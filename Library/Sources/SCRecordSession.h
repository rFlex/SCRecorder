//
//  SCSession.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 27/03/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SCRecordSessionSegment.h"

#define kRecordSessionDefaultVideoCodec AVVideoCodecH264
#define kRecordSessionDefaultVideoScalingMode AVVideoScalingModeResizeAspectFill
#define kRecordSessionDefaultOutputBitPerPixel 12
#define kRecordSessionDefaultAudioBitrate 128000
#define kRecordSessionDefaultAudioFormat kAudioFormatMPEG4AAC

extern NSString *__nonnull const SCRecordSessionSegmentFilenameKey;
extern NSString *__nonnull const SCRecordSessionSegmentFilenamesKey;
extern NSString *__nonnull const SCRecordSessionSegmentsKey;
extern NSString *__nonnull const SCRecordSessionDurationKey;
extern NSString *__nonnull const SCRecordSessionIdentifierKey;
extern NSString *__nonnull const SCRecordSessionSegmentInfoKey;
extern NSString *__nonnull const SCRecordSessionDateKey;
extern NSString *__nonnull const SCRecordSessionDirectoryKey;

extern NSString *__nonnull const SCRecordSessionTemporaryDirectory;
extern NSString *__nonnull const SCRecordSessionCacheDirectory;
extern NSString *__nonnull const SCRecordSessionDocumentDirectory;

@class SCRecordSession;
@class SCRecorder;

@interface SCRecordSession : NSObject

//////////////////
// GENERAL SETTINGS
////

/**
 An unique identifier generated when creating this record session.
 */
@property (readonly, nonatomic) NSString *__nonnull identifier;

/**
 The date when this record session was created.
 */
@property (readonly, nonatomic) NSDate *__nonnull date;

/**
 The directory to which the record segments will be saved.
 Can be either SCRecordSessionTemporaryDirectory or an arbritary directory.
 Default is SCRecordSessionTemporaryDirectory.
 */
@property (copy, nonatomic) NSString *__nonnull segmentsDirectory;

/**
 The output file type used for the AVAssetWriter.
 If null, AVFileTypeMPEG4 will be used for a video file, AVFileTypeAppleM4A for an audio file
 */
@property (copy, nonatomic) NSString *__nullable fileType;

/**
 The extension of every record segments.
 If null, the SCRecordSession will figure out one depending on the fileType.
 */
@property (copy, nonatomic) NSString *__nullable fileExtension;

/**
 The output url based on the identifier, the recordSegmentsDirectory and the fileExtension
 */
@property (readonly, nonatomic) NSURL *__nonnull outputUrl;

/**
 Contains every record segment as SCRecordSessionSegment.
 */
@property (readonly, nonatomic) NSArray *__nonnull segments;

/**
 The duration of the whole recordSession including the current recording segment
 and the previously added record segments.
 */
@property (readonly, nonatomic) CMTime duration;

/**
 The duration of the recorded record segments.
 */
@property (readonly, atomic) CMTime segmentsDuration;

/**
 The duration of the current recording segment.
 */
@property (readonly, atomic) CMTime currentSegmentDuration;

/**
 True if a recordSegment has began
 */
@property (readonly, nonatomic) BOOL recordSegmentBegan;

/**
 The recorder that is managing this SCRecordSession
 */
@property (readonly, nonatomic, weak) SCRecorder *__nullable recorder;

//////////////////
// PUBLIC METHODS
////

- (nonnull instancetype)init;

- (nonnull instancetype)initWithDictionaryRepresentation:(nonnull NSDictionary *)dictionaryRepresentation;

/**
 Create a SCRecordSession
 */
+ (nonnull instancetype)recordSession;

/**
 Create a SCRecordSession based on dictionary representation
 */
+ (nonnull instancetype)recordSession:(nonnull NSDictionary *)dictionaryRepresentation;

