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

@class SCRecordSession;
@protocol SCRecordSessionDelegate <NSObject>

@optional

@end

@interface SCRecordSession : NSObject

//////////////////
// GENERAL SETTINGS
////

// The outputUrl which will be the output file
// when endSession has been called
@property (strong, nonatomic) NSURL *outputUrl;

// The output file type used for the AVAssetWriter
// If null, AVFileTypeMPEG4 will be used for a video file, AVFileTypeAppleM4A for an audio file
@property (copy, nonatomic) NSString *fileType;

// If true, every record segments will be tracked an added into a separate
// NSURL inside the recordSegments
// You can easily remove each segment in the recordSegments property
// Default is NO
@property (assign, nonatomic) BOOL shouldTrackRecordSegments;

// Contains every recordSegments as NSURL
// If trackRecordSegments is true, every pause/record actions
// will result in a new entry in this array
// If trackRecordSegments is false, it will contains only one segment
@property (readonly, nonatomic) NSArray* recordSegments;

// Set the dictionaries used for configuring the AVAssetWriter
// If you set a non-null value here, the other settings will be ignored
@property (strong, nonatomic) NSDictionary *videoOutputSettings;
@property (strong, nonatomic) NSDictionary *audioOutputSettings;


//////////////////
// VIDEO SETTINGS
////

// Change the size of the video
// If videoOutputSettings has been changed, this property will be ignored
// If this value is CGSizeZero, the input video size received
// from the camera will be used
// Default is CGSizeZero
@property (assign, nonatomic) CGSize videoSize;

// Change the affine transform for the video
// If videoOutputSettings has been changed, this property will be ignored
@property (assign, nonatomic) CGAffineTransform videoAffineTransform;

// Changing the bits per pixel for the compression
// If videoOutputSettings has been changed, this property will be ignored
@property (assign, nonatomic) Float32 videoBitsPerPixel;

// Set the codec used for the video
// Default is AVVideoCodecH264
@property (copy, nonatomic) NSString *videoCodec;

// Set the video scaling mode
@property (copy, nonatomic) NSString *videoScalingMode;


//////////////////
// AUDIO SETTINGS
////

// Set the sample rate of the audio
// If audioOutputSettings has been changed, this property will be ignored
@property (assign, nonatomic) Float64 audioSampleRate;

// Set the number of channels
// If audioOutputSettings is not nil,, this property will be ignored
@property (assign, nonatomic) int audioChannels;

// Set the bitrate of the audio
// If audioOutputSettings is not nil,, this property will be ignored
@property (assign, nonatomic) int audioBitRate;

// Must be like kAudioFormat* (example kAudioFormatMPEGLayer3)
// If audioOutputSettings is not nil, this property will be ignored
@property (assign, nonatomic) int audioEncodeType;


//////////////////
// PUBLIC METHODS
////

// Create a SCRecordSession
+ (id)recordSession;

// Clear the record session, making it reusable
// If the recordSession is recording, the file will be deleted
- (void)clear;

// Set the outputUrl property by a generated url in the temp directory
- (void)setOutputUrlWithTempUrl;

- (void)saveToCameraRoll;

// Start a new record segment
// This method is automatically called when the record resumes
- (void)beginRecordSegment:(NSError**)error;

// End the current record segment
// This method is automatically called by the SCRecorder
// when calling [SCRecorder pause] if necessary
// segmentIndex contains the index of the segment recorded accessible
// in the recordSegments array. If error is not null, if will be -1
- (void)endRecordSegment:(void(^)(NSInteger segmentIndex, NSError* error))completionHandler;

// Remove the record segment at the given index and delete the associated file
- (void)removeSegmentAtIndex:(NSInteger)segmentIndex;

// Remove all the record segments and their associated files
- (void)removeAllSegments;

// End the session
// No record segments can be added after calling this method,
// unless "clear" is called
- (void)endSession:(void(^)(NSError*error))completionHandler;

// Returns an asset representing all the record segments
// from this record session. This can be called anytime.
- (AVAsset*)assetRepresentingRecordSegments;

@property (readonly, nonatomic) BOOL recordSegmentBegan;

//////////////////
// PRIVATE API
////

@property (readonly, nonatomic) BOOL videoInitialized;
@property (readonly, nonatomic) BOOL audioInitialized;
@property (readonly, nonatomic) BOOL videoInitializationFailed;
@property (readonly, nonatomic) BOOL audioInitializationFailed;

- (void)initializeVideoUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer suggestedFileType:(NSString*)fileType error:(NSError**)error;
- (void)initializeAudioUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer suggestedFileType:(NSString *)fileType error:(NSError **)error;

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)videoSampleBuffer;
- (void)appendAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer;
- (void)makeTimeOffsetDirty;

@end
