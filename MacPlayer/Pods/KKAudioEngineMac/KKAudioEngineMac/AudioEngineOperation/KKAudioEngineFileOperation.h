//
// KKAudioEngineFileOperation.h
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioEngineOperation.h"

@interface KKAudioEngineFileOperation : KKAudioEngineOperation

- (instancetype)initWithURL:(NSURL *)inURL suggestedFileType:(AudioFileTypeID)inTypeID;

@end