/**
 Calling any method of SCRecordSession is thread safe. However,
 if the record session is inside an SCRecorder instance, its state
 might change between 2 calls you are making. Making any modification
 within this block will ensure that you are the only one who has
 access to any modification on this SCRecordSession.
 */
- (void)dispatchSyncOnSessionQueue:(void(^__nonnull)())block;

//////////////////////
/////// SEGMENTS
////

/**
 Remove the record segment. Does not delete the associated file.
 */
- (void)removeSegment:(SCRecordSessionSegment *__nonnull)segment;

/**
 Remove the record segment at the given index.
 */
- (void)removeSegmentAtIndex:(NSInteger)segmentIndex deleteFile:(BOOL)deleteFile;

/**
 Add a recorded segment.
 */
- (void)addSegment:(SCRecordSessionSegment *__nonnull)segment;

/**
 Insert a record segment.
 */
- (void)insertSegment:(SCRecordSessionSegment *__nonnull)segment atIndex:(NSInteger)segmentIndex;

/**
 Remove all the record segments and their associated files.
 */
- (void)removeAllSegments;

/**
 Remove all the record segments and their associated files if deleteFiles is true.
 */
- (void)removeAllSegments:(BOOL)deleteFiles;

/**
 Remove the last segment safely. Does nothing if no segment were recorded.
 */
- (void)removeLastSegment;

/**
 Cancel the session.
 End the current recordSegment (if any) and call removeAllSegments
 If you don't want a segment to be automatically added when calling this method,
 you should remove the SCRecordSession from the SCRecorder
 */
- (void)cancelSession:(void(^ __nullable)())completionHandler;

/**
 Merge the recorded record segments using the given AVAssetExportSessionPreset.
 Returns the AVAssetExportSession used for exporting.
 Returns nil and call the completion handler block synchronously if an error happend while preparing the export session.
 */
- (AVAssetExportSession *__nullable)mergeSegmentsUsingPreset:(NSString *__nonnull)exportSessionPreset completionHandler:(void(^__nonnull)(NSURL *__nullable outputUrl, NSError *__nullable error))completionHandler;

/**
 Returns an asset representing all the record segments
 from this record session. This can be called anytime.
 */
- (AVAsset *__nonnull)assetRepresentingSegments;

/**
 Returns a player item representing all the record segments
 from this record session and containing an audio mix that smooth
 the transition between the segments.
 */
- (AVPlayerItem *__nonnull)playerItemRepresentingSegments;

/**
 Append all the record segments to a given AVMutableComposition.
 */
- (void)appendSegmentsToComposition:(AVMutableComposition *__nonnull)composition;

/**
 Append all the record segments to a given AVMutableComposition and adds the audio mix instruction
 if audioMix is provided
 */
- (void)appendSegmentsToComposition:(AVMutableComposition *__nonnull)composition audioMix:(AVMutableAudioMix *__nullable)audioMix;

/**
 Returns a dictionary that represents this SCRecordSession
 This will only contains strings and can be therefore safely serialized
 in any text format
 */
- (NSDictionary *__nonnull)dictionaryRepresentation;

/**
 Stop the current segment and deinitialize the video and the audio.
 This can be usefull if the input video or audio profile changed.
 */
- (void)deinitialize;

/**
 Start a new record segment.
 This method is automatically called by the SCRecorder.
 */
- (void)beginSegment:(NSError*__nullable*__nullable)error;

/**
 End the current record segment.
 This method is automatically called by the SCRecorder
 when calling [SCRecorder pause] if necessary.
 segmentIndex contains the index of the segment recorded accessible
 in the recordSegments array. If error is not null, if will be -1
 If you don't remove the SCRecordSession from the SCRecorder while calling this method,
 The SCRecorder might create a new recordSegment right after automatically if it is not paused.
 */
- (BOOL)endSegmentWithInfo:(NSDictionary *__nullable)info completionHandler:(void(^__nullable)(SCRecordSessionSegment *__nullable segment, NSError *__nullable error))completionHandler;

@end
