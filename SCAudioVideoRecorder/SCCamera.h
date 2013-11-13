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
    SCFlashModeLigth
};

typedef NS_ENUM(NSInteger, SCCameraDevice) {
    SCCameraDeviceBack = AVCaptureDevicePositionBack,
    SCCameraDeviceFront = AVCaptureDevicePositionFront
};

@class SCCamera;
@protocol SCCameraDelegate <SCAudioVideoRecorderDelegate>

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

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE

// Switch between back and front camera
- (void) switchCamera;

@property (weak, nonatomic) UIView * previewView;

#else

@property (weak, nonatomic) NSView * previewView;

#endif


@end
