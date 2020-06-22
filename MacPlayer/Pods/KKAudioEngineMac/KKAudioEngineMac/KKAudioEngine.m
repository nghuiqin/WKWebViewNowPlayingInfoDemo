//
// KKAudioEngine.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioEngine.h"
#import "KKAudioEngineHTTPOperation.h"
#import "KKAudioEngineFileOperation.h"
#import "KKAudioGraph.h"

AudioFileTypeID kAudioFileFlacType = 'flac';

@interface KKAudioEngine ()
{
	NSTimeInterval crossfadeDuration;
	BOOL crossfadeWithPanning;
}
@property (strong, nonatomic) KKAudioGraph *audioGraph;
@property (strong, nonatomic) NSOperationQueue *operationQueue;
@property (strong, nonatomic) KKAudioEngineOperation *previousOperation;
@property (strong, nonatomic) KKAudioEngineOperation *currentOperation;
@property (strong, nonatomic) KKAudioEngineOperation *nextOperation;

@property (strong, nonatomic) KKAudioEngineOperation *audioGraphRenderingOperation;
@property (strong, nonatomic) KKAudioEngineOperation *audioGraphCrossfadeRenderingOperation;

@property (assign, nonatomic) BOOL usingVocalRemoval;
@property (strong, nonatomic) NSTimer *timer;
@end

@interface KKAudioEngine (Timer)
- (void)beginTimer;

- (void)endTimer;
@end

@interface KKAudioEngine (KKAudioEngineOperationDelegate) <KKAudioEngineOperationDelegate>
@end

@interface KKAudioEngine (KKAudioGraphDelegate) <KKAudioGraphDelegate>
@end

@interface KKAudioEngine (PreviousOperation)
- (void)resetPreviousOperation;
@end


@implementation KKAudioEngine

- (void)dealloc
{
	[self reset];
}

- (instancetype)init
{
	self = [super init];
	if (self) {
		self.audioGraph = [[KKAudioGraph alloc] init];
		self.audioGraph.delegate = self;
		self.operationQueue = [[NSOperationQueue alloc] init];
	}
	return self;
}

- (void)reset
{
	[self.currentOperation cancel];
	self.currentOperation = nil;
	[self.nextOperation cancel];
	self.nextOperation = nil;
	[self.operationQueue cancelAllOperations];
	self.audioGraphRenderingOperation = nil;
	self.audioGraphCrossfadeRenderingOperation = nil;
}

- (void)_loadCurrentOperation:(KKAudioEngineOperation *)op
{
	[self resetPreviousOperation];
	[self reset];

	self.currentOperation = op;
	self.currentOperation.delegate = self;
	self.currentOperation.crossfadeDuration = self.crossfadeDuration;
	[self.operationQueue addOperation:self.currentOperation];
}

- (void)_loadNextOperation:(KKAudioEngineOperation *)op
{
	[self.nextOperation cancel];
	self.nextOperation = nil;

	self.nextOperation = op;
	self.nextOperation.crossfadeDuration = self.crossfadeDuration;
	[self.operationQueue addOperation:self.nextOperation];
}

- (void)loadAudioWithURL:(NSURL *)inURL suggestedFileType:(AudioFileTypeID)inTypeID contextInfo:(id)contextInfo
{
	Class cls = [inURL isFileURL] ? [KKAudioEngineFileOperation class] : [KKAudioEngineHTTPOperation class];
	KKAudioEngineOperation *operation = [[cls alloc] initWithURL:inURL suggestedFileType:inTypeID];
	operation.contextInfo = contextInfo;
	operation.delegate = self;
	operation.crossfadeDuration = self.crossfadeDuration;
	[self _loadCurrentOperation:operation];
}

- (void)loadNextAudioWithURL:(NSURL *)inURL suggestedFileType:(AudioFileTypeID)inTypeID contextInfo:(id)contextInfo
{
	Class cls = [inURL isFileURL] ? [KKAudioEngineFileOperation class] : [KKAudioEngineHTTPOperation class];
	KKAudioEngineOperation *operation = [[cls alloc] initWithURL:inURL suggestedFileType:inTypeID];
	operation.contextInfo = contextInfo;
	operation.delegate = self;
	operation.crossfadeDuration = self.crossfadeDuration;
	[self _loadNextOperation:operation];
}

- (void)play
{
	if (!self.currentOperation) {
		return;
	}
	[self resetPreviousOperation];
	[self.audioGraph play];
}

