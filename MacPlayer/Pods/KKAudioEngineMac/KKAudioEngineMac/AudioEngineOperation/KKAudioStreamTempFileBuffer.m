//
// KKAudioStreamTempFileBuffer.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioStreamTempFileBuffer.h"

#define MAX_PRELOAD_PACKET_COUNT 100
#define PRELOAD_HELPER_COUNT 2

typedef NS_ENUM(NSUInteger, KKAudioPreloadStatus)
{
	KKAudioPreloadStatusUnused,
	KKAudioPreloadStatusLoading,
	KKAudioPreloadStatusLoaded,
};

@interface KKAudioPreloadHelper : NSObject
{
	NSLock *lock;
	FILE *fileHandle;
	dispatch_queue_t preloadQueue;
	KKAudioPacketInfo packetInfos[MAX_PRELOAD_PACKET_COUNT];
}
@property (assign) size_t startIndex;
@property (assign) KKAudioPreloadStatus preloadStatus;
@end

@implementation KKAudioPreloadHelper
- (void)dealloc
{
	[self reset];
	fclose(fileHandle);
}

- (instancetype)initWithFilename:(NSString *)inFilename preloadQueue:(dispatch_queue_t)inPreloadQueue
{
	if (self = [super init]) {
		fileHandle = fopen([inFilename UTF8String], "r");
		lock = [[NSLock alloc] init];
		preloadQueue = inPreloadQueue;
	}
	return self;
}

- (KKAudioPacketInfo *)packetAtIndex:(size_t)inIndex
{
	if (inIndex < self.startIndex) {
		return NULL;
	}
	if (inIndex >= self.startIndex + MAX_PRELOAD_PACKET_COUNT) {
		return NULL;
	}

	size_t index = inIndex - self.startIndex;
	return &(packetInfos[index]);
}

- (void)reset
{
	free(packetInfos[0].data);
	for (int i = 0; i < MAX_PRELOAD_PACKET_COUNT; ++i) {
		packetInfos[i].data = NULL;
	}
	_preloadStatus = KKAudioPreloadStatusUnused;
}

- (void)preloadWithPackets:(KKAudioPacketInfo *)inPackets
{
	size_t tmpBufferSize = 0;
	for (size_t i = 0; i < MAX_PRELOAD_PACKET_COUNT; ++i) {
		self->packetInfos[i] = inPackets[self.startIndex + i];
		self->packetInfos[i].packetDescription.mStartOffset = tmpBufferSize;
		tmpBufferSize += packetInfos[i].packetDescription.mDataByteSize;
	}
	dispatch_async(preloadQueue, ^{
		long filePos = (long) self->packetInfos[0].data;
		self->packetInfos[0].data = malloc(tmpBufferSize);
		fseek(self->fileHandle, filePos, SEEK_SET);
		fread(self->packetInfos[0].data, tmpBufferSize, 1, self->fileHandle);

		for (size_t i = 1; i < MAX_PRELOAD_PACKET_COUNT; ++i) {
			self->packetInfos[i].data = self->packetInfos[0].data + self->packetInfos[i].packetDescription.mStartOffset;
		}

		self->_preloadStatus = KKAudioPreloadStatusLoaded;
	});
}

- (void)lock
{
	[lock lock];
}

- (void)unlock
{
	[lock unlock];
}
@end

@interface KKAudioStreamTempFileBuffer ()
{
	NSString *tempFilename;
	FILE *writeFileHandle;
	FILE *readFileHandle;

	BOOL everPreload;
	NSMutableArray *preloadHelpers;

	KKAudioPacketInfo tmpInfo;
}
@end

@implementation KKAudioStreamTempFileBuffer

