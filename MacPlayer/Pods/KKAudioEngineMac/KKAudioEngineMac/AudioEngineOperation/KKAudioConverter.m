//
// KKAudioConverter.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioConverter.h"
#import "KKAudioFormat.h"

static OSStatus KKAudioConverterFiller(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData);

@interface KKAudioConverter ()
{
	AudioStreamBasicDescription audioStreamDescription;
	AudioStreamBasicDescription destFormat;
	AudioConverterRef converter;
	AudioBufferList *renderBufferList;
	UInt32 renderBufferSize;
}
@end

@implementation KKAudioConverter

- (void)dealloc
{
	[self reset];
	AudioConverterDispose(converter);
	free(renderBufferList->mBuffers[0].mData);
	free(renderBufferList);
}

- (instancetype)initWithSourceFormat:(AudioStreamBasicDescription *)sourceFormat
{
	self = [super init];
	if (self) {
		audioStreamDescription = *sourceFormat;
		destFormat = KKLinearPCMStreamDescription();
		AudioConverterNew(&audioStreamDescription, &destFormat, &converter);

		UInt32 packetSize = 4096 * 4;
		renderBufferSize = packetSize;
		renderBufferList = (AudioBufferList *) calloc(1, sizeof(UInt32) + sizeof(AudioBuffer));
		renderBufferList->mNumberBuffers = 1;
		renderBufferList->mBuffers[0].mNumberChannels = 2;
		renderBufferList->mBuffers[0].mDataByteSize = packetSize;
		renderBufferList->mBuffers[0].mData = calloc(1, packetSize);
	}
	return self;
}

- (void)reset
{
	AudioConverterReset(converter);
	renderBufferList->mNumberBuffers = 1;
	renderBufferList->mBuffers[0].mNumberChannels = 2;
	renderBufferList->mBuffers[0].mDataByteSize = renderBufferSize;
	bzero(renderBufferList->mBuffers[0].mData, renderBufferSize);
}

- (OSStatus)convertDataFromBuffer:(KKAudioStreamBuffer *)buffer numberOfFrames:(UInt32)inNumberOfFrames ioData:(AudioBufferList *)inIoData convertedFrameCount:(UInt32 *)convertedFrameCount
{
	UInt32 packetSize = inNumberOfFrames;
	NSArray *args = @[self, buffer];
	OSStatus status = noErr;
	@synchronized (buffer) {
		status = AudioConverterFillComplexBuffer(converter, KKAudioConverterFiller, (__bridge void *) (args), &packetSize, renderBufferList, NULL);
	}
	if (noErr == status && packetSize) {
		inIoData->mNumberBuffers = 1;
		inIoData->mBuffers[0].mNumberChannels = 2;
		inIoData->mBuffers[0].mDataByteSize = renderBufferList->mBuffers[0].mDataByteSize;
		inIoData->mBuffers[0].mData = renderBufferList->mBuffers[0].mData;
		renderBufferList->mBuffers[0].mDataByteSize = renderBufferSize;
		status = noErr;
	}
	*convertedFrameCount = packetSize;
	return status;
}

- (BOOL)_fillBufferlist:(AudioBufferList *)ioData withBuffer:(KKAudioStreamBuffer *)buffer packetDescription:(AudioStreamPacketDescription **)outDataPacketDescription
{
	static AudioStreamPacketDescription aspdesc;

	ioData->mNumberBuffers = 1;
	KKAudioPacketInfo currentPacketInfo = buffer.currentPacketInfo;

	if (currentPacketInfo.data == NULL) {
		return NO;
	}

	void *data = currentPacketInfo.data;
	UInt32 length = (UInt32) currentPacketInfo.packetDescription.mDataByteSize;
	ioData->mBuffers[0].mData = data;
	ioData->mBuffers[0].mDataByteSize = length;

	if (outDataPacketDescription) {
		*outDataPacketDescription = &aspdesc;
	}
	aspdesc.mDataByteSize = length;
	aspdesc.mStartOffset = 0;
	aspdesc.mVariableFramesInPacket = 1;

	[buffer movePacketReadIndex];
	return YES;
}

- (double)packetsPerSecond
{
	return audioStreamDescription.mSampleRate / audioStreamDescription.mFramesPerPacket;
}

@synthesize audioStreamDescription;
@end


OSStatus KKAudioConverterFiller(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData) {
	NSArray *args = (__bridge NSArray *) inUserData;
	KKAudioConverter *self = args[0];
	KKAudioStreamBuffer *buffer = args[1];
	BOOL rtn = [self _fillBufferlist:ioData withBuffer:buffer packetDescription:outDataPacketDescription];
	*ioNumberDataPackets = rtn ? 1 : 0;
	return rtn == YES ? noErr : kAudioConverterErr_UnspecifiedError;
}