- (void)pause
{
	if (!self.currentOperation) {
		return;
	}
	[self resetPreviousOperation];
	[self.audioGraph pause];
}

- (void)stop
{
	if (!self.currentOperation) {
		return;
	}
	[self resetPreviousOperation];
	[self.audioGraph pause];
	[self.currentOperation cancel];
	self.currentOperation = nil;
}

- (void)cancelNextOperation
{
	if (self.nextOperation) {
		[self.nextOperation cancel];
		self.nextOperation = nil;
	}
}

#pragma mark -

- (id)currentContextInfo
{
	return self.currentOperation.contextInfo;
}

- (CGFloat)volume
{
	return self.audioGraph.volume;
}

- (void)setVolume:(CGFloat)volume
{
	[self.audioGraph setVolume:volume];
}

- (BOOL)isUsingNormalization
{
	return self.audioGraph.usingNormalization;
}

- (void)setUsingNormalization:(BOOL)usingNormalization
{
	self.audioGraph.usingNormalization = usingNormalization;
}

- (void)fadeToVolume:(Float32)targetVolume
{
	[self.audioGraph fadeToVolume:targetVolume];
}

- (void)resetFaderVolume
{
	[self.audioGraph resetFaderVolume];
}

@end

@implementation KKAudioEngine (CurrentAudioProperties)

- (BOOL)hasCurrentOperation
{
	return self.currentOperation != nil;
}

- (BOOL)isCurrentSongTrackFullyLoaded
{
	return self.currentOperation != nil && !self.currentOperation.isContinuousStream && self.currentOperation.loaded;
}

- (BOOL)isPlaying
{
	return self.audioGraph.playing;
}

- (BOOL)isPlayingContinuousStream
{
	return self.currentOperation ? self.currentOperation.isContinuousStream : NO;
}

- (NSTimeInterval)currentTime
{
	return self.currentOperation ? self.currentOperation.currentTime : 0;
}

- (void)setCurrentTime:(NSTimeInterval)currentTime
{
	[self resetPreviousOperation];
	BOOL playing = self.audioGraph.playing;
	if (playing) {
		[self.audioGraph pause];
	}
	self.currentOperation.currentTime = currentTime;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t) (0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		if (playing) {
			[self.audioGraph play];
		}
	});
}

- (NSTimeInterval)expectedDuration
{
	return self.currentOperation ? self.currentOperation.expectedDuration : 0;
}

- (NSTimeInterval)loadedDuration
{
	return self.currentOperation ? self.currentOperation.loadedDuration : 0;
}

- (CGFloat)loadedPercentage
{
	return self.currentOperation ? self.currentOperation.loadedPercentage : 0;
}

- (NSDictionary *)ID3Tags
{
	return self.currentOperation.ID3Tags;
}

- (NSTimeInterval)crossfadeDuration
{
	return crossfadeDuration;
}

- (BOOL)crossfadeWithPanning
{
	return crossfadeWithPanning;
}

- (void)setCrossfadeWithPanning:(BOOL)inCrossfadeWithPanning
{
	crossfadeWithPanning = inCrossfadeWithPanning;
}

- (void)setCrossfadeDuration:(NSTimeInterval)incrossfadeDuration
{
	[self resetPreviousOperation];
	crossfadeDuration = incrossfadeDuration;
	self.currentOperation.crossfadeDuration = self.crossfadeDuration;
	self.nextOperation.crossfadeDuration = self.crossfadeDuration;
}

- (void)endCurrentOperation
{
	[self.currentOperation cancel];
	self.currentOperation = nil;

	if (self.nextOperation) {
		self.currentOperation = self.nextOperation;
		self.currentOperation.delegate = self;
		self.nextOperation = nil;
		if (self.currentOperation.hasEnoughDataToPlay) {
			self.currentOperation.stalled = NO;
			[self.audioGraph play];
		}
		else {
			self.currentOperation.stalled = YES;
		}
		[self.delegate audioEngineDidEndCurrentPlayback:self];
	}
	else {
		[self.delegate audioEngineDidEndCurrentPlayback:self];
		[self.delegate audioEngineDidEndPlaying:self];
	}
}

@end


@implementation KKAudioEngine (NextAudioProperties)

- (BOOL)hasNextOperation
{
	return self.nextOperation != nil;
}

- (id)nextContextInfo
{
	return self.nextOperation.contextInfo;
}

