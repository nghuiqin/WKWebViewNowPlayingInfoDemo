//
// KKAudioEngineOperation+Privates.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioEngineOperation+Privates.h"

static NSUInteger KKAudioURLStreamPlayer_defaultTempFileUsageThreshold = 8 * 1024 * 1024;    // 8 MB
static const size_t kDefaultAudioStreamBufferPacketCountForContinuousStream = 1024;

@implementation KKAudioEngineOperation (Privates)

- (void)wait
{
	self.port = [[NSPort alloc] init];
	[[NSRunLoop currentRunLoop] addPort:self.port forMode:NSDefaultRunLoopMode];
	self.runloopRunning = YES;
	while (self.runloopRunning) {
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
	}
	[[NSRunLoop currentRunLoop] removePort:self.port forMode:NSDefaultRunLoopMode];
	self.port = nil;
}

- (void)quitRunLoop
{
	self.runloopRunning = NO;
}

- (void)feedByteData:(const void *)inBytes size:(NSUInteger)inBlockSize
{
	if (!self.expectedLoadingTotalByteDataLength) {
		return;
	}
	if (!self.buffer) {
		if (self.expectedLoadingTotalByteDataLength != NSUIntegerMax && self.expectedLoadingTotalByteDataLength > KKAudioURLStreamPlayer_defaultTempFileUsageThreshold) {
			self.buffer = [[KKAudioStreamTempFileBuffer alloc] initWithMaximumPacketCount:KKAudioStreamBufferIndeterminatePacketCount];
		}
		else {
			self.buffer = [[KKAudioStreamBuffer alloc] initWithMaximumPacketCount:(self.expectedLoadingTotalByteDataLength == NSUIntegerMax ? kDefaultAudioStreamBufferPacketCountForContinuousStream : KKAudioStreamBufferIndeterminatePacketCount)];
		}
	}
	[self.parser feedByteData:inBytes length:inBlockSize];
}

@end
