//
//  SCSession.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 27/03/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#define kRecordSessionDefaultVideoCodec AVVideoCodecH264
#define kRecordSessionDefaultVideoScalingMode AVVideoScalingModeResizeAspectFill
#define kRecordSessionDefaultOutputBitPerPixel 12
#define kRecordSessionDefaultAudioBitrate 128000
#define kRecordSessionDefaultAudioFormat kAudioFormatMPEG4AAC

extern const NSString *SCRecordSessionSegmentsKey;
extern const NSString *SCRecordSessionOutputUrlKey;
extern const NSString *SCRecordSessionDurationKey;
extern const NSString *SCRecordSessionIdentifierKey;
extern const NSString *SCRecordSessionDateKey;

@class SCRecordSession;
@protocol SCRecordSessionDelegate <NSObject>

@optional

@end

@interface SCRecordSession : NSObject

//////////////////
// GENERAL SETTINGS
////

/**
 An unique identifier generated when creating this record session.
 */
@property (readonly, nonatomic) NSString *identifier;

/**
 The date when this record session was created.
 */
@property (readonly, nonatomic) NSDate *date;

/**
 The outputUrl which will be the output file when endSession
 has been called. The default url is a generated url to the temp directory.
 */
@property (strong, nonatomic) NSURL *outputUrl;

/**
 The output file type used for the AVAssetWriter.
 If null, AVFileTypeMPEG4 will be used for a video file, AVFileTypeAppleM4E for an audio file
 */
@property (copy, nonatomic) NSString *fileType;

/**
 If true, every record segments will be tracked and added into a separate
 NSURL inside the recordSegments.
 Default is YES
 */
@property (assign, nonatomic) BOOL shouldTrackRecordSegments;

/**
 Contains every record segment as NSURL.
 If shouldTrackRecordSegments is true, every pause/record actions
 will result in a new entry in this array.
 If shouldTrackRecordSegments is false, it will contains at most one segment
 */
@property (readonly, nonatomic) NSArray *recordSegments;

/**
 The current record duration
 */
@property (readonly, nonatomic) CMTime currentRecordDuration;

/**
 The suggested maximum record duration that this session should handle
 If currentRecordDuration becomes more or equal than this value, the
 SCRecordSession will be removed from the SCRecorder
 */
@property (assign, nonatomic) CMTime suggestedMaxRecordDuration;

/**
 If suggestedMaxRecordDuration is a valid value,
 this will contains a float between 0 and 1 representing the
 recorded ratio, 1 being fully recorded.
 */
@property (readonly, nonatomic) CGFloat ratioRecorded;

/**
 Set the video dictionary used for configuring the AVAssetWriter
 If you set a non-null value here, the other settings will be ignored
 */
@property (strong, nonatomic) NSDictionary *videoOutputSettings;

/**
 Set the audio dictionary used for configuring the AVAssetWriter
 If you set a non-null value here, the other settings will be ignored
 */
@property (strong, nonatomic) NSDictionary *audioOutputSettings;

/**
 If null, the SCRecordSession will try to figure out which preset
 to use for the AVAssetExportSession when merging the recordSegments
 (this only happens when shouldTrackRecordSegments is true)
 If this value is not null, it will use this property.
 */
@property (copy, nonatomic) NSString *recordSegmentsMergePreset;

/**
 True if a recordSegment has began
 */
@property (readonly, nonatomic) BOOL recordSegmentBegan;


//////////////////
// VIDEO SETTINGS
////

/**
 Change the size of the video
 If videoOutputSettings has been changed, this property will be ignored
 If this value is CGSizeZero, the input video size received
 from the camera will be used
 Default is CGSizeZero
 */
@property (assign, nonatomic) CGSize videoSize;

/**
 Change the affine transform for the video
 If videoOutputSettings has been changed, this property will be ignored
 */
@property (assign, nonatomic) CGAffineTransform videoAffineTransform;

/**
 Changing the bits per pixel for the compression
 If videoOutputSettings has been changed, this property will be ignored
 */
@property (assign, nonatomic) Float32 videoBitsPerPixel;

/**
 Set the codec used for the video
 Default is AVVideoCodecH264
 */
@property (copy, nonatomic) NSString *videoCodec;

/**
 Set the video scaling mode
 */
@property (copy, nonatomic) NSString *videoScalingMode;

/**
 If the recorder provides video and this property is set to no, the
 recorder won't send video buffer to this session
 Default is NO
 */
@property (assign, nonatomic) BOOL shouldIgnoreVideo;

/**
 The maximum framerate that this SCRecordSession should handle
 If the camera appends too much frames, they will be dropped.
 If this property's value is 0, it will use the current video
 framerate from the camera.
 */
@property (assign, nonatomic) CMTimeScale videoMaxFrameRate;

/**
 The time scale of the video
 A value different than 1 with the sound enabled will probably fail.
 A value more than 1 will make the buffers last longer, it creates
 a slow motion effect. A value less than 1 will make the buffers be
 shorter, it creates a timelapse effect.
 */
@property (assign, nonatomic) CGFloat videoTimeScale;

/**
 If true and videoSize is CGSizeZero, the videoSize
 used will equal to the minimum width or height found,
 thus making the video square.
 */
@property (assign, nonatomic) BOOL videoSizeAsSquare;

