//
//  VRVideoRecorder.h
//  VideoRecorder
//
//  Created by Simon CORSIN on 8/3/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SCVideoEncoder.h"
#import "SCAudioEncoder.h"

@class SCAudioVideoRecorder;

//
// VideoRecorderDelegate
//

@protocol SCAudioVideoRecorderDelegate <NSObject>

@optional

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didRecordVideoFrame:(Float64)frameSecond;
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didRecordAudioSample:(Float64)sampleSecond;
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFinishRecordingAtUrl:(NSURL*)recordedFile error:(NSError*)error;
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeVideoEncoder:(NSError*)error;
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeAudioEncoder:(NSError*)error;

@end

//
// AudioVideo Recorder
//

@class SCVideoEncoder;
@class SCAudioEncoder;

@interface SCAudioVideoRecorder : NSObject<SCDataEncoderDelegate> {
    
}

- (void) startRecordingAtCameraRoll:(NSError**)error;
- (NSURL*) startRecordingOnTempDir:(NSError**)error;
- (void) startRecordingAtUrl:(NSURL*)url error:(NSError**)error;

- (void) prepareRecordingAtCameraRoll:(NSError**)error shouldStartRecording:(BOOL)shouldRecord;
- (NSURL*) prepareRecordingOnTempDir:(NSError**)error shouldStartRecording:(BOOL)shouldRecord;
- (void) prepareRecordingAtUrl:(NSURL*)url error:(NSError**)error shouldStartRecording:(BOOL)shouldRecord;

- (void) resumeRecording;
- (void) pauseRecording;
- (void) cancelRecording;
- (void) stopRecording;

- (BOOL) isRecordingStarted;
- (BOOL) isRecording;

@property (weak, nonatomic) id<SCAudioVideoRecorderDelegate> delegate;
@property (strong, nonatomic, readonly) AVCaptureVideoDataOutput * videoOutput;
@property (strong, nonatomic, readonly) AVCaptureAudioDataOutput * audioOutput;
@property (strong, nonatomic, readonly) SCVideoEncoder * videoEncoder;
@property (strong, nonatomic, readonly) SCAudioEncoder * audioEncoder;
@property (strong, nonatomic, readonly) NSURL * outputFileUrl;
@property (strong, nonatomic, readonly) AVAssetWriter * assetWriter;
@property (assign, nonatomic) BOOL dispatchDelegateMessagesOnMainQueue;

@end