- (void)preloadIfNeeded
{
	NSMutableArray *unusedHelpers = [[NSMutableArray alloc] init];
	NSMutableArray *usingHelpers = [[NSMutableArray alloc] init];
	NSMutableArray *validHelpers = [[NSMutableArray alloc] init];

	for (KKAudioPreloadHelper *helper in preloadHelpers) {
		[helper lock];
		if (helper.preloadStatus == KKAudioPreloadStatusUnused) {
			[unusedHelpers addObject:helper];
		}
		else {
			[usingHelpers addObject:helper];
		}
		[helper unlock];
	}

	size_t indexNeedPreload = packetReadIndex;
	BOOL indexNotFound = NO;
	while (!indexNotFound) {
		BOOL indexPreloaded = NO;
		for (KKAudioPreloadHelper *helper in usingHelpers) {
			[helper lock];
			if ([helper packetAtIndex:indexNeedPreload] != NULL) {
				indexNeedPreload = helper.startIndex + MAX_PRELOAD_PACKET_COUNT;
				indexPreloaded = YES;
				[validHelpers addObject:helper];
				[helper unlock];
				break;
			}
			[helper unlock];
		}
		if (!indexPreloaded) {
			indexNotFound = YES;
		}
	}

	for (KKAudioPreloadHelper *helper in usingHelpers) {
		if (![validHelpers containsObject:helper]) {
			[helper lock];
			if (helper.preloadStatus == KKAudioPreloadStatusLoaded && [helper packetAtIndex:packetReadIndex] == NULL) {
				[helper reset];
				[unusedHelpers addObject:helper];
			}
			[helper unlock];
		}
	}

	KKAudioPreloadHelper *helper = [unusedHelpers firstObject];
	if (!helper) {
		return;
	}

	if (indexNeedPreload + MAX_PRELOAD_PACKET_COUNT >= availablePacketCount) {
		return;
	}

	[helper lock];
	helper.preloadStatus = KKAudioPreloadStatusLoading;
	helper.startIndex = indexNeedPreload;
	@synchronized (self) {
		[helper preloadWithPackets:packets];
	}
	[helper unlock];
}

- (void)dealloc
{
	@synchronized (self) {
		if (writeFileHandle) {
			fclose(writeFileHandle);
		}
		writeFileHandle = NULL;

		if (readFileHandle) {
			fclose(readFileHandle);
		}
		readFileHandle = NULL;

		if (tempFilename) {
			NSError *error = nil;
			NSFileManager *fileManager = [[NSFileManager alloc] init];
			BOOL removeDone = [fileManager removeItemAtPath:tempFilename error:&error];
			if (!removeDone) {
				NSLog(@"Fatal: Cannot remove file: %@, error: %@", tempFilename, error);
			}
		}
		tempFilename = nil;

		for (size_t index = 0; index < packetCount; index++) {
			packets[index].data = NULL;
		}

		if (tmpInfo.data) {
			free(tmpInfo.data);
			tmpInfo.data = NULL;
		}
	}
}

- (instancetype)initWithMaximumPacketCount:(size_t)inCount
{
	NSAssert(inCount == KKAudioStreamBufferIndeterminatePacketCount, @"Temp file buffer is not designed for continous stream");

	if (self = [super initWithMaximumPacketCount:inCount]) {
		CFUUIDRef uuid = CFUUIDCreate(NULL);
		CFStringRef uuidStr = CFUUIDCreateString(NULL, uuid);
		CFRelease(uuid);

		tempFilename = [NSTemporaryDirectory() stringByAppendingFormat:@"LFASTFB-%@", (__bridge NSString *) uuidStr];
		CFRelease(uuidStr);
		writeFileHandle = fopen([tempFilename UTF8String], "w+");
		readFileHandle = fopen([tempFilename UTF8String], "r");

		dispatch_queue_t preloadQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		preloadHelpers = [NSMutableArray arrayWithCapacity:PRELOAD_HELPER_COUNT];
		for (int i = 0; i < PRELOAD_HELPER_COUNT; ++i) {
			[preloadHelpers addObject:[[KKAudioPreloadHelper alloc] initWithFilename:tempFilename preloadQueue:preloadQueue]];
		}
	}

	return self;
}

