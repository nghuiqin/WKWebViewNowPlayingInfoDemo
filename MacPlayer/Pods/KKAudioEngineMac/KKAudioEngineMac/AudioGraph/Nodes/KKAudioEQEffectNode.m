//
// KKAudioEQEffectNode.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioEQEffectNode.h"

@implementation KKAudioEQEffectNode

- (AudioComponentDescription)unitDescription
{
	AudioComponentDescription EQEffectUnitDescription;
	bzero(&EQEffectUnitDescription, sizeof(AudioComponentDescription));
	EQEffectUnitDescription.componentType = kAudioUnitType_Effect;
	EQEffectUnitDescription.componentSubType = kAudioUnitSubType_GraphicEQ;
	EQEffectUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	EQEffectUnitDescription.componentFlags = 0;
	EQEffectUnitDescription.componentFlagsMask = 0;
	return EQEffectUnitDescription;
}

@end
