//
// KKAudioGraph.h
//
// Copyright (c) 2014 KKBOX Taiwan Co., Ltd. All Rights Reserved.
//

@import Foundation;
@import AudioToolbox;

@class KKAudioGraph;

/**
 * The delegate for `KKAudioGraph`.
 */
@protocol KKAudioGraphDelegate <NSObject>
/**
 * Feeds PCM data for the current media.
 * @param audioGraph the audio graph.
 * @param inNumberOfFrames the number of frames requested by the audio graph.
 * @param inIoData a block of memory to let you fill PCM data into.
 * @param inBusNumber the bus number of the mixer node for the current media.
 * @return a status code. KKAudioGraph only uses data here is the status code is noErr.
 */
- (OSStatus)audioGraph:(nonnull KKAudioGraph *)audioGraph requestNumberOfFrames:(UInt32)inNumberOfFrames ioData:(nonnull AudioBufferList *)inIoData busNumber:(UInt32)inBusNumber;

/**
 * Feeds PCM data for the fading-out previous media.
 * @param audioGraph the audio graph.
 * @param inNumberOfFrames the number of frames requested by the audio graph.
 * @param inIoData a block of memory to let you fill PCM data into.
 * @param inBusNumber the bus number of the mixer node for the previous media.
 * @return a status code. KKAudioGraph only uses data here is the status code is noErr.
 */
- (OSStatus)audioGraph:(nonnull KKAudioGraph *)audioGraph requestNumberOfFramesForCrossfade:(UInt32)inNumberOfFrames ioData:(nonnull AudioBufferList *)inIoData busNumber:(UInt32)inBusNumber;

/**
 * Called when the audio graph will start playing. You may update your UI here.
 * @param audioGraph the audio graph.
 */
- (void)audioGraphWillStartPlaying:(nonnull KKAudioGraph *)audioGraph;

/**
 * Called when the audio graph did start playing. You may update your UI here.
 * @param audioGraph the audio graph.
 */
- (void)audioGraphDidStartPlaying:(nonnull KKAudioGraph *)audioGraph;

/**
 * Called when the audio did stop playing. You may update your UI here.
 * @param audioGraph the audio graph.
 */
- (void)audioGraphDidStopPlaying:(nonnull KKAudioGraph *)audioGraph;

@optional
/**
 * Feeds the audio graph a normalization gain on a specific bus.
 *
 * Normalization gains is a mechanism to makes volume level of each tracks to be
 * similar in order to prevent the audio playback is suddenly too loud or too
 * quiet. A normalization gain is applied on each track, so it should change the
 * input volume of a bus for the mixer, but not to change the output volume.
 *
 * @param audioGraph the audio graph
 * @param busNumber the specific bus. KKAudioGraph uses bus 0 for current media,
 * and bus 1 for the fading-out previous media.
 * @return the normalization gain.
 */
- (CGFloat)audioGraph:(nonnull KKAudioGraph *)audioGraph requestNormalizationGainForBus:(UInt32)busNumber;
@end

/**
 * KKAudioGraph is a wrapper of `AUGraph`. It manages the nodes such as output
 * node, mixer node, other effect nodes and so on.
 *
 * Actually it is the main component to play PCM data. To let KKAudioGraph to do
 * audio playback, you should provide a delegate and feed PCM data to it in your
 * implementation of its delegate methods.
 */
@interface KKAudioGraph : NSObject

/** Stars playing. */
- (void)play;

/** Pauses playing. */
- (void)pause;

/**
 * Updates volume level. Since you may set the properties like
 * `usingNormalization`, `volume` and so on, KKAudioGraph calculates the exact
 * volume ought to be and apply it in the method.
 */
- (void)updateVolumeLevel;

/**
 * Changes the volume level to a specific one smoothly in 2 seconds.
 * @param targetVolume the specific volume. 0 to 1.
 */
- (void)fadeToVolume:(Float32)targetVolume;

/** Resets any running effect caused by `-fadeToVolume:` */
- (void)resetFaderVolume;

/** The delegate. */
@property (weak, nonatomic, nullable) id <KKAudioGraphDelegate> delegate;
/** Current volume. 0 to 1. */
@property (assign, nonatomic) Float32 volume;
/** If the audio graph is using audio normalization. */
@property (assign, nonatomic, getter=isUsingNormalization) BOOL usingNormalization;
/** If th audio graph is playing. */
@property (readonly, nonatomic, getter=isPlaying) BOOL playing;
@end

@interface KKAudioGraph (Mixer)
/**
 * Sets the input volume to a specific bus. In KKAudioGraph, bus 0 is for the
 * current media, while bus 1 is reserved for let the previous media to fade
 * out. While doing fading-out, you need to change the volume of bus 1
 * repeatedly.
 * @param volume the volume, 0 to 1.
 * @param busNumber the bus number. Actually it could to 0 to 7, but we only use
 * bus 0 and bus 1.
 */
- (void)setVolume:(CGFloat)volume forBus:(UInt32)busNumber;

/**
 * Makes the audio output to pan to the left or the right.
 * @param pan 1 to -1.
 */
- (void)setOutputPan:(CGFloat)pan;

/**
 * Makes the input on a specific bus to pan to the left or the right. Yo can use
 * the property to create a effect like "fading-in from left", "fading-out to
 * right" and so on.
 * @param pan 1 to -1.
 * @param busNumber  the bus number. Actually it could to 0 to 7, but we only
 * use bus 0 and bus 1.
 */
- (void)setPan:(CGFloat)pan forBus:(UInt32)busNumber;
@end

