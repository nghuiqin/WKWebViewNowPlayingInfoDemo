//
// KKAudioEngineOperation+Privates.h
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioEngineOperation.h"
#import "KKAudioStreamParser.h"
#import "KKAudioStreamBuffer.h"
#import "KKAudioStreamTempFileBuffer.h"
#import "KKAudioConverter.h"

@interface KKAudioEngineOperation ()
@property (strong, nonatomic) KKAudioStreamParser *parser;
@property (strong, nonatomic) KKAudioStreamBuffer *buffer;
@property (strong, nonatomic) KKAudioConverter *converter;
@property (assign, nonatomic) BOOL hasEnoughDataToPlay;
@property (assign, nonatomic) NSUInteger expectedLoadingTotalByteDataLength;
@property (assign, nonatomic) BOOL loaded;
@property (assign, nonatomic) double loadedPercentage;
@property (assign, nonatomic) BOOL isContinuousStream;
@property (strong, nonatomic) NSDictionary *ID3Tags;

@property (assign, nonatomic) BOOL runloopRunning;
@property (strong, nonatomic) NSPort *port;
@end

@interface KKAudioEngineOperation (Privates)
- (void)wait;
- (void)quitRunLoop;
- (void)feedByteData:(const void *)inBytes size:(NSUInteger)inBlockSize;
@end

@interface KKAudioEngineOperation (KKAudioStreamParserDelegate) <KKAudioStreamParserDelegate>
@end
