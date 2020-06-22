//
// KKAudioOutputNode.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioOutputNode.h"

@implementation KKAudioOutputNode

- (AudioComponentDescription)unitDescription
{
	AudioComponentDescription outputUnitDescription;
	bzero(&outputUnitDescription, sizeof(AudioComponentDescription));
	outputUnitDescription.componentType = kAudioUnitType_Output;
	outputUnitDescription.componentSubType = kAudioUnitSubType_DefaultOutput;
	outputUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	outputUnitDescription.componentFlags = 0;
	outputUnitDescription.componentFlagsMask = 0;
	return outputUnitDescription;
}

@end
