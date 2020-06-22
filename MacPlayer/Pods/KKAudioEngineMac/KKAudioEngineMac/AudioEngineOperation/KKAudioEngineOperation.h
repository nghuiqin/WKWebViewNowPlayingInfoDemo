//
// KKAudioEngineOperation.h
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

@import Foundation;
@import AudioToolbox;

@class KKAudioEngineOperation;

/**
 * The delegate for `KKAudioEngineOperation`. However, it should be only
 * assigned on `KKAudioEngine`.
 */
@protocol KKAudioEngineOperationDelegate <NSObject>
/**
 * Called when the operation has buffered enough data (e.g. data for 3 seconds
 * of playback) to start playing. You can ask the audio graph to start playing
 * here.
 * @param operation the operation.
 */
- (void)audioEngineOperationDidHaveEnoughDataToStartPlaying:(nonnull KKAudioEngineOperation *)operation;

/**
 * Called when the operation was stalled but then it has enough data to (e.g
 * data for 3 seconds of playback) to resume playing. You can ask the audio
 * graph to resume player here.
 * @param operation the operation.
 */
- (void)audioEngineOperationDidHaveEnoughDataToResumePlaying:(nonnull KKAudioEngineOperation *)operation;

/**
 * Called when the operation has fully loaded a media.
 *
 * If we are playing a stream on the Internet, we may not want to wait for the
 * media to be fully downloaded and then play it, it is too slow. We may already
 * start playing even we have only partial data. However, only when the media is
 * fully downloaded, we can then know about the exact length of the media and
 * update our UI or other cached information.
 * @param operation the operation.
 */
- (void)audioEngineOperationDidCompleteLoading:(nonnull KKAudioEngineOperation *)operation;

/**
 * Called when th operation has read to the end of the media. It means you can
 * start to play the next media, if you did not enable crossfade.
 * @param operation the operation.
 */
- (void)audioEngineOperationDidEndReadingBuffer:(nonnull KKAudioEngineOperation *)operation;

/**
 * Called when the operation failed to load media. It may encounter a network
 * error, etc.
 * @param operation the operation.
 * @param error the error.
 */
- (void)audioEngineOperation:(nonnull KKAudioEngineOperation *)operation didFailLoadingWithError:(nonnull NSError *)error;

/**
 * Called when the operation has found ID3 tags from reading the media. The
 * delegate should decide to apply them to the player or not.
 * @param operation the operation.
 * @param inID3Tags the ID3 tags.
 */
- (void)audioEngineOperation:(nonnull KKAudioEngineOperation *)operation didFindID3tags:(nonnull NSDictionary *)inID3Tags;

/**
 * Called when the operation ends.
 * @param operation the operation.
 */
- (void)audioEngineOperationDidEnd:(nonnull KKAudioEngineOperation *)operation;

/**
 * Note: the delegate method is called in background threads.
 * @param operation the operation.
 * @return to begin cross fade or not.
 */
- (BOOL)audioEngineOperationShouldBeginCrossfade:(nonnull KKAudioEngineOperation *)operation;

/**
 * Note: the delegate method is called in background threads.
 * @param operation the operation.
 */
- (void)audioEngineOperationDidRequestBeginCrossfade:(nonnull KKAudioEngineOperation *)operation;
@end

/**
 * The operation used to load media clips in KKAudioEngine.
 */
@interface KKAudioEngineOperation : NSOperation

/**
 * Creates a new instance.
 * @param inTypeID the suggested audio file type.
 * @return a new instance.
 */
- (nonnull instancetype)initWithSuggestedFileType:(AudioFileTypeID)inTypeID;

/*!
 An interface to let the audio graph's render callback function to
 read conveted Linear PCM data from the opearion.

 @param inNumberOfFrames How many frames does audio graph's render
 callback function require.
 @param inIoData the aduio buffer lists which stored converted Linear
 PCM data.
 @param inBusNumber the bus numer. The render callback function may be
 bound on a mixer node. Since a mixer node accepts inputs from
 multiple buses, we can use the parameter to identify which bus is
 requesting audio data.
 */
- (OSStatus)readNumberOfFrames:(UInt32)inNumberOfFrames intoIoData:(nonnull AudioBufferList *)inIoData forBusNumber:(UInt32)inBusNumber;

/** The delegate, it should be a KKAudioEngine instance. */
@property (weak, nonatomic, nullable) id <KKAudioEngineOperationDelegate> delegate;
/** The custom context info object. */
@property (strong, nonatomic, nullable) id contextInfo;

/**
 * The current playback time of the operation. Change the property to do random
 * seek.
 */
@property (assign, nonatomic) NSTimeInterval currentTime;
/**
 * How long does the desired audio stream should be. The property should be set
 * outside of the operation, such as set by using external metadata.
 */
@property (assign, nonatomic) NSTimeInterval expectedDuration;
/** How much playable packets are loaded. */
@property (readonly, nonatomic) NSTimeInterval loadedDuration;
/**
 * If the audio stream is continuous or not. A continuous audio stream might be
 * an Internet radio station.
 */
@property (readonly, nonatomic) BOOL isContinuousStream;
/** The current loading progress. */
@property (readonly, nonatomic) double loadedPercentage;
/** If the audio stream is fully loading or not. */
@property (readonly, nonatomic) BOOL loaded;
/**
 * If the audio stream is stalled. It means the stream is not fully loaded and
 * we do not have enough packets to play since the speed of the current
 * connection is too slow, therefore we need to wait for the connections to
 * bring more packets.
 */
@property (assign, nonatomic) BOOL stalled;
/** ID3 tags contained in current audio stream. */
@property (readonly, nonatomic, nullable) NSDictionary *ID3Tags;

/** If we have enough packets to start playing. */
@property (readonly, nonatomic) BOOL hasEnoughDataToPlay;

/**
 * The duration of doing crossfade. When the property is set, the operation will
 * notify its delegate that its time to play next track in the time of the end
 * of current media minus crossfade duration.
 */
@property (assign, nonatomic) NSTimeInterval crossfadeDuration;

/** If the player should pause playing the operation when it is ready. */
@property (assign, nonatomic) BOOL pausedOnStart;
@end

@interface KKAudioEngineOperation ()
@property (readonly, nonatomic) double packetsPerSecond;
@end
