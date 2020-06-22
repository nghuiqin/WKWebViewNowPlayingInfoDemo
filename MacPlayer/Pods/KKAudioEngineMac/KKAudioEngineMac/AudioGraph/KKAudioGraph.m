//
// KKAudioGraph.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioGraph.h"
#import "KKAudioSubGraph.h"
#import "KKAudioOutputNode.h"
#import "KKAudioEQEffectNode.h"
#import "KKAudioGenericOutputNode.h"
#import "KKAudioMixerNode.h"
#import "KKAudioFormat.h"
#import "KKAudioEngineFader.h"

static OSStatus KKPlayerAURenderCallback(void *userData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
static OSStatus KKPlayerCrossfadeAURenderCallback(void *userData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);
static void KKAudioUnitPropertyListenerProc(void *inRefCon, AudioUnit ci, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement);

@interface KKAudioGraph () <KKAudioEngineFaderDelegate>
{
	AUGraph audioGraph;
	CGFloat volume;
	BOOL usingNormalization;
	CGFloat inputVolumes[8];
}

- (void)_zapAudioGraph;
- (void)_updateProperties;

@property (assign, nonatomic, getter=isPlaying) BOOL playing;
@property (strong, nonatomic) KKAudioEngineFader *fader;

@property (strong, nonatomic) KKAudioSubGraph *subgraph;
@property (strong, nonatomic) KKAudioGenericOutputNode *genericOutputNode;
@property (strong, nonatomic) KKAudioSubGraph *crossFadeSubgraph;
@property (strong, nonatomic) KKAudioGenericOutputNode *crossFadeGenericOutputNode;

@property (strong, nonatomic) KKAudioOutputNode *outputNode;
@property (strong, nonatomic) KKAudioEQEffectNode *EQEffectNode;
@property (strong, nonatomic) KKAudioMixerNode *mixerNode;
@end

@implementation KKAudioGraph

- (void)dealloc
{
	[self _zapAudioGraph];
}

- (void)connectNode:(KKAudioNode *)from bus:(UInt32)fromBus toNode:(KKAudioNode *)to bus:(UInt32)toBus
{
	__unused OSStatus status = noErr;
	status = AUGraphConnectNodeInput(audioGraph, [from node], fromBus, [to node], toBus);
	NSAssert(noErr == status, @"We need to connect the nodes %d %% %@", (int)status, from, to);
}

- (void)connectNodes:(NSArray *)nodes
{
	for (NSInteger i = 0; i < [nodes count] - 1; i++) {
		[self connectNode:nodes[i] bus:0 toNode:nodes[i + 1] bus:0];
	}
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		[self enlargeOutputDeviceFrameNumber];

		for (NSInteger i = 0; i < 8; i++) {
			inputVolumes[i] = 1;
		}

		__unused OSStatus status = noErr;

		// 1. Create the audio graph.
		status = NewAUGraph(&audioGraph);
		NSAssert(noErr == status, @"We need to create a new audio graph. %d", (int)status);
		status = AUGraphOpen(audioGraph);
		NSAssert(noErr == status, @"We need to open the audio graph. %d", (int)status);

		// 2. Create and connect nodes.
		self.mixerNode = [[KKAudioMixerNode alloc] initWithAudioGraph:audioGraph];
		self.mixerNode.busCount = 8;
		self.outputNode = [[KKAudioOutputNode alloc] initWithAudioGraph:audioGraph];
		self.EQEffectNode = [[KKAudioEQEffectNode alloc] initWithAudioGraph:audioGraph];

		self.subgraph = [[KKAudioSubGraph alloc] initWithAudioGraph:audioGraph];
		self.genericOutputNode = [[KKAudioGenericOutputNode alloc] initWithAudioGraph:self.subgraph.audioGraph];
		self.crossFadeSubgraph = [[KKAudioSubGraph alloc] initWithAudioGraph:audioGraph];
		self.crossFadeGenericOutputNode = [[KKAudioGenericOutputNode alloc] initWithAudioGraph:self.crossFadeSubgraph.audioGraph];

		[self connectNodes:@[self.subgraph, self.mixerNode, self.EQEffectNode, self.outputNode]];
		[self connectNode:(id)self.crossFadeSubgraph bus:0 toNode:self.mixerNode bus:1];

		// 3. Set output format.
		AudioStreamBasicDescription destFormat = KKLinearPCMStreamDescription();
		status = AudioUnitSetProperty(self.genericOutputNode.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &destFormat, sizeof(destFormat));
		NSAssert(noErr == status, @"We need to set the input format of the generic output node. %d", (int)status);
		status = AudioUnitSetProperty(self.crossFadeGenericOutputNode.audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &destFormat, sizeof(destFormat));
		NSAssert(noErr == status, @"We need to set the input format of the generic output node. %d", (int)status);

		// 4. Register callback to know if output unit of the audio graph is running.
		status = AudioUnitAddPropertyListener(self.outputNode.audioUnit, kAudioOutputUnitProperty_IsRunning, KKAudioUnitPropertyListenerProc, (__bridge void *)(self));
		NSAssert(noErr == status, @"We need to set the property listener to the output nodein order to know if we are playing or not. %d", (int)status);

		// 5. Register render callback.
		AURenderCallbackStruct callbackStruct;
		callbackStruct.inputProcRefCon = (__bridge void *)(self);

		callbackStruct.inputProc = KKPlayerCrossfadeAURenderCallback;
		status = AudioUnitSetProperty(self.crossFadeGenericOutputNode.audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(callbackStruct));

		callbackStruct.inputProc = KKPlayerAURenderCallback;
		status = AudioUnitSetProperty(self.genericOutputNode.audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(callbackStruct));

		self.fader = [[KKAudioEngineFader alloc] init];
		self.fader.delegate = self;

		// 6. Initialize the audio graph.
		self.volume = 1.0;
		status = AUGraphInitialize(audioGraph);
		NSAssert(noErr == status, @"We need to initialized the audio graph. %d", (int)status);
#if DEBUG
		CAShow(audioGraph);
#endif
		AudioOutputUnitStop(self.outputNode.audioUnit);
	}
	return self;
}

