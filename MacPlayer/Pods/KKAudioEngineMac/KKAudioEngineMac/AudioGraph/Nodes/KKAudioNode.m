//
// KKAudioNode.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioNode.h"

@interface KKAudioNode ()
{
	AUNode node;
	AudioUnit audioUnit;
}
- (void)makeAudioUnitWithAudioGraph:(AUGraph)audioGraph;
@end

@implementation KKAudioNode

- (instancetype)initWithAudioGraph:(AUGraph)audioGraph
{
	self = [super init];
	if (self) {
		OSStatus status = noErr;
		AudioComponentDescription unitDescription = [self unitDescription];
		status = AUGraphAddNode(audioGraph, &unitDescription, &node);
		NSAssert(noErr == status, @"We need to create the node. %@, %d", NSStringFromClass([self class]), (int)status);
		[self makeAudioUnitWithAudioGraph:audioGraph];
	}
	return self;
}

- (void)makeAudioUnitWithAudioGraph:(AUGraph)audioGraph
{
	__unused OSStatus status = noErr;
	AudioComponentDescription unitDescription = [self unitDescription];
	status = AUGraphNodeInfo(audioGraph, node, &unitDescription, &audioUnit);
	NSAssert(noErr == status, @"We need to get the audio unit of the node. %@, %d", NSStringFromClass([self class]), (int)status);

	UInt32 maxFPS = 4096;
	status = AudioUnitSetProperty(self.audioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maxFPS, sizeof(maxFPS));
	NSAssert(noErr == status, @"We need to set the maximum FPS(Frame Per Slice) to the EQ effect node. %d", (int)status);
}

- (AudioComponentDescription)unitDescription
{
	// Subclasses should override it.
	AudioComponentDescription unitDescription;
	bzero(&unitDescription, sizeof(AudioComponentDescription));
	return unitDescription;
}

@synthesize node;
@synthesize audioUnit;
@end
