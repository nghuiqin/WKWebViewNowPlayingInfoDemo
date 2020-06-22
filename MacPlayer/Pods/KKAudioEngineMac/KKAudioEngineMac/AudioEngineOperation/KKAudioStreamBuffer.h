//
// KKAudioStreamBuffer.h
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

@import Foundation;
@import AudioToolbox;

typedef struct {
	AudioStreamPacketDescription packetDescription;
	void *data;
} KKAudioPacketInfo;

@interface KKAudioStreamBuffer : NSObject
{
	size_t maximumPacketCount;

	KKAudioPacketInfo *packets;
	size_t packetCount;
	size_t availablePacketCount;
	size_t packetWriteIndex;
	size_t packetReadIndex;
}

- (instancetype)initWithMaximumPacketCount:(size_t)inCount;
- (void)storePacketData:(const void *)inData count:(size_t)inPacketCount descriptions:(AudioStreamPacketDescription *)inPacketDescriptions;

@property (readonly, nonatomic) BOOL isBufferForContinuousStream;
@property (readonly, nonatomic) size_t availablePacketCount;
@property (readonly, nonatomic) size_t unreadPacketCount;
@property (assign, nonatomic) size_t packetReadIndex;
@end

@interface KKAudioStreamBuffer ()
- (void)movePacketReadIndex;
@property (readonly, nonatomic) KKAudioPacketInfo currentPacketInfo;
@end

extern const size_t KKAudioStreamBufferIndeterminatePacketCount;
