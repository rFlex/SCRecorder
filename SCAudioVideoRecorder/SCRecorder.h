//
//  SCNewCamera.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 27/03/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SCRecordSession.h"

typedef NS_ENUM(NSInteger, SCFlashMode) {
    SCFlashModeOff  = AVCaptureFlashModeOff,
    SCFlashModeOn   = AVCaptureFlashModeOn,
    SCFlashModeAuto = AVCaptureFlashModeAuto,
    SCFlashModeLight
};

typedef NS_ENUM(NSInteger, SCCameraDevice) {
    SCCameraDeviceBack = AVCaptureDevicePositionBack,
    SCCameraDeviceFront = AVCaptureDevicePositionFront
};

typedef NS_ENUM(NSInteger, SCCameraFocusMode) {
    SCCameraFocusModeLocked = AVCaptureFocusModeLocked,
    SCCameraFocusModeAutoFocus = AVCaptureFocusModeAutoFocus,
    SCCameraFocusModeContinuousAutoFocus = AVCaptureFocusModeContinuousAutoFocus
};

@class SCRecorder;

@protocol SCRecorderDelegate <NSObject>

@optional

// Camera stuffs
- (void)recorder:(SCRecorder*)recorder didReconfigureInputs:(NSError*)videoInputError audioInputError:(NSError*)audioInputError;
- (void)recorder:(SCRecorder*)recorder didChangeFlashMode:(SCFlashMode)flashMode error:(NSError*)error;
- (void)recorder:(SCRecorder*)recorder didChangeSessionPreset:(NSString*)sessionPreset error:(NSError*)error;

// RecordSession stuffs
- (void)recorder:(SCRecorder*)recorder didInitializeAudioInRecordSession:(SCRecordSession*)recordSession error:(NSError *)error;
- (void)recorder:(SCRecorder*)recorder didInitializeVideoInRecordSession:(SCRecordSession*)recordSession error:(NSError *)error;
- (void)recorder:(SCRecorder*)recorder didBeginRecordSegment:(SCRecordSession*)recordSession error:(NSError*)error;
- (void)recorder:(SCRecorder*)recorder didEndRecordSegment:(SCRecordSession*)recordSession segmentIndex:(NSInteger)segmentIndex error:(NSError*)error;

@end


@interface SCRecorder : NSObject<AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

// Enable the audio, video, and photo
// Changing these parameters have no effect
// if the session has been already opened
@property (assign, nonatomic) BOOL audioEnabled;
@property (assign, nonatomic) BOOL videoEnabled;
@property (assign, nonatomic) BOOL photoEnabled;

// Will be YES if the SCRecorder is currently recording
@property (readonly, nonatomic) BOOL isRecording;

@property (assign, nonatomic) SCFlashMode flashMode;
@property (assign, nonatomic) SCCameraDevice device;
@property (assign, nonatomic) SCCameraFocusMode focusMode;

// The outputSettings used in the AVCaptureStillImageOutput
@property (copy, nonatomic) NSDictionary *photoOutputSettings;

// The sessionPreset used for the AVCaptureSession
@property (copy, nonatomic) NSString *sessionPreset;

// The capture session. This property will be null until
// openSession: has been called. Calling closeSession will set
// this property to null again.
@property (readonly, nonatomic) AVCaptureSession *captureSession;
@property (readonly, nonatomic) BOOL isCaptureSessionOpened;

// The previewLayer used for the video preview
@property (readonly, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

// Convenient way to set a view inside the previewLayer
@property (strong, nonatomic) UIView *previewView;

// Set the recordSession used while recording
// This can be removed and set at anytime
@property (strong, nonatomic) SCRecordSession *recordSession;

// Set the delegate used to receive information messages from the recorder
@property (weak, nonatomic) id<SCRecorderDelegate> delegate;


// Convenient way to create a recorder
+ (SCRecorder*)recorder;

// Start the camera session
// Calling this method will set the captureSession and configure it properly
- (void)openSession:(void(^)(NSError *sessionError, NSError * audioError, NSError * videoError, NSError *photoError))completionHandler;

// Close the session set in the captureSession
- (void)closeSession;

//- (void)addRecordSession:(SCRecordSession *)recordSession;
//- (BOOL)removeRecordSession:(SCRecordSession *)recordSession;

// Start the flow of inputs in the captureSession
// openSession must has been called before
// This will be done on a different thread to avoid GUI hiccup
- (void)startRunningSession:(void(^)())completionHandler;

// End the flows of inputs
// This wont close the session
- (void)endRunningSession;

// Calling this method will make the recorder to append sample buffers inside the current setted recordSession
- (void)record;

// Ask the recorder to stop appending sample buffers inside the recordSession
- (void)pause;

@end
