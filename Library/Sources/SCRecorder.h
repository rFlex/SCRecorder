//
//  SCNewCamera.h
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 27/03/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SCRecordSession.h"

typedef NS_ENUM(NSInteger, SCFlashMode) {
    SCFlashModeOff  = AVCaptureFlashModeOff,
    SCFlashModeOn   = AVCaptureFlashModeOn,
    SCFlashModeAuto = AVCaptureFlashModeAuto,
    SCFlashModeLight
};

@class SCRecorder;

@protocol SCRecorderDelegate <NSObject>

@optional

// Camera stuffs
- (void)recorder:(SCRecorder *)recorder didReconfigureVideoInput:(NSError *)videoInputError;
- (void)recorder:(SCRecorder *)recorder didReconfigureAudioInput:(NSError *)audioInputError;
- (void)recorder:(SCRecorder *)recorder didChangeFlashMode:(SCFlashMode)flashMode error:(NSError *)error;
- (void)recorder:(SCRecorder *)recorder didChangeSessionPreset:(NSString *)sessionPreset error:(NSError *)error;
- (void)recorderWillStartFocus:(SCRecorder *)recorder;
- (void)recorderDidStartFocus:(SCRecorder *)recorder;
- (void)recorderDidEndFocus:(SCRecorder *)recorder;

// RecordSession stuffs
- (void)recorder:(SCRecorder *)recorder didInitializeAudioInRecordSession:(SCRecordSession *)recordSession error:(NSError *)error;
- (void)recorder:(SCRecorder *)recorder didInitializeVideoInRecordSession:(SCRecordSession *)recordSession error:(NSError *)error;
- (void)recorder:(SCRecorder *)recorder didBeginRecordSegment:(SCRecordSession *)recordSession error:(NSError *)error;
- (void)recorder:(SCRecorder *)recorder didEndRecordSegment:(SCRecordSession *)recordSession segmentIndex:(NSInteger)segmentIndex error:(NSError *)error;
- (void)recorder:(SCRecorder *)recorder didAppendVideoSampleBuffer:(SCRecordSession *)recordSession;
- (void)recorder:(SCRecorder *)recorder didAppendAudioSampleBuffer:(SCRecordSession *)recordSession;
- (void)recorder:(SCRecorder *)recorder didSkipAudioSampleBuffer:(SCRecordSession *)recordSession;
- (void)recorder:(SCRecorder *)recorder didSkipVideoSampleBuffer:(SCRecordSession *)recordSession;
- (void)recorder:(SCRecorder *)recorder didCompleteRecordSession:(SCRecordSession *)recordSession;

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

// Change the flash mode on the camera
@property (assign, nonatomic) SCFlashMode flashMode;

// Change the current used device
@property (assign, nonatomic) AVCaptureDevicePosition device;

// Get the mode used for the focus
@property (readonly, nonatomic) AVCaptureFocusMode focusMode;

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

// Set the delegate used to receive information messages from the recorder
@property (weak, nonatomic) id<SCRecorderDelegate> delegate;

@property (strong, nonatomic) SCRecordSession *recordSession;

// Change the video orientation for the video
@property (assign, nonatomic) AVCaptureVideoOrientation videoOrientation;

// Change the frame rate for the video
@property (assign, nonatomic) CMTimeScale frameRate;

// Focus
@property (readonly, nonatomic) BOOL focusSupported;

// If for whatever reasons you need to access the underlying AVCaptureOutputs
@property (readonly, nonatomic) AVCaptureVideoDataOutput *videoOutput;
@property (readonly, nonatomic) AVCaptureAudioDataOutput *audioOutput;
@property (readonly, nonatomic) AVCaptureStillImageOutput *photoOutput;

// Convenient way to create a recorder
+ (SCRecorder*)recorder;

// Start the camera session
// Calling this method will set the captureSession and configure it properly
- (void)openSession:(void(^)(NSError *sessionError, NSError * audioError, NSError * videoError, NSError *photoError))completionHandler;

// Close the session set in the captureSession
- (void)closeSession;

// Start the flow of inputs in the captureSession
// openSession must has been called before
// Calling this method will block the main thread until it's done
- (void)startRunningSession;

// Start the flow of inputs in the captureSession
// openSession must has been called before
// This will be done on a different thread to avoid GUI hiccup
- (void)startRunningSession:(void(^)())completionHandler;

// End the flows of inputs
// This wont close the session
- (void)endRunningSession;

// Offer a way to configure multiple things at once
// You can call multiple beginSessionConfiguration recursively
// Each call of beginSessionConfiguration must be followed by a commitSessionConfiguration at some point
// Only the latest commitSessionConfiguration will in fact actually commit the configuration
- (void)beginSessionConfiguration;
- (void)commitSessionConfiguration;

// Switch between back and front device
- (void)switchCaptureDevices;

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates;

- (void)autoFocusAtPoint:(CGPoint)point;

// Switch to continuous auto focus mode at the specified point
- (void)continuousFocusAtPoint:(CGPoint)point;

// Set an activeFormat that supports the requested framerate
// This does not change the framerate
- (BOOL)setActiveFormatThatSupportsFrameRate:(CMTimeScale)frameRate width:(int)width andHeight:(int)height error:(NSError**)error;

// Calling this method will make the recorder to append sample buffers inside the current setted recordSession
- (void)record;

// Ask the recorder to stop appending sample buffers inside the recordSession
- (void)pause;

// Ask the recorder to stop appending sample buffers inside the recordSession
// The completionHandler handler is called on the main queue when the recorder is ready to record again
- (void)pause:(void(^)())completionHandler;

// Capture a photo from the camera
- (void)capturePhoto:(void(^)(NSError *error, UIImage *image))completionHandler;

@end
