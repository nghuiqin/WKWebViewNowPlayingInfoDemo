//
// KKAudioStreamParser.m
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

#import "KKAudioStreamParser.h"

static void LFAudioStreamParserPacketListener(void *inClientData, UInt32 inNumberBytes, UInt32 inNumberPackets, const void *inInputData, AudioStreamPacketDescription *inPacketDescriptions);
static void LFAudioStreamParserPropertyListener(void *inClientData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 *ioFlags);
static UInt32 MASK(UInt32 bits);
static UInt32 readUInt28(NSData *inData, UInt32 nLen);

@interface KKAudioStreamParser ()
{
	AudioFileStreamID audioFileStream;

	BOOL endParsingID3TagHeader;
	BOOL endParsingID3Tag;
	NSMutableData *ID3TagHeaderData;
	NSMutableData *ID3TagData;
	NSUInteger expectedID3TagLength;
}
@property (assign, nonatomic) NSUInteger totalParsedBytes;
@end

@implementation KKAudioStreamParser

- (void)dealloc
{
	if (audioFileStream) {
		__unused OSStatus status = AudioFileStreamClose(audioFileStream);
		NSAssert1(status == noErr, @"Must close audio file stream, error code: %d", (int) status);
		audioFileStream = NULL;
	}
}

- (instancetype)initWithSuggestedFileType:(AudioFileTypeID)inTypeID;
{
	self = [super init];
	if (self) {
		OSStatus status;
		status = AudioFileStreamOpen((__bridge void *) (self), LFAudioStreamParserPropertyListener, LFAudioStreamParserPacketListener, inTypeID, &audioFileStream);
		if (status != noErr) {
			NSLog(@"Fatal error: Cannot initialize audio file stream, error code: %d", (int) status);
			return nil;
		}
		expectedID3TagLength = 0;
		ID3TagHeaderData = [[NSMutableData alloc] init];
		ID3TagData = [[NSMutableData alloc] init];
	}
	return self;
}


- (void)_parseID3tagWithByteData:(const void *)inByteData length:(size_t)inLength
{
	NSUInteger ID3BodyOffset = 0;
	if (!endParsingID3TagHeader) {
		NSUInteger requiredLength = 10 - [ID3TagHeaderData length];
		if (inLength >= requiredLength) {
			endParsingID3TagHeader = YES;
			[ID3TagHeaderData appendBytes:inByteData length:requiredLength];
			NSString *headerString = [[NSString alloc] initWithData:ID3TagHeaderData encoding:NSUTF8StringEncoding];
			if ([headerString hasPrefix:@"ID3"]) {
				NSData *IDTagBodyLengthData = [ID3TagHeaderData subdataWithRange:NSMakeRange(6, 4)];
				expectedID3TagLength = readUInt28(IDTagBodyLengthData, 4);
				ID3BodyOffset = 10;
			}
			else {
				endParsingID3Tag = YES;
			}
			ID3TagHeaderData = nil;
		}
		else {
			[ID3TagHeaderData appendBytes:inByteData length:inLength];
		}
	}
	if (endParsingID3TagHeader && !endParsingID3Tag) {
		NSUInteger requiredLength = expectedID3TagLength - [ID3TagData length];
		NSData *incomdingData = [NSData dataWithBytes:inByteData length:inLength];
		if (inLength - ID3BodyOffset >= requiredLength) {
			endParsingID3Tag = YES;
			[ID3TagData appendData:[incomdingData subdataWithRange:NSMakeRange(ID3BodyOffset, requiredLength)]];
			UInt32 readHead = 0;
			NSMutableDictionary *ID3Tags = [NSMutableDictionary dictionary];
			while (readHead < expectedID3TagLength) {
				NSData *frameHeaderData = [ID3TagData subdataWithRange:NSMakeRange(readHead, 10)];
				NSData *frameIDData = [frameHeaderData subdataWithRange:NSMakeRange(0, 4)];
				NSData *frameBodyLengthData = [frameHeaderData subdataWithRange:NSMakeRange(4, 4)];
				NSString *frameID = [[NSString alloc] initWithData:frameIDData encoding:NSUTF8StringEncoding];
				UInt32 frameBodyLength = readUInt28(frameBodyLengthData, 4);
				if ([frameID hasPrefix:@"NORV"] || [frameID hasPrefix:@"T"]) {
					NSData *frameBodyData = [ID3TagData subdataWithRange:NSMakeRange(readHead + 10, frameBodyLength)];
					const char *textEncodingType = nil;
					[frameBodyData getBytes:&textEncodingType length:1];
					NSInteger type = (int) textEncodingType;
					NSData *frameContentData = [frameBodyData subdataWithRange:NSMakeRange(1, [frameBodyData length] - 1)];
					NSStringEncoding encoding = NSUTF8StringEncoding;
					switch (type) {
						case 0:
							encoding = NSUTF8StringEncoding;
							break;
						case 1:
							encoding = NSUTF16LittleEndianStringEncoding;
							break;
						case 2:
							encoding = NSUTF16BigEndianStringEncoding;
							break;
						case 3:
						default:
							encoding = NSUTF8StringEncoding;
							break;
					}
					NSString *contentString = [[NSString alloc] initWithData:frameContentData encoding:encoding];
					if (contentString) {
						[ID3Tags setObject:contentString forKey:frameID];
					}
				}
				readHead += 10 + frameBodyLength;
			}
			if ([[ID3Tags allKeys] count]) {
				if ([self.delegate respondsToSelector:@selector(audioStreamParser:didObtainID3Tags:)]) {
					[self.delegate audioStreamParser:self didObtainID3Tags:ID3Tags];
				}
			}
			ID3TagData = nil;
		}
		else {
			[ID3TagData appendData:[incomdingData subdataWithRange:NSMakeRange(ID3BodyOffset, inLength - ID3BodyOffset)]];
		}
	}
}

