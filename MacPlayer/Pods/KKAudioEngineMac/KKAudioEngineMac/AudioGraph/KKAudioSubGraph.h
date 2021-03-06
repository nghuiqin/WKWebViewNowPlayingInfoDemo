//
// KKAudioSubGraph.h
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

@import Foundation;
@import AudioToolbox;

@interface KKAudioSubGraph : NSObject
{
	AUNode node;
	AUGraph audioGraph;
}

- (instancetype)initWithAudioGraph:(AUGraph)audioGraph;

@property (readonly, nonatomic) AUNode node;
@property (readonly, nonatomic) AUGraph audioGraph;
@end
