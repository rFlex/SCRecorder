//
//  VRViewController.h
//  VideoRecorder
//
//  Created by Simon CORSIN on 8/3/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCCamera.h"

@interface SCViewController : UIViewController<SCCameraDelegate>

// Video
@property (weak, nonatomic) IBOutlet UIView *recordView;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (weak, nonatomic) IBOutlet UIButton *retakeButton;
@property (weak, nonatomic) IBOutlet UIView *previewView;
@property (weak, nonatomic) IBOutlet UILabel *timeRecordedLabel;
@property (weak, nonatomic) IBOutlet UIView *downBar;

// Video record finish loading
@property (weak, nonatomic) IBOutlet UIView *loadingView;

@property (weak, nonatomic) IBOutlet UIButton *reverseCamera;

// CameraMode
@property (weak, nonatomic) IBOutlet UIButton *switchCameraModeButton;
- (IBAction)switchCameraMode:(id)sender;

// flash with take photo
@property (weak, nonatomic) IBOutlet UIButton *flashModeButton;
- (IBAction)switchFlash:(id)sender;

// Normal capture photo
@property (weak, nonatomic) IBOutlet UIButton *capturePhotoButton;
- (IBAction)capturePhoto:(id)sender;

// Take Photo with motion
@property (weak, nonatomic) IBOutlet UIProgressView *shakeproofProgressView;
- (IBAction)shakeproofCapturePhoto:(UIButton *)sender;

// Continuous take Photo
- (IBAction)continuousBegin:(id)sender;

// Camera Scale
@property (weak, nonatomic) IBOutlet UISlider *cameraEffectiveScaleSlider;
- (IBAction)cameraEffectiveScaleSliderValueChange:(UISlider *)sender;

@end