- (void)enlargeOutputDeviceFrameNumber
{
	__unused OSStatus status;

	AudioDeviceID defaultOutputDevice = 0;
	UInt32 adIDSize = sizeof(defaultOutputDevice);
	AudioObjectPropertyAddress outputDeviceAddress;
	outputDeviceAddress.mSelector = kAudioHardwarePropertyDefaultOutputDevice;
	status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &outputDeviceAddress, 0, NULL, &adIDSize, &defaultOutputDevice);
	assert(noErr == status);

	UInt32 numFrames = 0;
	UInt32 dataSize = sizeof(numFrames);
	AudioObjectPropertyAddress bufferSizeAddress;
	bufferSizeAddress.mSelector = kAudioDevicePropertyBufferFrameSize;
	numFrames = 1024;
	dataSize = sizeof(numFrames);
	status = AudioObjectSetPropertyData(defaultOutputDevice, &bufferSizeAddress, 0, NULL, dataSize, &numFrames);
}

- (void)_zapAudioGraph
{
	Boolean isRunning = false;
	AUGraphIsRunning(audioGraph, &isRunning);
	if (isRunning) {
		AUGraphStop(audioGraph);
		DisposeAUGraph(audioGraph);
	}
	AUGraphUninitialize(audioGraph);
	AUGraphClose(audioGraph);
	DisposeAUGraph(audioGraph);
}

- (BOOL)_outputNodePlaying
{
	UInt32 property = 0;
	UInt32 propertySize = sizeof(property);
	AudioUnitGetProperty(self.outputNode.audioUnit, kAudioOutputUnitProperty_IsRunning, kAudioUnitScope_Global, 0, &property, &propertySize);
	return property != 0;
}

- (void)_updateProperties
{
	BOOL outputNodePlaying = [self _outputNodePlaying];

	if (!self.playing && outputNodePlaying) {
		self.playing = YES;
		[self.delegate audioGraphDidStartPlaying:self];
	}
	else if (self.playing && !outputNodePlaying) {
		self.playing = NO;
		[self.delegate audioGraphDidStopPlaying:self];
	}
	else if (!self.playing && !outputNodePlaying) {
		[self.delegate audioGraphDidStopPlaying:self];
	}
}

#pragma mark -

- (void)play
{
	if (self.playing) {
		return;
	}
	[self.delegate audioGraphWillStartPlaying:self];
	__unused OSStatus error = AUGraphStart(audioGraph);
	NSAssert(noErr == error, @"AuGraphStop, error: %ld", (signed long)error);
	error = AudioOutputUnitStart(self.outputNode.audioUnit);
	NSAssert(noErr == error, @"AudioOutputUnitStart, error: %ld", (signed long)error);
}