@end

@implementation KKAudioEngine (KKAudioEngineOperationDelegate)

- (void)audioEngineOperationDidHaveEnoughDataToStartPlaying:(KKAudioEngineOperation *)operation
{
	if (operation != self.currentOperation) {
		return;
	}
	[self.delegate audioEngineDidHaveEnoughDataToStartPlaying:self];

	if (operation.pausedOnStart) {
		return;
	}

	[self.audioGraph play];
	if ([self.delegate respondsToSelector:@selector(audioEngine:didStartPlayingOperation:)]) {
		[self.delegate audioEngine:self didStartPlayingOperation:self.currentOperation];
	}
}

- (void)audioEngineOperationDidHaveEnoughDataToResumePlaying:(KKAudioEngineOperation *)operation
{
	if (operation != self.currentOperation) {
		return;
	}
	if (operation.pausedOnStart) {
		return;
	}

	[self.audioGraph play];
	[self.delegate audioEngineDidHaveEnoughDataToResumePlaying:self];
}

- (void)audioEngineOperationDidCompleteLoading:(KKAudioEngineOperation *)operation
{
	if (operation != self.currentOperation) {
		return;
	}
	[self.delegate audioEngineDidCompleteLoading:self];
}

- (void)audioEngineOperationDidEndReadingBuffer:(KKAudioEngineOperation *)operation
{
	if (operation == self.previousOperation) {
		self.previousOperation = nil;
		return;
	}

	if (operation != self.currentOperation) {
		return;
	}

	if (operation.loaded) {
		[self endCurrentOperation];
	}
	else {
		[self.audioGraph pause];
		self.currentOperation.stalled = YES;
		[self.delegate audioEngineDidStall:self];
	}
}

- (void)audioEngineOperation:(KKAudioEngineOperation *)operation didFailLoadingWithError:(NSError *)error
{
	if (operation == self.nextOperation) {
		[self.delegate audioEngine:self didFailLoadingNextAudioWithError:error contextInfo:self.nextOperation.contextInfo];
		self.nextOperation = nil;
		return;
	}

	[self.audioGraph pause];
	[self.delegate audioEngine:self didFailLoadingWithError:error];
}

- (void)audioEngineOperation:(KKAudioEngineOperation *)operation didFindID3tags:(NSDictionary *)inID3Tags
{
	if ([self.delegate respondsToSelector:@selector(audioEngine:didFindID3tags:inOperation:)]) {
		[self.delegate audioEngine:self didFindID3tags:inID3Tags inOperation:operation];
	}

	if (operation == self.currentOperation) {
		if (inID3Tags[@"NORV"]) {
			[self.audioGraph updateVolumeLevel];
		}
	}
}

- (void)audioEngineOperationDidEnd:(KKAudioEngineOperation *)operation
{
	if (operation == self.previousOperation) {
		self.previousOperation = nil;
	}
	if (operation == self.currentOperation) {
		self.currentOperation = nil;
	}
	if (operation == self.nextOperation) {
		self.nextOperation = nil;
	}
}

- (BOOL)audioEngineOperationShouldBeginCrossfade:(KKAudioEngineOperation *)operation
{
	if (operation == self.currentOperation) {
		return self.nextOperation != nil && !self.nextOperation.isContinuousStream && self.nextOperation.hasEnoughDataToPlay;
	}
	return NO;
}

- (void)audioEngineOperationDidRequestBeginCrossfade:(KKAudioEngineOperation *)operation
{
	self.previousOperation = self.currentOperation;
	self.currentOperation = nil;
	dispatch_async(dispatch_get_main_queue(), ^{
		[self endCurrentOperation];
	});
	[self.audioGraph setVolume:0.0 forBus:0];
	[self.audioGraph setVolume:1.0 forBus:1];
}

- (CGFloat)audioGraph:(KKAudioGraph *)audioEngine requestNormalizationGainForBus:(UInt32)busNumber
{
	CGFloat normalizationGain = 0;
	if (busNumber == 0) {
		normalizationGain = [self.currentOperation.ID3Tags[@"NORV"] doubleValue];
	}
	else if (busNumber == 1) {
		normalizationGain = [self.previousOperation.ID3Tags[@"NORV"] doubleValue];
	}
	return normalizationGain;
}

@end


@implementation KKAudioEngine (KKAudioGraphDelegate)

