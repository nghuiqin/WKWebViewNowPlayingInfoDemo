//
// KKAudioConverter.h
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

@import Foundation;
@import AudioToolbox;
#import "KKAudioStreamBuffer.h"

@interface KKAudioConverter : NSObject

- (instancetype)initWithSourceFormat:(AudioStreamBasicDescription *)sourceFormat;
- (void)reset;
- (OSStatus)convertDataFromBuffer:(KKAudioStreamBuffer *)buffer numberOfFrames:(UInt32)inNumberOfFrames ioData:(AudioBufferList *)inIoData convertedFrameCount:(UInt32 *)convertedFrameCount;

@property (readonly, nonatomic) AudioStreamBasicDescription audioStreamDescription;
@property (readonly, nonatomic) double packetsPerSecond;
@end
