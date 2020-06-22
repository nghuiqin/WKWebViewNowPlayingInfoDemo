//
// KKAudioMixerNode.m
//
// Copyright (c) 2008-2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioMixerNode.h"

@implementation KKAudioMixerNode

- (AudioComponentDescription)unitDescription
{
	AudioComponentDescription mixerUnitDescription;
	bzero(&mixerUnitDescription, sizeof(AudioComponentDescription));
	mixerUnitDescription.componentType = kAudioUnitType_Mixer;
	mixerUnitDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
	mixerUnitDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
	mixerUnitDescription.componentFlags = 0;
	mixerUnitDescription.componentFlagsMask = 0;
	return mixerUnitDescription;
}

- (UInt32)busCount
{
	UInt32 property = 0;
	UInt32 propertySize = sizeof(property);
	AudioUnitGetProperty(self.audioUnit, kAudioUnitProperty_BusCount, kAudioUnitScope_Input, 0, &property, &propertySize);
	return property;
}

- (void)setBusCount:(UInt32)busCount
{
	[self busCount];
	__unused OSStatus status = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_BusCount, kAudioUnitScope_Input, 0, &busCount, sizeof(busCount));
	status = AudioUnitSetParameter(self.audioUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Output, 0, 1.0, 0);
	NSAssert(noErr == status, @"We need to set bus count. %d", (int)status);
	for (UInt32 i = 0; i < busCount; i++) {
		status = AudioUnitSetParameter(self.audioUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, i, 1.0, 0);
	}
}

- (void)setVolume:(Float32)volume forBus:(UInt32)busNumber
{
	__unused OSStatus status = AudioUnitSetParameter(self.audioUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, busNumber, volume, 1);
	NSAssert(noErr == status, @"We need to set input volume. %d", (int)status);
}

- (void)setOutputPan:(Float32)pan
{
	__unused OSStatus status = AudioUnitSetParameter(self.audioUnit, kMultiChannelMixerParam_Pan, kAudioUnitScope_Output, 0, pan, 1);
	NSAssert(noErr == status, @"We need to set input volume. %d", (int)status);
}

- (void)setPan:(Float32)pan forBus:(UInt32)busNumber
{
	__unused OSStatus status = AudioUnitSetParameter(self.audioUnit, kMultiChannelMixerParam_Pan, kAudioUnitScope_Input, busNumber, pan, 1);
	NSAssert(noErr == status, @"We need to set input volume. %d", (int)status);
}

@end