static void VocalRemoval(void *bytes, UInt32 size) {
	// Always assuming that we have 2 channels, and 2 bytes/channel
	size_t sampleCount = size / 4;

	for (size_t i = 0; i < sampleCount * 4; i += 4) {
		short *sp = (short *) (bytes + i);
		short left = *sp;
		short right = *(sp + 1);
		short new = (left - right);
		*sp = new;
		*(sp + 1) = new;
	}
}

- (OSStatus)audioGraph:(KKAudioGraph *)audioGraph requestNumberOfFrames:(UInt32)inNumberOfFrames ioData:(AudioBufferList *)inIoData busNumber:(UInt32)inBusNumber
{
	self.audioGraphRenderingOperation = nil;
	KKAudioEngineOperation *currentOperation = nil;
	@synchronized(self) {
		currentOperation = self.currentOperation;
	}
	if (!currentOperation) {
		return -1;
	}
	if (currentOperation == self.previousOperation) {
		return -1;
	}
	OSStatus status = [currentOperation readNumberOfFrames:inNumberOfFrames intoIoData:inIoData forBusNumber:inBusNumber];
	if (self.usingVocalRemoval) {
		VocalRemoval(inIoData->mBuffers[0].mData, inIoData->mBuffers[0].mDataByteSize);
	}
	return status;
}

- (OSStatus)audioGraph:(KKAudioGraph *)audioGraph requestNumberOfFramesForCrossfade:(UInt32)inNumberOfFrames ioData:(AudioBufferList *)inIoData busNumber:(UInt32)inBusNumber
{
	self.audioGraphCrossfadeRenderingOperation = nil;
	KKAudioEngineOperation *previousOperation = nil;
	KKAudioEngineOperation *currentOperation = nil;
	@synchronized (self) {
		currentOperation = self.currentOperation;
		previousOperation = self.previousOperation;
	}
	if (!previousOperation) {
		return -1;
	}

	OSStatus status = [previousOperation readNumberOfFrames:inNumberOfFrames intoIoData:inIoData forBusNumber:inBusNumber];
	if (self.usingVocalRemoval) {
		VocalRemoval(inIoData->mBuffers[0].mData, inIoData->mBuffers[0].mDataByteSize);
	}
	if (self.currentOperation.crossfadeDuration) {
		CGFloat currentVolume = currentOperation.currentTime / currentOperation.crossfadeDuration;
		CGFloat previousVolume = 1.0 - currentVolume;
		[self.audioGraph setVolume:currentVolume / 2.0 + 0.5 forBus:0];
		[self.audioGraph setVolume:previousVolume / 2.0 + 0.5 forBus:1];
		if (self.crossfadeWithPanning) {
			[self.audioGraph setPan:-1 + currentVolume forBus:0];
			[self.audioGraph setPan:currentVolume forBus:1];
		}
	}
	return status;
}

- (void)audioGraphWillStartPlaying:(KKAudioGraph *)audioGraph
{
	[self.delegate audioEngineWillStartPlaying:self];
}

- (void)audioGraphDidStartPlaying:(KKAudioGraph *)audioGraph
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self beginTimer];
		[self.delegate audioEngineDidStartPlaying:self];
		self.currentOperation.stalled = NO;
	});
}

- (void)audioGraphDidStopPlaying:(KKAudioGraph *)audioGraph
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self endTimer];
		[self.delegate audioEngineDidPausePlaying:self];
	});
}

@end

@implementation KKAudioEngine (PreviousOperation)

- (void)resetPreviousOperation
{
	self.previousOperation = nil;
	[self.audioGraph setVolume:1.0 forBus:0];
	[self.audioGraph setVolume:0.0 forBus:1];
	[self.audioGraph setPan:0 forBus:0];
	[self.audioGraph setPan:0 forBus:1];
}

@end


@implementation KKAudioEngine (Timer)

- (void)_updatePlaybackTime:(NSTimer *)inTimer
{
	[self.delegate audioEngine:self updateCurrentPlaybackTime:self.currentTime loadedDuration:self.loadedDuration];
}

- (void)beginTimer
{
	[self.timer invalidate];
	self.timer = nil;
	self.timer = [NSTimer timerWithTimeInterval:1.0 / 60.0 target:self selector:@selector(_updatePlaybackTime:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSDefaultRunLoopMode];
}

- (void)endTimer
{
	[self.timer invalidate];
	self.timer = nil;
}

@end

