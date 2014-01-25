//
//  SCCamera.h
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/6/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCAudioVideoRecorder.h"

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

@class SCCamera;
@protocol SCCameraDelegate <SCAudioVideoRecorderDelegate>

@optional

// Photo
// These methods are commonly used to show a custom animation
- (void)cameraWillCapturePhoto:(SCCamera *)camera;
- (void)cameraDidCapturePhoto:(SCCamera *)camera;
- (void)camera:(SCCamera *)camera cleanApertureDidChange:(CGRect)cleanAperture;

// Focus
- (void)cameraWillStartFocus:(SCCamera *)camera;
- (void)cameraDidStartFocus:(SCCamera*)camera;
- (void)cameraDidStopFocus:(SCCamera *)camera;
- (void)camera:(SCCamera *)camera didFailFocus:(NSError *)error;

// FocusMode
- (void)cameraUpdateFocusMode:(NSString *)focusModeString;

// Session
// These methods are commonly used to show an open/close session animation
- (void)cameraSessionWillStart:(SCCamera *)camera;
- (void)cameraSessionDidStart:(SCCamera *)camera;
- (void)cameraSessionWillStop:(SCCamera *)camera;
- (void)cameraSessionDidStop:(SCCamera *)camera;

@end

typedef enum {
    SCVideoGravityResize,
    SCVideoGravityResizeAspectFill,
    SCVideoGravityResizeAspect
} SCCameraPreviewVideoGravity;

@interface SCCamera : SCAudioVideoRecorder {
    
}

+ (SCCamera*) camera;

- (id) initWithSessionPreset:(NSString*)sessionPreset;

- (void) initialize:(void(^)(NSError * audioError, NSError * videoError))completionHandler;

- (BOOL) isReady;

@property (strong, nonatomic, readonly) AVCaptureSession * session;
@property (weak, nonatomic) id<SCCameraDelegate> delegate;
@property (copy, nonatomic) NSString * sessionPreset;
@property (assign, nonatomic) SCCameraPreviewVideoGravity previewVideoGravity;
@property (assign, nonatomic) AVCaptureVideoOrientation videoOrientation;
@property (strong, nonatomic, readonly) AVCaptureVideoPreviewLayer * previewLayer;
@property (readonly) AVCaptureDevice * currentDevice;


@property (nonatomic) SCFlashMode flashMode;
@property (nonatomic) SCCameraDevice cameraDevice;

// Focus
@property (nonatomic, readonly, getter = focusSupported) BOOL isFocusSupported;
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates;
- (void)autoFocusAtPoint:(CGPoint)point;
// Switch to continuous auto focus mode at the specified point
- (void)continuousFocusAtPoint:(CGPoint)point;

// Session
- (void)startRunningSession;
- (void)stopRunningSession;

// Set an activeFormat that supports the requested framerate
// This does not change the framerate
- (BOOL)setActiveFormatThatSupportsFrameRate:(NSInteger)frameRate width:(NSInteger)width andHeight:(NSInteger)height error:(NSError**)error;

// Switch between back and front camera
- (void) switchCamera;

- (BOOL)isFrameRateSupported:(NSInteger)frameRate;

// Offer a way to configure multiple things at once
// You can call multiple beginSessionConfiguration recursively
// Each call of beginSessionConfiguration must be followed by a commitSessionConfiguration at some point
// Only the latest commitSessionConfiguration will in fact actually commit the configuration
- (void)beginSessionConfiguration;
- (void)commitSessionConfiguration;

@property (assign, nonatomic) NSInteger frameRate;

// preview
@property (weak, nonatomic) UIView * previewView;

@property (nonatomic, readonly) CGRect cleanAperture;
@property (readonly, nonatomic) SCCameraFocusMode focusMode;

@end
