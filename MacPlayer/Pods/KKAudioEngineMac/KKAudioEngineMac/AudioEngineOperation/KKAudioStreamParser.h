//
// KKAudioStreamParser.h
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

@import Foundation;
@import AudioToolbox;

@class KKAudioStreamParser;

@protocol KKAudioStreamParserDelegate <NSObject>
- (void)audioStreamParser:(KKAudioStreamParser *)inParser didObtainPacketData:(const void *)inData count:(size_t)inPacketCount descriptions:(AudioStreamPacketDescription *)inPacketDescriptions;
- (void)audioStreamParser:(KKAudioStreamParser *)inParser didObtainStreamDescription:(AudioStreamBasicDescription *)inDescription;
@optional
- (void)audioStreamParser:(KKAudioStreamParser *)inParser didObtainID3Tags:(NSDictionary *)inID3Tags;
@end

@interface KKAudioStreamParser : NSObject

- (instancetype)initWithSuggestedFileType:(AudioFileTypeID)inTypeID;
- (BOOL)feedByteData:(const void *)inByteData length:(size_t)inLength;

@property (weak, nonatomic) id <KKAudioStreamParserDelegate> delegate;
@property (readonly, nonatomic) NSUInteger totalParsedBytes;
@end
