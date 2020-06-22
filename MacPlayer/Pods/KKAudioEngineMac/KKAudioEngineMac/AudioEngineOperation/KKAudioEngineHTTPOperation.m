//
// KKAudioEngineHTTPOperation.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioEngineHTTPOperation.h"
#import "KKAudioEngineOperation+Privates.h"

@interface KKAudioEngineHTTPOperation ()
@property (strong, nonatomic) NSURLConnection *connection;
@property (strong, nonatomic) NSURL *URL;
@property (assign, nonatomic) NSUInteger totalReceivedByteDataLength;
@end

@interface KKAudioEngineHTTPOperation (NSURLConnectionDelegate) <NSURLConnectionDelegate>
@end

@implementation KKAudioEngineHTTPOperation

- (void)dealloc
{
	[self.connection cancel];
	self.connection = nil;
}

- (instancetype)initWithURL:(NSURL *)inURL suggestedFileType:(AudioFileTypeID)inTypeID
{
	NSParameterAssert(inURL);
	NSParameterAssert(inTypeID);
	self = [super initWithSuggestedFileType:inTypeID];
	if (self) {
		self.URL = inURL;
	}
	return self;
}

- (void)main
{
	@autoreleasepool {
		dispatch_sync(dispatch_get_main_queue(), ^{
			NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:self.URL];
			self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
			[self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
			[self.connection start];
			self.parser.delegate = self;
		});

		[self wait];

		dispatch_sync(dispatch_get_main_queue(), ^{
			[self.delegate audioEngineOperationDidEnd:self];
		});
	}
}

@end

@implementation KKAudioEngineHTTPOperation (NSURLConnectionDelegate)

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	self.expectedLoadingTotalByteDataLength = response.expectedContentLength;
	self.isContinuousStream = (self.expectedLoadingTotalByteDataLength == NSUIntegerMax);
	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		NSHTTPURLResponse *HTTPResponse = (NSHTTPURLResponse *) response;
		if (HTTPResponse.statusCode != 200 && HTTPResponse.statusCode != 206) {
			self.runloopRunning = NO;
			NSError *error = [NSError errorWithDomain:@"KKAudioEngineHTTPOperationDomain" code:HTTPResponse.statusCode userInfo:@{NSLocalizedDescriptionKey:@"HTTP code error."}];
			[self.delegate audioEngineOperation:self didFailLoadingWithError:error];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[self feedByteData:data.bytes size:data.length];
	self.totalReceivedByteDataLength += data.length;
	self.loadedPercentage = self.totalReceivedByteDataLength / self.expectedLoadingTotalByteDataLength;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	if (!self.hasEnoughDataToPlay) {
		self.hasEnoughDataToPlay = YES;
		[self.delegate audioEngineOperationDidHaveEnoughDataToStartPlaying:self];
	}

	self.loaded = YES;
	self.loadedPercentage = 1.0;
	self.expectedDuration = self.loadedDuration;
	[self.delegate audioEngineOperationDidCompleteLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	self.runloopRunning = NO;
	[self.delegate audioEngineOperation:self didFailLoadingWithError:error];
}

@end

