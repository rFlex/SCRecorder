//
//  SCCamera.h
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/6/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCAudioVideoRecorder.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE

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

#endif

@class SCCamera;
@protocol SCCameraDelegate <SCAudioVideoRecorderDelegate>

@optional

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE

// Photo
// These methods are commonly used to show a custom animation
- (void)cameraWillCapturePhoto:(SCCamera *)camera;
- (void)cameraDidCapturePhoto:(SCCamera *)camera;
- (void)camera:(SCCamera *)camera cleanApertureDidChange:(CGRect)cleanAperture;

// Focus
- (void)cameraWillStartFocus:(SCCamera *)camera;
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

#endif
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


#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE

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

// Switch between back and front camera
- (void) switchCamera;

- (BOOL)isFrameRateSupported:(NSInteger)frameRate;
@property (assign, nonatomic) NSInteger frameRate;

// preview
@property (weak, nonatomic) UIView * previewView;
@property (nonatomic, readonly) CGRect cleanAperture;

#else

@property (weak, nonatomic) NSView * previewView;

#endif


@end
