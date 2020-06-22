//
// KKAudioEngine.h
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

@import Foundation;
@import AudioToolbox;
#import "KKAudioGraph.h"
#import "KKAudioEngineOperation.h"

extern AudioFileTypeID kAudioFileFlacType;

@class KKAudioEngine;

/**
 * The protocol fot the delegate of KKAudioEngine.
 */
@protocol KKAudioEngineDelegate <NSObject>
/**
 * Called when the audio engine will start playing.
 * @param audioEngine the audio engine.
 */
- (void)audioEngineWillStartPlaying:(nonnull KKAudioEngine *)audioEngine;
/**
 * Called when the audio engine did start playing.
 * @param audioEngine the audio engine.
 */
- (void)audioEngineDidStartPlaying:(nonnull KKAudioEngine *)audioEngine;
/**
 * Called when the audio engine pauses playing.
 * @param audioEngine the audio engine.
 */
- (void)audioEngineDidPausePlaying:(nonnull KKAudioEngine *)audioEngine;
/**
 * Called when the loaded data is not big enough to continue playback. The
 * delegate may show a "buffering" message in the situation.
 *
 * Thw delegate method is called even when the audio engine is going to the
 * next playback item while doing gap-less playback.
 *
 * @param audioEngine the audio engine.
 */
- (void)audioEngineDidStall:(nonnull KKAudioEngine *)audioEngine;
/**
 * called when the current playback item goes to end.
 * @param audioEngine the audio engine.
 */
- (void)audioEngineDidEndCurrentPlayback:(nonnull KKAudioEngine *)audioEngine;
/**
 * Called when the audio engine ends playing all items.
 * @param audioEngine the audio engine.
 */
- (void)audioEngineDidEndPlaying:(nonnull KKAudioEngine *)audioEngine;
/**
 * Called when the audio engine has loaded enough data to start playing.
 * @param audioEngine the audio engine.
 */
- (void)audioEngineDidHaveEnoughDataToStartPlaying:(nonnull KKAudioEngine *)audioEngine;
/**
 * Called when the audio engine is stalled but has enough data again.
 * @param audioEngine the audio engine.
 */
- (void)audioEngineDidHaveEnoughDataToResumePlaying:(nonnull KKAudioEngine *)audioEngine;
/**
 * Called when the audio engine has fully loaded a media clip online or offline.
 * @param audioEngine the audio engine.
 */
- (void)audioEngineDidCompleteLoading:(nonnull KKAudioEngine *)audioEngine;
/**
 * Called when the audio engine fails to load a media clip.
 * @param audioEngine the audio engine.
 * @param error the error that happens while loading.
 */
- (void)audioEngine:(nonnull KKAudioEngine *)audioEngine didFailLoadingWithError:(nonnull NSError *)error;
/**
 * Called when the audio engine fails to load the waiting media clip for gapless playback.
 * @param audioEngine  the audio engine.
 * @param error the error.
 * @param contextInfo the context info on the loading operation.
 */
- (void)audioEngine:(nonnull KKAudioEngine *)audioEngine didFailLoadingNextAudioWithError:(nonnull NSError *)error contextInfo:(nullable id)contextInfo;
/**
 * Called when the current playback time changes.
 * @param audioEngine the audio engine.
 * @param currentTime the current time.
 * @param loadedDuration the loaded duration.
 */
- (void)audioEngine:(nonnull KKAudioEngine *)audioEngine updateCurrentPlaybackTime:(NSTimeInterval)currentTime loadedDuration:(NSTimeInterval)loadedDuration;

@optional

/**
 * Called when the audio engine finds out ID3 tags in
 * @param audioEngine the audio engine.
 * @param inID3Tags the ID3 tags.
 * @param operation the operation that for the media clip.
 */
- (void)audioEngine:(nonnull KKAudioEngine *)audioEngine didFindID3tags:(nonnull NSDictionary *)inID3Tags inOperation:(nonnull KKAudioEngineOperation *)operation;
/**
 * Called when an operation in the audio engine starts playing.
 * @param audioEngine the engine.
 * @param operation the operation.
 */
- (void)audioEngine:(nonnull KKAudioEngine *)audioEngine didStartPlayingOperation:(nonnull KKAudioEngineOperation *)operation;
@end

#pragma mark -

/**
 * A general-purpose audio player for KKBOX.
 *
 * It could play not only local files but also remote audio clips via HTTP. The
 * supported formats are including the formats that Core Audio supports such as
 * MP3, AAC and so on, it also supports FLAC format by adopting libFlac. You can
 * use KKAudioEngine to play continuous streams, such as Internet radio
 * stations, as well.
 *
 * The player also supports:
 *
 * - Gap-less playback.
 * - Cross-Fading effect.
 * - Audio normalization.
 * - Equalizers.
 * - Human Voice Removal.
 *
 * Note: KKAudioEngine handles audio sessions for you. once you create a new
 * instance of KKAudioEngine, it starts to make audio session active and may
 * pause other application playing audio. It is suggested to create the instance
 * by adopting lazy-loading pattern.
 */
