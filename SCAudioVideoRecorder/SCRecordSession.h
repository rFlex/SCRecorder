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
- (void)recordSession:(SCRecordSession*)recordSession;

@end

@interface SCRecordSession : NSObject

//////////////////
// GENERAL SETTINGS
////

// The outputUrl which will be the file
@property (strong, nonatomic) NSURL *outputUrl;

// The output file type used for the AVAssetWriter
// If null, AVFileTypeMPEG4 will be used for a video file, AVFileTypeAppleM4A for an audio file
@property (copy, nonatomic) NSString *fileType;

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
// PRIVATE PROPERTIES
////

@property (readonly, nonatomic) BOOL videoInitialized;
@property (readonly, nonatomic) BOOL audioInitialized;
@property (readonly, nonatomic) BOOL videoInitializationFailed;
@property (readonly, nonatomic) BOOL audioInitializationFailed;


//////////////////
// METHODS
////

+ (id)recordSession;

- (void)clear;
- (void)setOutputUrlWithTempUrl;
- (void)saveToCameraRoll;

- (void)initializeVideoUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer suggestedFileType:(NSString*)fileType error:(NSError**)error;
- (void)initializeAudioUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer suggestedFileType:(NSString *)fileType error:(NSError **)error;

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)videoSampleBuffer;
- (void)appendAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer;

@end
