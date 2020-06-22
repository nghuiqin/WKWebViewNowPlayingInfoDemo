//
// KKAudioGenericOutputNode.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioGenericOutputNode.h"

@implementation KKAudioGenericOutputNode

- (AudioComponentDescription)unitDescription
{
	AudioComponentDescription genericUnitDescription;
	bzero(&genericUnitDescription, sizeof(AudioComponentDescription));
	genericUnitDescription.componentType = kAudioUnitType_Output;
	genericUnitDescription.componentSubType = kAudioUnitSubType_GenericOutput;
	genericUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	genericUnitDescription.componentFlags = 0;
	genericUnitDescription.componentFlagsMask = 0;
	return genericUnitDescription;
}

@end
