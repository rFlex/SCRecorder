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
#import "SCSampleBufferHolder.h"
#import "SCVideoPlayerView.h"
#import "SCPlayer.h"
#import "SCAssetExportSession.h"
#import "SCImageView.h"
#import "SCSwipeableFilterView.h"
#import "SCRecorderFocusView.h"

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

/**
 Enable the audio
 Changing this parameter has no effect is the session
 has been already opened
 */
@property (assign, nonatomic) BOOL audioEnabled;

/**
 Enable the video
 Changing this parameter has no effect is the session
 has been already opened
 */
@property (assign, nonatomic) BOOL videoEnabled;

/**
 Enable the photo
 Changing this parameter has no effect is the session
 has been already opened
 */
@property (assign, nonatomic) BOOL photoEnabled;

/**
 Will be true if the SCRecorder is currently recording
 */
@property (readonly, nonatomic) BOOL isRecording;

/**
 Change the flash mode on the camera
 */
@property (assign, nonatomic) SCFlashMode flashMode;


/**
 Determine whether the device has flash
 */
@property (assign, nonatomic, readonly) BOOL deviceHasFlash;

/**
 Change the current used device
 */
@property (assign, nonatomic) AVCaptureDevicePosition device;

/**
 Get the current focus mode used by the camera device
 */
@property (readonly, nonatomic) AVCaptureFocusMode focusMode;

/**
 The outputSettings used in the AVCaptureStillImageOutput
 */
@property (copy, nonatomic) NSDictionary *photoOutputSettings;

/**
 The session preset used for the AVCaptureSession
 */
@property (copy, nonatomic) NSString *sessionPreset;

/**
 The captureSession. This will be null until openSession: has
 been called. Calling closeSession will set this property to null again.
 */
@property (readonly, nonatomic) AVCaptureSession *captureSession;

/**
 Whether the captureSession has been opened.
 */
@property (readonly, nonatomic) BOOL isCaptureSessionOpened;

/**
 The preview layer used for the video preview
 */
@property (readonly, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

/**
 Convenient way to set a view inside the preview layer
 */
@property (strong, nonatomic) UIView *previewView;

/**
 If set, this render will receive every received frames as CIImage.
 Can be useful for displaying a real time filter for example.
 */
@property (strong, nonatomic) id<CIImageRenderer> CIImageRenderer;

/**
 Set the delegate used to receive messages for the SCRecorder
 */
@property (weak, nonatomic) id<SCRecorderDelegate> delegate;

/**
 The record session to which the recorder will flow the camera/microphone buffers
 */
@property (strong, nonatomic) SCRecordSession *recordSession;

/**
 The video orientation. This is automatically set if autoSetVideoOrientation is enabled
 */
@property (assign, nonatomic) AVCaptureVideoOrientation videoOrientation;

/**
 If true, the videoOrientation property will be set automatically
 depending on the current device orientation
 Default is NO
 */
@property (assign, nonatomic) BOOL autoSetVideoOrientation;

/**
 The frameRate for the video
 */
@property (assign, nonatomic) CMTimeScale frameRate;

/**
 If enabled, the recorder will initialize the recordSession and create the record segments
 when asking to record. Otherwise it will do it as soon as possible.
 Default is YES
 */
@property (assign, nonatomic) BOOL initializeRecordSessionLazily;

/**
 Whether the focus is supported on the current camera device
 */
@property (readonly, nonatomic) BOOL focusSupported;

/**
 The underlying AVCaptureVideoDataOutput
 */
@property (readonly, nonatomic) AVCaptureVideoDataOutput *videoOutput;

/**
 The underlying AVCaptureAudioDataOutput
 */
@property (readonly, nonatomic) AVCaptureAudioDataOutput *audioOutput;

/**
 The underlying AVCaptureStillImageOutput
 */
@property (readonly, nonatomic) AVCaptureStillImageOutput *photoOutput;

/**
 The dispatch queue that the SCRecorder uses for sending messages to the attached
 SCRecordSession.
 */
@property (readonly, nonatomic) dispatch_queue_t recordSessionQueue;

/**
 Create a recorder
 @return the newly created recorder
 */
+ (SCRecorder*)recorder;

/**
 Create the AVCaptureSession
 Calling this method will the captureSesion and configure it properly.
 This takes a completion block as a convenience for all the errors that can happen,
 but the method is actually called synchronously
 @param completionHandler Called when completed before this method returns
 */
- (void)openSession:(void(^)(NSError *sessionError, NSError * audioError, NSError * videoError, NSError *photoError))completionHandler;

/**
 Close and destroy the AVCaptureSession.
 */
- (void)closeSession;

/**
 Start the flow of inputs in the AVCaptureSession.
 openSession: must has been called before.
 Calling this method will block until it's done
 */
- (void)startRunningSession;

/**
 End the flow of inputs in the AVCaptureSession
 This wont destroy the AVCaptureSession.
 */
- (void)endRunningSession;

/**
 Offer a way to configure multiple things at once.
 You can call beginSessionConfiguration multiple times.
 Only the latest most outer commitSessionConfiguration will effectively commit
 the configuration
 */
- (void)beginSessionConfiguration;

/**
 Commit the session configuration after beginSessionConfiguration has been called
 */
- (void)commitSessionConfiguration;

/**
 Switch between the camera devices
 */
- (void)switchCaptureDevices;

/**
 Convert the view coordinates to a point usable by the focus methods
 @return a point of interest usable in the focus methods
 */
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates;

/**
 Focus automatically at the given point of interest.
 Once the focus is completed, the camera device will goes to locked mode
 and won't try to do any further focus
 @param point A point of interest between 0,0 and 1,1
 */
- (void)autoFocusAtPoint:(CGPoint)point;

/**
 Continously focus at a point. The camera device detects when it needs to focus
 and focus automatically when needed.
 @param point A point of interest between 0,0 and 1,1,
 */
- (void)continuousFocusAtPoint:(CGPoint)point;

/**
 Lock the current focus and prevent any new further focus
 */
- (void)lockFocus;

/**
 Set an active device format that supports the request framerate and size
 This does not change the frameRate.
 @return whether the method has succeeded or not
 */
- (BOOL)setActiveFormatThatSupportsFrameRate:(CMTimeScale)frameRate width:(int)width andHeight:(int)height error:(NSError**)error;

/**
 Allow the recorder to append the sample buffers inside the current setted recordSession
 */
- (void)record;

/**
 Disallow the recorder to append the sample buffers inside the current setted recordSession.
 If a record segment has started, this will be either canceled or completed depending on
 if it is empty or not.
 */
- (void)pause;

/**
 Disallow the recorder to append the sample buffers inside the current setted recordSession.
 If a record segment has started, this will be either canceled or completed depending on
 if it is empty or not.
 @param completionHandler called on the main queue when the recorder is ready to record again.
 */
- (void)pause:(void(^)())completionHandler;

/**
 Capture a photo from the camera
 @param completionHandler called on the main queue with the image taken or an error in case of a problem
 */
- (void)capturePhoto:(void(^)(NSError *error, UIImage *image))completionHandler;

/**
 Signal to the recorder that the previewView frame has changed.
 This will make the previewLayer to matches the size of the previewView.
 */
- (void)previewViewFrameChanged;

/**
 Get an image representing the last output video buffer.
 */
- (UIImage *)snapshotOfLastVideoBuffer;

/**
 Get an image representing the last appended video buffer
 */
- (UIImage *)snapshotOfLastAppendedVideoBuffer;

@end
