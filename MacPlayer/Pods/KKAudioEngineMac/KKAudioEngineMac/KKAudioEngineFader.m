//
// KKAudioEngineFader.m
//
// Copyright (c) 2014-2017 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioEngineFader.h"

static const NSInteger steps = 20;
static NSTimeInterval duration = 2.0; // 2 seconds

@interface KKAudioEngineFader ()

@property (readwrite, assign, nonatomic) Float32 currentVolume; // 0 to 1;

@property (readwrite, assign, nonatomic) Float32 targetVolume; // 0 to 1;
@property (readwrite, assign, nonatomic) double volumeChangePerTick;
@property (strong, nonatomic) NSTimer *timer;

@end

@implementation KKAudioEngineFader

- (instancetype)init
{
	self = [super init];
	if (self) {
		self.currentVolume = 1.0;
	}
	return self;
}

- (void)timerMethod:(NSTimer *)timer
{
	self.currentVolume += self.volumeChangePerTick;
	[self.delegate fader:self didChangeVolume:self.currentVolume];
	BOOL ended = NO;
	if (self.volumeChangePerTick > 0) {
		ended = self.currentVolume >= self.targetVolume;
	}
	else {
		ended = self.currentVolume <= self.targetVolume;
	}
	if (ended) {
		if (self.timer) {
			[self.timer invalidate];
			self.timer = nil;
		}
	}
}

- (void)fadeToVolume:(Float32)targetVolume
{
	if (self.timer) {
		[self.timer invalidate];
		self.timer = nil;
	}
	if (targetVolume > 1) {
		targetVolume = 1;
	}
	if (targetVolume < 0) {
		targetVolume = 0;
	}

	self.targetVolume = targetVolume;
	if (self.currentVolume == self.targetVolume) {
		return;
	}

	self.volumeChangePerTick = (targetVolume - self.currentVolume) / steps;
	self.timer = [NSTimer scheduledTimerWithTimeInterval:duration / steps target:self selector:@selector(timerMethod:) userInfo:nil repeats:YES];
}

- (void)resetVolume
{
	if (self.timer) {
		[self.timer invalidate];
		self.timer = nil;
	}
	self.currentVolume = 1.0;
	[self.delegate fader:self didChangeVolume:self.currentVolume];
}

@end
