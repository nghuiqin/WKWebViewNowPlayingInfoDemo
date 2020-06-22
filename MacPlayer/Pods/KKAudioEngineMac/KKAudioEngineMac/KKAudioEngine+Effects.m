//
// KKAudioEngine+Effects.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioEngine+Effects.h"
#import "KKAudioGraph.h"
#import "KKAudioNode.h"
#import "KKAudioNode+View.h"

@interface KKAudioGraph (Privates)
@property (readonly, nonatomic) KKAudioNode *EQEffectNode;
@end

@implementation KKAudioEngine (Effects)

- (NSView *)EQControlView
{
	return self.audioGraph.EQEffectNode.view;
}

@end