/**
  If true, each frame will be encoded as a keyframe
 This is needed if you want to merge the recordSegments using
 the passthrough preset. This will seriously impact the video
 size. You can set this to NO and change the recordSegmentsMergePreset if you want
 a better quality/size ratio, but the merge will be slower.
 Default is NO
 */
@property (assign, nonatomic) BOOL videoShouldKeepOnlyKeyFrames;


//////////////////
// AUDIO SETTINGS
////

/**
 Set the sample rate of the audio
 If audioOutputSettings has been changed, this property will be ignored
 */
@property (assign, nonatomic) Float64 audioSampleRate;

/**
 Set the number of channels
 If audioOutputSettings is not nil,, this property will be ignored
 */
@property (assign, nonatomic) int audioChannels;

/**
 Set the bitrate of the audio
 If audioOutputSettings is not nil,, this property will be ignored
 */
@property (assign, nonatomic) int audioBitRate;

/**
 Must be like kAudioFormat* (example kAudioFormatMPEGLayer3)
 If audioOutputSettings is not nil, this property will be ignored
 */
@property (assign, nonatomic) int audioEncodeType;

/**
 If the recorder provides audio and this property is set to no, the
 recorder won't send audio buffer to this session
 Default is NO
 */
@property (assign, nonatomic) BOOL shouldIgnoreAudio;


//////////////////
// PUBLIC METHODS
////

- (id)init;

- (id)initWithDictionaryRepresentation:(NSDictionary *)dictionaryRepresentation;

/**
 Create a SCRecordSession
 */
+ (id)recordSession;

/**
 Create a SCRecordSession based on dictionary representation
 */
+ (id)recordSession:(NSDictionary *)dictionaryRepresentation;

/**
 If the video was already merged, this save
 the merged video to the camera roll
 */
- (void)saveToCameraRoll;

/**
 Start a new record segment.
 This method is automatically called by the SCRecorder
 */
- (void)beginRecordSegment:(NSError**)error;

/**
 End the current record segment.
 This method is automatically called by the SCRecorder
 when calling [SCRecorder pause] if necessary.
 segmentIndex contains the index of the segment recorded accessible
 in the recordSegments array. If error is not null, if will be -1
 If you don't remove the SCRecordSession from the SCRecorder while calling this method,
 The SCRecorder might create a new recordSegment right after automatically if it is not paused.
 */
- (void)endRecordSegment:(void(^)(NSInteger segmentIndex, NSError *error))completionHandler;

/**
 Remove the record segment at the given index and delete the associated file if asked
 Unexpected behavior can occur if you call this method if
 recordSegmentBegan is true
 */
- (void)removeSegmentAtIndex:(NSInteger)segmentIndex deleteFile:(BOOL)deleteFile;

/**
 Manually add a record segment
 Unexpected behavior can occur if you call this method if
 recordSegmentBegan is true
 */
- (void)addSegment:(NSURL *)fileUrl;

/**
 Manually insert a record segment
 Unexpected behavior can occur if you call this method if
 recordSegmentBegan is true
 */
- (void)insertSegment:(NSURL *)fileUrl atIndex:(NSInteger)segmentIndex;

/**
 Remove all the record segments and their associated files
 Unexpected behavior can occur if you call this method if
 recordSegmentBegan is true
 */
- (void)removeAllSegments;

/**
 Merge all recordSegments into the outputUrl
 */
- (void)mergeRecordSegments:(void(^)(NSError *error))completionHandler;

/**
 End the session.
 End the current recordSegment (if any), call mergeRecordSegments and
 if the merge succeed, delete every recordSegments.
 If you don't want a segment to be automatically added when calling this method,
 you should remove the SCRecordSession from the SCRecorder
 */
- (void)endSession:(void(^)(NSError *error))completionHandler;

/**
 Cancel the session.
 End the current recordSegment (if any) and call removeAllSegments
 If you don't want a segment to be automatically added when calling this method,
 you should remove the SCRecordSession from the SCRecorder
 */
- (void)cancelSession:(void(^)())completionHandler;

/**
 Returns an asset representing all the record segments
 from this record session. This can be called anytime.
 */
- (AVAsset *)assetRepresentingRecordSegments;

/**
 Returns a dictionary that represents this SCRecordSession
 This will only contains strings and can be therefore safely serialized
 in any text format
 */
- (NSDictionary *)dictionaryRepresentation;

/**
 Returns the fileType that the SCRecordSession is going to use
 */
- (NSString *)suggestedFileType;

//////////////////
// PRIVATE API
////

@property (readonly, nonatomic) BOOL videoInitialized;
@property (readonly, nonatomic) BOOL audioInitialized;
@property (readonly, nonatomic) BOOL videoInitializationFailed;
@property (readonly, nonatomic) BOOL audioInitializationFailed;
@property (readonly, nonatomic) BOOL recordSegmentReady;
@property (readonly, nonatomic) BOOL currentSegmentHasAudio;
@property (readonly, nonatomic) BOOL currentSegmentHasVideo;

- (void)initializeVideoUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer hasAudio:(BOOL)hasAudio error:(NSError **)error;
- (void)initializeAudioUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer hasVideo:(BOOL)hasVideo error:(NSError **)error;

- (void)uninitialize;

- (BOOL)appendVideoSampleBuffer:(CMSampleBufferRef)videoSampleBuffer frameDuration:(CMTime)frameDuration;
- (BOOL)appendAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer;
- (void)makeTimeOffsetDirty;

@end