- (BOOL)feedByteData:(const void *)inByteData length:(size_t)inLength
{
	if (!inLength) {
		return NO;
	}

	@synchronized (self) {
		@try {
			[self _parseID3tagWithByteData:inByteData length:inLength];
		}
		@catch (NSException *e) {
		}

		if (audioFileStream && endParsingID3Tag) {
			OSStatus status = AudioFileStreamParseBytes(audioFileStream, (UInt32) inLength, inByteData, 0);
			self.totalParsedBytes += (NSUInteger) inLength;
			return status == noErr;
		}
	}
	return NO;
}

@end

void LFAudioStreamParserPacketListener(void *inClientData, UInt32 inNumberBytes, UInt32 inNumberPackets, const void *inInputData, AudioStreamPacketDescription *inPacketDescriptions) {
	@autoreleasepool {
		KKAudioStreamParser *self = (__bridge KKAudioStreamParser *) inClientData;
		if (inPacketDescriptions == NULL) {
			/*
			 If inPacketDescriptions is NULL, it means it is an uncompressed audio stream.
			 */
			UInt32 packetSize = inNumberBytes / inNumberPackets;
			AudioStreamPacketDescription *packetDescription = (AudioStreamPacketDescription *) malloc(sizeof(AudioStreamPacketDescription) * inNumberPackets);

			for (NSInteger i = 0; i < inNumberPackets; i++) {
				UInt32 packetOffset = (UInt32) (packetSize * i);
				packetDescription[i].mStartOffset = packetOffset;
				packetDescription[i].mVariableFramesInPacket = 0;
				if (i == inNumberPackets - 1) {
					packetDescription[i].mDataByteSize = inNumberBytes - packetOffset;
				}
				else {
					packetDescription[i].mDataByteSize = packetSize;
				}
			}
			[self.delegate audioStreamParser:self didObtainPacketData:inInputData count:(size_t) inNumberPackets descriptions:packetDescription];
			free(packetDescription);
			return;
		}
		[self.delegate audioStreamParser:self didObtainPacketData:inInputData count:(size_t) inNumberPackets descriptions:inPacketDescriptions];
	}
}

void LFAudioStreamParserPropertyListener(void *inClientData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, UInt32 *ioFlags) {
	@autoreleasepool {
		if (inPropertyID == 'dfmt') {
			AudioStreamBasicDescription description;
			UInt32 descriptionSize = sizeof(description);
			AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &descriptionSize, &description);
			KKAudioStreamParser *self = (__bridge KKAudioStreamParser *) inClientData;
			[self.delegate audioStreamParser:self didObtainStreamDescription:&description];
		}
	}
}

static UInt32 MASK(UInt32 bits) {
	return ((1 << (bits)) - 1);
}

static UInt32 readUInt28(NSData *inData, UInt32 nLen) {
	UInt32 val = 0;
	short BITSUSED = 7;
	UInt32 MAXVAL = MASK(BITSUSED * 4);
	const char *bytes = [inData bytes];

	for (int i = 0; i < nLen; ++i) {
		UInt32 c = *(bytes + i);
		val = (val << BITSUSED) | (c & MASK(BITSUSED));
	}

	return ((val) < (MAXVAL) ? (val) : (MAXVAL));
}
