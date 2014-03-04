//
//  VRVideoRecorder.h
//  VideoRecorder
//
//  Created by Simon CORSIN on 8/3/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCVideoEncoder.h"
#import "SCAudioEncoder.h"

#if DEBUG
#define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#define DLog(...)
#endif


// photo dictionary keys

extern NSString * const SCAudioVideoRecorderPhotoMetadataKey;
extern NSString * const SCAudioVideoRecorderPhotoJPEGKey;
extern NSString * const SCAudioVideoRecorderPhotoImageKey;
extern NSString * const SCAudioVideoRecorderPhotoThumbnailKey; // 160x120

@class SCAudioVideoRecorder;

//
// VideoRecorderDelegate
//

@protocol SCAudioVideoRecorderDelegate <NSObject>

@optional

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didRecordVideoFrame:(CMTime)frameTime;
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didRecordAudioSample:(CMTime)sampleTime;
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder willFinishRecordingAtTime:(CMTime)frameTime;
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFinishRecordingAtUrl:(NSURL*)recordedFile
                      error:(NSError*)error;
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder willFinalizeAudioMixAtUrl:(NSURL*)recordedFile;
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeVideoEncoder:(NSError*)error;
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeAudioEncoder:(NSError*)error;

// Photo
- (void)audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error;

@end

//
// AudioVideo Recorder
//

@class SCVideoEncoder;
@class SCAudioEncoder;

@interface SCAudioVideoRecorder : NSObject<SCDataEncoderDelegate> {
    
}

// The Camera roll only exists on iOS
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
- (void) prepareRecordingAtCameraRoll:(NSError**)error;
// Photo
- (void) capturePhoto;
#endif

- (NSURL*) prepareRecordingOnTempDir:(NSError**)error;
- (void) prepareRecordingAtUrl:(NSURL*)url error:(NSError**)error;

- (void) record;
- (void) pause;
- (void) cancel;
- (void) stop;

- (BOOL) isPrepared;
- (BOOL) isRecording;

- (void) reset;

@property (weak, nonatomic) id<SCAudioVideoRecorderDelegate> delegate;

@property (strong, nonatomic, readonly) AVCaptureVideoDataOutput * videoOutput;
@property (strong, nonatomic, readonly) AVCaptureAudioDataOutput * audioOutput;
@property (strong, nonatomic, readonly) AVCaptureStillImageOutput *stillImageOutput;

@property (assign, nonatomic) BOOL enableSound;
@property (assign, nonatomic) BOOL enableVideo;

// The VideoEncoder. Accessing this allow the configuration of the video encoder
@property (strong, nonatomic, readonly) SCVideoEncoder * videoEncoder;

// The AudioEncoder. Accessing this allow the configuration of the audio encoder
@property (strong, nonatomic, readonly) SCAudioEncoder * audioEncoder;

// When the recording is prepared, this getter contains the output file
@property (strong, nonatomic, readonly) NSURL * outputFileUrl;

// If not null, the asset will be played when the record starts, and pause when it pauses.
// When the record ends, the audio mix will be mixed with the playback asset
@property (strong, nonatomic) AVAsset * playbackAsset;
@property (assign, nonatomic) BOOL playPlaybackAssetWhenRecording;

// When the playback asset should start
@property (assign, nonatomic) CMTime playbackStartTime;

// If true, every messages sent to the delegate will be dispatched through the main queue
@property (assign, nonatomic) BOOL dispatchDelegateMessagesOnMainQueue;

// Must be like AVFileType*
@property (copy, nonatomic) NSString * outputFileType;

@property (assign, readonly, nonatomic) CMTime currentRecordingTime;

// The recording will stop when the total recorded time reaches this value
// Default is kCMTimePositiveInfinity
@property (assign, nonatomic) CMTime recordingDurationLimit;

// The rate at which the record should be processed
// The recording will be slower if between 0 and 1 exclusive, faster in more than 1
@property (assign, nonatomic) float recordingRate;

@end
