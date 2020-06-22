//
// KKAudioEngineOperation.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioEngineOperation.h"
#import "KKAudioEngineOperation+Privates.h"

static const double kMinimumPlayableDuration = 3.0;

@interface KKAudioEngineOperation ()
{
	NSTimeInterval crossfadeDuration;
}
@property (assign, nonatomic) NSTimeInterval internalCrossfadeDuration;
@property (assign, nonatomic) BOOL crossfadeEverCalled;
@end

@implementation KKAudioEngineOperation

- (void)dealloc
{
	self.delegate = nil;
	self.parser.delegate = nil;
}

- (instancetype)initWithSuggestedFileType:(AudioFileTypeID)inTypeID
{
	self = [super init];
	if (self) {
		self.parser = [[KKAudioStreamParser alloc] initWithSuggestedFileType:inTypeID];
	}
	return self;
}

- (void)main
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.delegate audioEngineOperationDidEnd:self];
	});
}

- (void)cancel
{
	[super cancel];
	[self quitRunLoop];
}

- (BOOL)detectIfReadingBufferEnds
{
	if (self.buffer.unreadPacketCount == 0) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate audioEngineOperationDidEndReadingBuffer:self];
		});
		return YES;
	}
	else if (self.loaded && self.crossfadeDuration > 0) {
		if (self.crossfadeEverCalled) {
			return NO;
		}
		if (self.buffer.unreadPacketCount > self.internalCrossfadeDuration * self.packetsPerSecond) {
			return NO;
		}
		if (![self.delegate audioEngineOperationShouldBeginCrossfade:self]) {
			return NO;
		}
		self.crossfadeEverCalled = YES;
		[self.delegate audioEngineOperationDidRequestBeginCrossfade:self];
		return NO;
	}
	return NO;
}

- (OSStatus)readNumberOfFrames:(UInt32)inNumberOfFrames intoIoData:(AudioBufferList *)inIoData forBusNumber:(UInt32)inBusNumber
{
	if ([self detectIfReadingBufferEnds]) {
		return -1;
	}
	UInt32 convertedPacketCount = 0;
	OSStatus status = [self.converter convertDataFromBuffer:self.buffer numberOfFrames:(UInt32)inNumberOfFrames ioData:(AudioBufferList *)inIoData convertedFrameCount:&convertedPacketCount];
	if (noErr != status || !convertedPacketCount) {
		[self.converter reset];
	}

	if (self.loaded && self.buffer.unreadPacketCount == 0) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.delegate audioEngineOperationDidEndReadingBuffer:self];
		});
		return -1;
	}
	return status;
}

- (NSTimeInterval)currentTime
{
	if (self.buffer && self.converter) {
		if (self.buffer.isBufferForContinuousStream) {
			return 0;
		}
		Float64 sampleRate = self.converter.audioStreamDescription.mSampleRate;
		UInt32 framesPerPacker = self.converter.audioStreamDescription.mFramesPerPacket;
		return self.buffer.packetReadIndex * framesPerPacker / sampleRate;
	}
	return 0;
}

- (void)setCurrentTime:(NSTimeInterval)currentTime
{
	if (self.buffer && self.converter) {
		if (self.buffer.isBufferForContinuousStream) {
			return;
		}
		NSInteger packetIndex = (NSInteger)currentTime * self.packetsPerSecond;
		self.buffer.packetReadIndex = packetIndex;
		self.internalCrossfadeDuration = (self.loaded && self.loadedDuration - self.currentTime < crossfadeDuration) ? 0 : crossfadeDuration;
	}
}

- (NSTimeInterval)loadedDuration
{
	if (self.buffer && self.converter) {
		if (self.buffer.isBufferForContinuousStream) {
			return 0;
		}
		Float64 sampleRate = self.converter.audioStreamDescription.mSampleRate;
		UInt32 framesPerPacker = self.converter.audioStreamDescription.mFramesPerPacket;
		return self.buffer.availablePacketCount * framesPerPacker / sampleRate;
	}
	return 0;
}

- (double)packetsPerSecond
{
	if (self.converter) {
		return self.converter.packetsPerSecond;
	}
	return 0;
}

- (NSTimeInterval)crossfadeDuration
{
	return crossfadeDuration;
}

- (void)setCrossfadeDuration:(NSTimeInterval)inCrossfadeDuration
{
	crossfadeDuration = inCrossfadeDuration;
	self.internalCrossfadeDuration = (self.loaded && self.loadedDuration - self.currentTime < crossfadeDuration) ? 0 : crossfadeDuration;
}

@end

@implementation KKAudioEngineOperation (KKAudioStreamParserDelegate)

- (void)audioStreamParser:(KKAudioStreamParser *)inParser didObtainPacketData:(const void *)inData count:(size_t)inPacketCount descriptions:(AudioStreamPacketDescription *)inPacketDescriptions
{
	// Main thread
	[self.buffer storePacketData:inData count:inPacketCount descriptions:inPacketDescriptions];
	if (!self.hasEnoughDataToPlay) {
		if (self.buffer.packetReadIndex == 0 &&
				self.buffer.availablePacketCount > self.packetsPerSecond * kMinimumPlayableDuration) {
			self.hasEnoughDataToPlay = YES;
			[self.delegate audioEngineOperationDidHaveEnoughDataToStartPlaying:self];
		}
	}
	else if (self.stalled) {
		if ((NSTimeInterval)self.buffer.unreadPacketCount / self.packetsPerSecond > kMinimumPlayableDuration) {
			self.stalled = NO;
			[self.delegate audioEngineOperationDidHaveEnoughDataToResumePlaying:self];
		}
	}
}

- (void)audioStreamParser:(KKAudioStreamParser *)inParser didObtainStreamDescription:(AudioStreamBasicDescription *)inDescription
{
	// Main thread
	self.converter = [[KKAudioConverter alloc] initWithSourceFormat:inDescription];
}

- (void)audioStreamParser:(KKAudioStreamParser *)inParser didObtainID3Tags:(NSDictionary *)inID3Tags
{
	self.ID3Tags = inID3Tags;
	[self.delegate audioEngineOperation:self didFindID3tags:inID3Tags];
}

@end
