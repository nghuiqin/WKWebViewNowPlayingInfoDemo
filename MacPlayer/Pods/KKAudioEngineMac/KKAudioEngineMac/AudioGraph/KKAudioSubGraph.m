//
// KKAudioSubGraph.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioSubGraph.h"

@implementation KKAudioSubGraph

- (instancetype)initWithAudioGraph:(AUGraph)inAudioGraph;
{
	self = [super init];
	if (self) {
		__unused OSStatus status = noErr;
		status = AUGraphNewNodeSubGraph(inAudioGraph, &node);
		NSAssert(noErr == status, @"We need to create the node for creating a new subgraph. %d", (int)status);
		status = AUGraphGetNodeInfoSubGraph(inAudioGraph, node, &audioGraph);
		NSAssert(noErr == status, @"We need to create a new subgraph. %d", (int)status);
	}
	return self;
}

@synthesize node;
@synthesize audioGraph;
@end