@interface KKAudioEngine : NSObject

#pragma mark Loading resources

/**
 * Loads a local or remote audio clip.
 *
 * @param inURL URL of the audio clip. It could be a URL on the Internet, or a file URL.
 * @param inTypeID the type of the file.
 * @param contextInfo any context info object that you like.
 */
- (void)loadAudioWithURL:(nonnull NSURL *)inURL suggestedFileType:(AudioFileTypeID)inTypeID contextInfo:(nullable id)contextInfo;

/**
 * Loads a local or remote audio clip as the next item to play. Once the current playback
 * ends, KKAudioEngine will start to play the item gaplessly, or with cross-fading.
 *
 * @param inURL URL of the audio clip. It could be a URL on the Internet, or a file URL.
 * @param inTypeID the type of the file.
 * @param contextInfo any context info object that you like.
 */
- (void)loadNextAudioWithURL:(nonnull NSURL *)inURL suggestedFileType:(AudioFileTypeID)inTypeID contextInfo:(nullable id)contextInfo;

#pragma mark Playback controls

/** Resumes playing. */
- (void)play;
/** Pauses playing. */
- (void)pause;
/** Stops playing and sets the current playback item to nil. */
- (void)stop;
/** Cancels loading the next playback item, and sets it to nil. */
- (void)cancelNextOperation;

#pragma mark Basic properties

/** The delegate object. */
@property (weak, nonatomic, nullable) id <KKAudioEngineDelegate> delegate;
/** Volume of the player. 0.0 to 1.0. 1.0 by default. */
@property (assign, nonatomic) CGFloat volume;
/** Asks the player to change to a specific volume level with a fading effect. */
- (void)fadeToVolume:(Float32)targetVolume;
/** Resets the object to fade in/out player volume. */
- (void)resetFaderVolume;

/**
 * If the player should use audio normalization by the ID3 tags of audio files.
 */
@property (assign, nonatomic, getter=isUsingNormalization) BOOL usingNormalization;
@end

@interface KKAudioEngine (CurrentAudioProperties)
#pragma mark Properties for current audio resource
/** If KKAudioEngine has the current playback item. */
@property (readonly, nonatomic) BOOL hasCurrentOperation;
/** If the current item is fully loaded. */
@property (readonly, nonatomic, getter=isCurrentSongTrackFullyLoaded) BOOL currentSongTrackFullyLoaded;
/** The context info object of the current item to play. */
@property (readonly, nonatomic, nullable) id currentContextInfo;
/** If the player is playing or paused. */
@property (readonly, nonatomic, getter=isPlaying) BOOL playing;
/** If the current playback item is a continuous steam, like a Internet radio station. */
@property (readonly, nonatomic, getter=isPlayingContinuousStream) BOOL playingContinuousStream;
/** The current playback time. */
@property (assign, nonatomic) NSTimeInterval currentTime;
/** The expected length of the current playback item in seconds. */
@property (readonly, nonatomic) NSTimeInterval expectedDuration;
/** How much is the current item loaded in seconds. */
@property (readonly, nonatomic) NSTimeInterval loadedDuration;
/** How much is the current item loaded. 0.0 to 1.0. */
@property (readonly, nonatomic) CGFloat loadedPercentage;
/** ID3 tags contained in the file of the current playback item. */
@property (readonly, nonatomic, nullable) NSDictionary *ID3Tags;
/** Length of the cross-fading effect in seconds. */
@property (assign, nonatomic) NSTimeInterval crossfadeDuration;
/**
 * If the sounds of the next item comes in from left, when the sounds of current
 * item goes out to right while doing cross-fading effect.
 */
@property (assign, nonatomic) BOOL crossfadeWithPanning;
/** If KKAudioEngine should try to remove human voice in audio streams. */
@property (assign, nonatomic) BOOL usingVocalRemoval;
@end

@interface KKAudioEngine (NextAudioProperties)
#pragma mark Properties for next audio resource
/** If KKAudioEngine has next item to play right now. */
@property (readonly, nonatomic) BOOL hasNextOperation;
/** The context info object of the next item to play. */
@property (readonly, nonatomic, nullable) id nextContextInfo;
@end

@interface KKAudioEngine (AudioGraph)
/** The audio graph inside the player. */
@property (readonly, nonatomic, nonnull) KKAudioGraph * audioGraph;
@end
