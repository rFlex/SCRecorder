//
//  SCCamera.h
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/6/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCAudioVideoRecorder.h"

typedef NS_ENUM(NSInteger, SCCameraMode) {
    SCCameraModePhoto = UIImagePickerControllerCameraCaptureModePhoto,
    SCCameraModeVideo = UIImagePickerControllerCameraCaptureModeVideo
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


#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
@property (nonatomic, assign) SCCameraMode cameraMode;
// Switch between back and front camera
- (void) switchCamera;

@property (weak, nonatomic) UIView * previewView;
@property (assign, nonatomic) BOOL useFrontCamera;

#else

@property (weak, nonatomic) NSView * previewView;

#endif


@end