- (void)storePacketData:(const void *)inData count:(size_t)inPacketCount descriptions:(AudioStreamPacketDescription *)inPacketDescriptions
{
	if (!writeFileHandle) {
		return;
	}
	if (self.isBufferForContinuousStream) {
		NSAssert(NO, @"Temp file buffer is not designed for continous stream");
	}
	if (!inPacketDescriptions) {
		NSAssert(NO, @"Must have packet descriptions");
		return;
	}

	@synchronized (self) {
		if (packetWriteIndex + inPacketCount >= packetCount) {
			// grow the buffer
			size_t oldSize = packetCount * sizeof(KKAudioPacketInfo);
			while (packetCount < packetWriteIndex + inPacketCount) {
				packetCount = packetCount * 2;
			}
			packets = (KKAudioPacketInfo *) realloc(packets, packetCount * sizeof(KKAudioPacketInfo));
			NSAssert(packets, @"Must allocate enough memory for packets");

			// zero out the realloc'ed area; remember we need to case packets to byte semantic
			// otherwise it would be interpreted as (void *)&packets[oldSize]
			bzero(((void *) packets) + oldSize, packetCount * sizeof(KKAudioPacketInfo) - oldSize);
		}
	}

	fseek(writeFileHandle, 0, SEEK_END);
	void *filePos = (void *) ftell(writeFileHandle);

	size_t tmpBufferSize = 0;
	for (size_t index = 0; index < inPacketCount; index++) {
		packets[packetWriteIndex + index].data = filePos;
		packets[packetWriteIndex + index].packetDescription = inPacketDescriptions[index];
		tmpBufferSize += inPacketDescriptions[index].mDataByteSize;
		filePos += inPacketDescriptions[index].mDataByteSize;
	}

	if (tmpBufferSize > 0) {
		void *tmpBuffer = malloc(tmpBufferSize);
		size_t offset = 0;

		for (size_t index = 0; index < inPacketCount; index++) {
			memcpy(tmpBuffer + offset, inData + inPacketDescriptions[index].mStartOffset, inPacketDescriptions[index].mDataByteSize);
			offset += inPacketDescriptions[index].mDataByteSize;
		}
		fwrite(tmpBuffer, tmpBufferSize, 1, writeFileHandle);
		free(tmpBuffer);
	}

	packetWriteIndex += inPacketCount;
	availablePacketCount += inPacketCount;

	if (availablePacketCount > MAX_PRELOAD_PACKET_COUNT && !everPreload) {
		everPreload = YES;
		[self preloadIfNeeded];
	}
}

- (void)setPacketReadIndex:(size_t)inPacketReadIndex
{
	[super setPacketReadIndex:inPacketReadIndex];
	[self preloadIfNeeded];
}

- (KKAudioPacketInfo)emptyInfo
{
	KKAudioPacketInfo info;
	info.data = NULL;
	return info;
}

- (KKAudioPacketInfo)currentPacketInfo
{
	if (tmpInfo.data) {
		free(tmpInfo.data);
		tmpInfo.data = NULL;
	}

	KKAudioPacketInfo info = [self currentPacketInfoFromPreloadHelper];
	if (info.data == NULL && self.availablePacketCount > MAX_PRELOAD_PACKET_COUNT) {
		BOOL preloading = NO;
		for (KKAudioPreloadHelper *helper in preloadHelpers) {
			[helper lock];
			if (helper.preloadStatus == KKAudioPreloadStatusLoading && [helper packetAtIndex:packetReadIndex] != NULL) {
				preloading = YES;
				[helper unlock];
				break;
			}
			[helper unlock];
		}

		if (!preloading) {
			return [self currentPacketInfoFromFile];
		}
	}
	return info;
}

- (KKAudioPacketInfo)currentPacketInfoFromPreloadHelper
{
	KKAudioPacketInfo *availableInfo = NULL;
	for (KKAudioPreloadHelper *helper in preloadHelpers) {
		[helper lock];
		if (helper.preloadStatus == KKAudioPreloadStatusLoaded && [helper packetAtIndex:packetReadIndex] != NULL) {
			availableInfo = [helper packetAtIndex:packetReadIndex];
			[helper unlock];
			break;
		}
		[helper unlock];
	}

	if (!availableInfo) {
		return [self emptyInfo];
	}

	KKAudioPacketInfo info = *availableInfo;
	tmpInfo.packetDescription = info.packetDescription;

	size_t packetMemorySize = info.packetDescription.mDataByteSize;
	void *packetMemory = malloc(packetMemorySize);
	memcpy(packetMemory, info.data, packetMemorySize);
	tmpInfo.data = packetMemory;
	return tmpInfo;
}

- (KKAudioPacketInfo)currentPacketInfoFromFile
{
	@synchronized (self) {
		if (packets[packetReadIndex].data == NULL && packetReadIndex > 0) {
			return [self emptyInfo];
		}
		KKAudioPacketInfo info = packets[packetReadIndex];
		tmpInfo.packetDescription = info.packetDescription;

		size_t packetMemorySize = info.packetDescription.mDataByteSize;
		void *packetMemory = malloc(packetMemorySize);
		fseek(readFileHandle, (long) info.data, SEEK_SET);
		fread(packetMemory, packetMemorySize, 1, readFileHandle);
		tmpInfo.data = packetMemory;
		return tmpInfo;
	}
}

@end
