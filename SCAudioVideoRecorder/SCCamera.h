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
    SCFlashModeLigth
};

typedef NS_ENUM(NSInteger, SCCameraDevice) {
    SCCameraDeviceBack = AVCaptureDevicePositionBack,
    SCCameraDeviceFront = AVCaptureDevicePositionFront
};

#endif

@class SCCamera;
@protocol SCCameraDelegate <SCAudioVideoRecorderDelegate>

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
// These methods are prepared to take pictures animation
- (void)cameraWillCapturePhoto:(SCCamera *)camera;
- (void)cameraDidCapturePhoto:(SCCamera *)camera;

// Focus
- (void)cameraWillStartFocus:(SCCamera *)camera;
- (void)cameraDidStopFocus:(SCCamera *)camera;

// FocusMode
- (void)cameraUpdateFocusMode:(NSString *)focusModeString;

// Error
- (void)camera:(SCCamera *)camera didFailWithError:(NSError *)error;

// session，Because these methods are in order to open the animation of the session and the closing session
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

@property (weak, nonatomic) UIView * previewView;

#else

@property (weak, nonatomic) NSView * previewView;

#endif


@end
