//
// KKAudioStreamBuffer.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioStreamBuffer.h"

const size_t KKAudioStreamBufferIndeterminatePacketCount = 0;
static const size_t kDefaultPacketCount = 2048;

@implementation KKAudioStreamBuffer

- (void)dealloc
{
	@synchronized (self) {
		for (size_t index = 0; index < packetCount; index++) {
			void *data = packets[index].data;
			if (data) {
				free(data);
			}
			packets[index].data = NULL;
		}
		if (packets) {
			free(packets);
			packets = NULL;
		}
	}
}

- (instancetype)initWithMaximumPacketCount:(size_t)inCount
{
	if (self = [super init]) {
		maximumPacketCount = inCount;
		packetCount = (maximumPacketCount == KKAudioStreamBufferIndeterminatePacketCount) ? kDefaultPacketCount : maximumPacketCount;
		packets = (KKAudioPacketInfo *) calloc(packetCount, sizeof(KKAudioPacketInfo));
	}

	return self;
}

- (void)storePacketData:(const void *)inData count:(size_t)inPacketCount descriptions:(AudioStreamPacketDescription *)inPacketDescriptions
{
	@synchronized (self) {
		for (size_t index = 0; index < inPacketCount; index++) {
			if (packetWriteIndex >= packetCount) {
				if (!self.isBufferForContinuousStream) {
					// grow the buffer
					size_t oldSize = packetCount * sizeof(KKAudioPacketInfo);
					while (packetCount < packetWriteIndex + inPacketCount) {
						packetCount = packetCount * 2;
					}
					packets = (KKAudioPacketInfo *) realloc(packets, packetCount * sizeof(KKAudioPacketInfo));
					NSAssert(packets, @"Must allocate enough memory for packets");

					// zero out the realloc'ed area; remember we need to cast packets to byte semantic
					// otherwise it would be interpreted as (void *)&packets[oldSize]
					bzero((void *) packets + oldSize, packetCount * sizeof(KKAudioPacketInfo) - oldSize);
				}
				else {
					packetWriteIndex = 0;
				}
			}

			AudioStreamPacketDescription emptyDescription;

			if (!inPacketDescriptions) {
				emptyDescription.mStartOffset = index;
				emptyDescription.mDataByteSize = 1;
				emptyDescription.mVariableFramesInPacket = 0;
			}

			AudioStreamPacketDescription *currentDescription = inPacketDescriptions ? &(inPacketDescriptions[index]) : &emptyDescription;
			KKAudioPacketInfo *nextInfo = &packets[packetWriteIndex];

			if (nextInfo->data) {
				free(nextInfo->data);
				nextInfo->data = NULL;
			}

			nextInfo->data = malloc(currentDescription->mDataByteSize);
			NSAssert(nextInfo->data, @"Must allocate memory for current packet");
			memcpy(nextInfo->data, inData + currentDescription->mStartOffset, currentDescription->mDataByteSize);
			memcpy(&nextInfo->packetDescription, currentDescription, sizeof(AudioStreamPacketDescription));

			packetWriteIndex++;

			availablePacketCount++;

			if (self.isBufferForContinuousStream) {
				if (availablePacketCount >= maximumPacketCount) {
					availablePacketCount = maximumPacketCount;
				}
			}
		}
	}
}

- (BOOL)isBufferForContinuousStream
{
	return maximumPacketCount != KKAudioStreamBufferIndeterminatePacketCount;
}

- (size_t)unreadPacketCount
{
	if (packetWriteIndex >= packetReadIndex) {
		return packetWriteIndex - packetReadIndex;
	}

	// the case where packetWriteIndex < packetReadIndex
	if (self.isBufferForContinuousStream) {
		return (maximumPacketCount - packetReadIndex) + packetWriteIndex;
	}

	return 0;
}

- (void)setPacketReadIndex:(size_t)inNewIndex
{
	size_t max = availablePacketCount;

	if (self.isBufferForContinuousStream) {
		if (inNewIndex >= packetCount) {
			packetReadIndex = 0;
		}
		else {
			packetReadIndex = inNewIndex;
		}
		return;
	}

	if (inNewIndex > max) {
		packetReadIndex = max;
		return;
	}

	if (inNewIndex < packetWriteIndex) {
		packetReadIndex = inNewIndex;
	}
	else {
		packetReadIndex = packetWriteIndex;
	}
}

@synthesize availablePacketCount;
@synthesize packetReadIndex;

- (void)movePacketReadIndex
{
	[self setPacketReadIndex:packetReadIndex + 1];
}

- (KKAudioPacketInfo)currentPacketInfo
{
	@synchronized (self) {
		if (packets == NULL) {
			KKAudioPacketInfo emptyInfo;
			emptyInfo.data = NULL;
			return emptyInfo;
		}

		if (packetReadIndex == 0 && packetWriteIndex == 0) {
			KKAudioPacketInfo emptyInfo;
			emptyInfo.data = NULL;
			return emptyInfo;
		}

		BOOL isBufferForContinuousStream = (maximumPacketCount != KKAudioStreamBufferIndeterminatePacketCount);
		if (isBufferForContinuousStream) {
			if (packetReadIndex > packetCount) {
				KKAudioPacketInfo emptyInfo;
				emptyInfo.data = NULL;
				return emptyInfo;
			}
			return packets[packetReadIndex];
		}

		if (packetReadIndex > packetWriteIndex) {
			KKAudioPacketInfo emptyInfo;
			emptyInfo.data = NULL;
			return emptyInfo;
		}

		return packets[packetReadIndex];
	}
}

@end
