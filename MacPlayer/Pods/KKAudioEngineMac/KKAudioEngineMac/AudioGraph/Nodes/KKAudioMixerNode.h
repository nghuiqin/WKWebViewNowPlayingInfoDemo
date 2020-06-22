//
// KKAudioMixerNode.h
//
// Copyright (c) 2008-2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioNode.h"

@interface KKAudioMixerNode : KKAudioNode
- (void)setVolume:(Float32)volume forBus:(UInt32)busNumber; // 0 - 1
- (void)setOutputPan:(Float32)pan; // -1 - 1
- (void)setPan:(Float32)pan forBus:(UInt32)busNumber; // -1 - 1
@property (assign, nonatomic) UInt32 busCount;
@end
