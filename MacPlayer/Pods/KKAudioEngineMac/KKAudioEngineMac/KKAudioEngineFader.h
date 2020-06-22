//
// KKAudioEngineFader.h
//
// Copyright (c) 2014-2017 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

@import Foundation;

@class KKAudioEngineFader;

@protocol KKAudioEngineFaderDelegate <NSObject>
- (void)fader:(KKAudioEngineFader *)fader didChangeVolume:(Float32)volume;
@end

@interface KKAudioEngineFader : NSObject
- (void)fadeToVolume:(Float32)targetVolume;
- (void)resetVolume;

@property (assign, nonatomic) id <KKAudioEngineFaderDelegate> delegate; 
@property (readonly, assign, nonatomic) Float32 currentVolume; // 0 to 1;
@end
