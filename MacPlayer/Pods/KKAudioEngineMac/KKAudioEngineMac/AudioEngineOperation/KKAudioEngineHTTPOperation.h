//
// KKAudioEngineHTTPOperation.h
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioEngineOperation.h"

@interface KKAudioEngineHTTPOperation : KKAudioEngineOperation

- (instancetype)initWithURL:(NSURL *)inURL suggestedFileType:(AudioFileTypeID)inTypeID;

@property (readonly, nonatomic) NSURL *URL;
@end