- (void)pause
{
	if (!self.playing) {
		return;
	}
	__unused OSStatus error = AUGraphStop(audioGraph);
	NSAssert(noErr == error, @"AuGraphStop, error: %ld", (signed long)error);
	error = AudioOutputUnitStop(self.outputNode.audioUnit);
	NSAssert(noErr == error, @"AudioOutputUnitStart, error: %ld", (signed long)error);
}

#pragma mark -
#pragma mark Properties

- (void)updateVolumeLevel
{
	[self setVolume:inputVolumes[0] forBus:0];
	[self setVolume:inputVolumes[1] forBus:1];
	Float32 currentVolume = self.volume;

	OSStatus status = 0;
	status = AudioUnitSetParameter(self.mixerNode.audioUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, currentVolume, 0);
	NSAssert(noErr == status, @"AudioUnitSetParameter");
}

- (void)fadeToVolume:(Float32)targetVolume
{
	[self.fader fadeToVolume:targetVolume];
}

- (void)resetFaderVolume
{
	[self.fader resetVolume];
}

- (void)setVolume:(Float32)inVolume
{
	volume = inVolume;
	[self updateVolumeLevel];
}

- (Float32)volume
{
	return (Float32)volume;
}

- (void)setUsingNormalization:(BOOL)inUsingNormalization
{
	usingNormalization = inUsingNormalization;
	[self updateVolumeLevel];
}

- (BOOL)isUsingNormalization
{
	return usingNormalization;
}

#pragma mark

- (void)fader:(KKAudioEngineFader *)inFader didChangeVolume:(Float32)volume
{
	[self updateVolumeLevel];
}

@end

OSStatus KKPlayerAURenderCallback(void *userData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
	KKAudioGraph *self = (__bridge KKAudioGraph *)userData;
	OSStatus status = [self.delegate audioGraph:self requestNumberOfFrames:inNumberFrames ioData:ioData busNumber:inBusNumber];
	if (!self.delegate || status != noErr) {
		ioData->mNumberBuffers = 0;
		*ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
	}
	return status;
}

static OSStatus KKPlayerCrossfadeAURenderCallback(void *userData, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
	KKAudioGraph *self = (__bridge KKAudioGraph *)userData;
	OSStatus status = [self.delegate audioGraph:self requestNumberOfFramesForCrossfade:inNumberFrames ioData:ioData busNumber:inBusNumber];
	if (!self.delegate || status != noErr) {
		ioData->mNumberBuffers = 0;
		*ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
	}
	return status;
}

void KKAudioUnitPropertyListenerProc(void *inRefCon, AudioUnit ci, AudioUnitPropertyID inID, AudioUnitScope inScope, AudioUnitElement inElement) {
	KKAudioGraph *self = (__bridge KKAudioGraph *)inRefCon;
	[self _updateProperties];
}

@implementation KKAudioGraph (Mixer)

- (void)setVolume:(CGFloat)inVolume forBus:(UInt32)busNumber
{
	inputVolumes[busNumber] = inVolume;
	CGFloat inputVolume = inVolume;
	if (self.usingNormalization) {
		CGFloat normalizationGain = 0;
		if ([self.delegate respondsToSelector:@selector(audioGraph:requestNormalizationGainForBus:)]) {
			normalizationGain = [self.delegate audioGraph:self requestNormalizationGainForBus:busNumber];
		}
		Float32 fNorv = pow(10.0, normalizationGain / 20.0);
		inputVolume = inputVolume * fNorv;
		if (inputVolume > 1.0) {
			inputVolume = 1.0;
		}
	}
	[self.mixerNode setVolume:inputVolume forBus:busNumber];
}

- (void)setOutputPan:(CGFloat)pan
{
	[self.mixerNode setOutputPan:pan];
}

- (void)setPrimitiveVolume:(CGFloat)inVolume forBus:(UInt32)busNumber
{
	[self.mixerNode setVolume:inVolume forBus:busNumber];
}

- (void)setPan:(CGFloat)pan forBus:(UInt32)busNumber
{
	[self.mixerNode setPan:pan forBus:busNumber];
}

@end
