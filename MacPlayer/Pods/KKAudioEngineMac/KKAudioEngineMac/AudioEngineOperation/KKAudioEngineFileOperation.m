//
// KKAudioEngineFileOperation.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioEngineFileOperation.h"
#import "KKAudioEngineOperation+Privates.h"

@interface KKAudioEngineFileOperation ()
@property (strong, nonatomic) NSConditionLock *conditionLock;
@property (strong, nonatomic) NSURL *URL;
@end

@implementation KKAudioEngineFileOperation

- (instancetype)initWithURL:(NSURL *)inURL suggestedFileType:(AudioFileTypeID)inTypeID;
{
	NSParameterAssert(inURL);
	NSParameterAssert(inTypeID);
	self = [super initWithSuggestedFileType:inTypeID];
	if (self) {
		self.URL = inURL;
		self.conditionLock = [[NSConditionLock alloc] initWithCondition:0];
	}
	return self;
}

- (void)main
{
	static const size_t bufferSize = 32768;

	__block NSUInteger totaReadByteDataLength = 0;

	@autoreleasepool {
		dispatch_sync(dispatch_get_main_queue(), ^{
			NSFileManager *fileManager = [[NSFileManager alloc] init];
			NSDictionary *attrs = [fileManager attributesOfItemAtPath:[self.URL path] error:nil];
			self.expectedLoadingTotalByteDataLength = [attrs fileSize];
			self.parser.delegate = self;
		});

		void *buffer = calloc(1, bufferSize);
		if (!buffer) {
			NSLog(@"Fatal error: Run out of memory");
			dispatch_sync(dispatch_get_main_queue(), ^{
				[self.delegate audioEngineOperationDidEnd:self];
			});
			return;
		}

		@try {
			NSInputStream *inputStream = [NSInputStream inputStreamWithURL:self.URL];
			[inputStream open];

			[self.conditionLock lockWhenCondition:0];
			while ([inputStream hasBytesAvailable] && ![self isCancelled]) {
				NSInteger readSize = [inputStream read:buffer maxLength:bufferSize];
				if (!readSize) {
					break;
				}

				[self.conditionLock unlockWithCondition:1];
				dispatch_sync(dispatch_get_main_queue(), ^{
					[self.conditionLock lockWhenCondition:1];
					[self feedByteData:buffer size:readSize];
					totaReadByteDataLength += readSize;
					self.loadedPercentage = totaReadByteDataLength / self.expectedLoadingTotalByteDataLength;
					[self.conditionLock unlockWithCondition:0];
				});
				[self.conditionLock lockWhenCondition:0];
			}

			[self.conditionLock unlockWithCondition:1];
			dispatch_sync(dispatch_get_main_queue(), ^{
				[self.conditionLock lockWhenCondition:1];

				if (!self.hasEnoughDataToPlay) {
					self.hasEnoughDataToPlay = YES;
					[self.delegate audioEngineOperationDidHaveEnoughDataToStartPlaying:self];
				}

				self.loaded = YES;
				self.loadedPercentage = 1.0;
				self.expectedDuration = self.loadedDuration;
				[self.delegate audioEngineOperationDidCompleteLoading:self];
				[self.conditionLock unlockWithCondition:0];
			});
			[self.conditionLock lockWhenCondition:0];
			[self.conditionLock unlockWithCondition:0];

			[inputStream close];
		}
		@catch (NSException *e) {
		}
		@finally {
		}

		[self wait];

		dispatch_sync(dispatch_get_main_queue(), ^{
			[self.delegate audioEngineOperationDidEnd:self];
		});
	}
}


@end
