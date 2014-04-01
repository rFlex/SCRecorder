//
//  VRViewController.m
//  VideoRecorder
//
//  Created by Simon CORSIN on 8/3/13.
//  Copyright (c) 2013 SCorsin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "SCTouchDetector.h"
#import "SCViewController.h"
#import "SCAudioTools.h"
#import "SCVideoPlayerViewController.h"
#import "SCCameraFocusView.h"
#import "SCImageViewDisPlayViewController.h"
#import "SCRecorder.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "SCCamera.h"

#import "SCCameraFocusTargetView.h"

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface SCViewController () {
    SCRecorder *_recorder;
}

@property (strong, nonatomic) SCCameraFocusView *focusView;
@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCViewController

#pragma mark - UIViewController 

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0

- (UIStatusBarStyle) preferredStatusBarStyle {
	return UIStatusBarStyleLightContent;
}

#endif

#pragma mark - Left cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
//	self.view.backgroundColor = [UIColor grayColor];
    self.capturePhotoButton.alpha = 0.0;
    
    _recorder = [SCRecorder recorder];
    _recorder.sessionPreset = AVCaptureSessionPresetHigh;
    _recorder.delegate = self;
    
    UIView *previewView = self.previewView;
    _recorder.previewView = previewView;
    
    [self.retakeButton addTarget:self action:@selector(handleRetakeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.stopButton addTarget:self action:@selector(handleStopButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	[self.reverseCamera addTarget:self action:@selector(handleReverseCameraTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.recordView addGestureRecognizer:[[SCTouchDetector alloc] initWithTarget:self action:@selector(handleTouchDetected:)]];
    self.loadingView.hidden = YES;
    
    self.focusView = [[SCCameraFocusView alloc] initWithFrame:previewView.bounds];
    self.focusView.recorder = _recorder;
    [previewView addSubview:self.focusView];
    self.focusView.outsideFocusTargetImage = [UIImage imageNamed:@"capture_flip"];
    self.focusView.insideFocusTargetImage = [UIImage imageNamed:@"capture_flip"];
    
    [_recorder openSession:^(NSError *sessionError, NSError *audioError, NSError *videoError, NSError *photoError) {
        NSLog(@"==== Opened session ====");
        NSLog(@"Session error: %@", sessionError.description);
        NSLog(@"Audio error : %@", audioError.description);
        NSLog(@"Video error: %@", videoError.description);
        NSLog(@"Photo error: %@", photoError.description);
        NSLog(@"=======================");
        [self prepareCamera];
    }];
    
}

- (void)recorder:(SCRecorder *)recorder didReconfigureInputs:(NSError *)videoInputError audioInputError:(NSError *)audioInputError {
    NSLog(@"Reconfigured inputs, videoError: %@, audioError: %@", videoInputError, audioInputError);
}

- (void) viewWillAppear:(BOOL)animated {
	self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (_recorder.isCaptureSessionOpened) {
        [_recorder startRunningSession:nil];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
    
    [_recorder endRunningSession];
}

- (void)updateLabelForSecond:(Float64)totalRecorded {
    self.timeRecordedLabel.text = [NSString stringWithFormat:@"Recorded - %.2f sec", totalRecorded];
}

#pragma mark - SCAudioVideoRecorder delegate

// Video

#pragma mark - Camera Delegate

// Photo
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error {
    if (!error) {
        [self showPhoto:[photoDict valueForKey:SCAudioVideoRecorderPhotoImageKey]];
        ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
        [assetLibrary writeImageDataToSavedPhotosAlbum:[photoDict objectForKey:SCAudioVideoRecorderPhotoJPEGKey] metadata:[photoDict objectForKey:SCAudioVideoRecorderPhotoMetadataKey] completionBlock:^(NSURL *assetURL, NSError *blockError) {
            DLog(@"Saved to the camera roll.");
        }];
    }
}

// Camera

- (void)camera:(SCCamera *)camera didFailWithError:(NSError *)error {
    DLog(@"error : %@", error.description);
}

// Photo
- (void)cameraWillCapturePhoto:(SCCamera *)camera {
}

- (void)cameraDidCapturePhoto:(SCCamera *)camera {

}

// Focus
- (void)recorderDidStartFocus:(SCRecorder *)recorder {
    [self.focusView showFocusAnimation];
}

- (void)recorderDidEndFocus:(SCRecorder *)recorder {
    [self.focusView hideFocusAnimation];
}

#pragma mark - Handle

- (void)showAlertViewWithTitle:(NSString*)title message:(NSString*) message {
    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alertView show];
}

- (void)showVideo:(AVAsset*)asset {
	SCVideoPlayerViewController * videoPlayerViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"SCVideoPlayerViewController"];
	videoPlayerViewController.asset = asset;
    
	[self.navigationController pushViewController:videoPlayerViewController animated:YES];
}

- (void)showPhoto:(UIImage *)photo {
    SCImageViewDisPlayViewController *sc_imageViewDisPlayViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"SCImageViewDisPlayViewController"];
    sc_imageViewDisPlayViewController.photo = photo;
    [self.navigationController pushViewController:sc_imageViewDisPlayViewController animated:YES];
    sc_imageViewDisPlayViewController = nil;
}

- (void) handleReverseCameraTapped:(id)sender {
	[_recorder switchCaptureDevices];
}

- (void) handleStopButtonTapped:(id)sender {
    SCRecordSession *recordSession = _recorder.recordSession;
    
    if (recordSession != nil) {
        _recorder.recordSession = nil;
        
        [self finishSession:recordSession];
    }
}

- (void)finishSession:(SCRecordSession *)recordSession {
    [recordSession endSession:^(NSError *error) {
        if (error == nil) {
            [self showVideo:[AVURLAsset URLAssetWithURL:recordSession.outputUrl options:nil]];
        } else {
            NSLog(@"Failed to end session: %@", error);
        }
        [self prepareCamera];
    }];
}

- (void) handleRetakeButtonTapped:(id)sender {
	[self prepareCamera];
    [self updateLabelForSecond:0];
}

- (IBAction)switchCameraMode:(id)sender {
//    if (self.camera.sessionPreset == AVCaptureSessionPresetPhoto) {
//        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//            self.capturePhotoButton.alpha = 0.0;
//            self.recordView.alpha = 1.0;
//            self.retakeButton.alpha = 1.0;
//            self.stopButton.alpha = 1.0;
//        } completion:^(BOOL finished) {
//			self.camera.sessionPreset = AVCaptureSessionPresetHigh;
//            [self.switchCameraModeButton setTitle:@"Switch Photo" forState:UIControlStateNormal];
//            [self.flashModeButton setTitle:@"Flash : Off" forState:UIControlStateNormal];
//            self.camera.flashMode = SCFlashModeOff;
//        }];
//    } else if (self.camera.sessionPreset == AVCaptureSessionPresetHigh) {
//        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
//            self.recordView.alpha = 0.0;
//            self.retakeButton.alpha = 0.0;
//            self.stopButton.alpha = 0.0;
//            self.capturePhotoButton.alpha = 1.0;
//        } completion:^(BOOL finished) {
//			self.camera.sessionPreset = AVCaptureSessionPresetPhoto;
//            [self.switchCameraModeButton setTitle:@"Switch Video" forState:UIControlStateNormal];
//            [self.flashModeButton setTitle:@"Flash : Auto" forState:UIControlStateNormal];
//            self.camera.flashMode = SCFlashModeAuto;
//        }];
//    }
}

- (IBAction)switchFlash:(id)sender {
//    NSString *flashModeString = nil;
//    if (self.camera.sessionPreset == AVCaptureSessionPresetPhoto) {
//        switch (self.camera.flashMode) {
//            case SCFlashModeAuto:
//                flashModeString = @"Flash : Off";
//                self.camera.flashMode = SCFlashModeOff;
//                break;
//            case SCFlashModeOff:
//                flashModeString = @"Flash : On";
//                self.camera.flashMode = SCFlashModeOn;
//                break;
//            case SCFlashModeOn:
//                flashModeString = @"Flash : Light";
//                self.camera.flashMode = SCFlashModeLight;
//                break;
//            case SCFlashModeLight:
//                flashModeString = @"Flash : Auto";
//                self.camera.flashMode = SCFlashModeAuto;
//                break;
//            default:
//                break;
//        }
//    } else {
//        switch (self.camera.flashMode) {
//            case SCFlashModeOff:
//                flashModeString = @"Flash : On";
//                self.camera.flashMode = SCFlashModeLight;
//                break;
//            case SCFlashModeLight:
//                flashModeString = @"Flash : Off";
//                self.camera.flashMode = SCFlashModeOff;
//                break;
//            default:
//                break;
//        }
//    }
//    
//    [self.flashModeButton setTitle:flashModeString forState:UIControlStateNormal];
}

- (void) prepareCamera {
    if (_recorder.recordSession == nil) {
        
        SCRecordSession *session = [SCRecordSession recordSession];
        session.suggestedMaxRecordDuration = CMTimeMakeWithSeconds(5, 10000);
        session.shouldTrackRecordSegments = YES;
//        session.shouldIgnoreAudio = YES;
        
        _recorder.recordSession = session;
    }
}

- (void)recorder:(SCRecorder *)recorder didCompleteRecordSession:(SCRecordSession *)recordSession {
    [self finishSession:recordSession];
}

- (void)recorder:(SCRecorder *)recorder didInitializeAudioInRecordSession:(SCRecordSession *)recordSession error:(NSError *)error {
    if (error == nil) {
        NSLog(@"Initialized audio in record session");
    } else {
        NSLog(@"Failed to initialize audio in record session: %@", error.localizedDescription);
    }
}

- (void)recorder:(SCRecorder *)recorder didInitializeVideoInRecordSession:(SCRecordSession *)recordSession error:(NSError *)error {
    if (error == nil) {
        NSLog(@"Initialized video in record session");
    } else {
        NSLog(@"Failed to initialize video in record session: %@", error.localizedDescription);
    }
}

- (void)recorder:(SCRecorder *)recorder didBeginRecordSegment:(SCRecordSession *)recordSession error:(NSError *)error {
    NSLog(@"Began record segment: %@", error);
}

- (void)recorder:(SCRecorder *)recorder didEndRecordSegment:(SCRecordSession *)recordSession segmentIndex:(NSInteger)segmentIndex error:(NSError *)error {
    NSLog(@"End record segment %d", (int)segmentIndex);
}

- (void)recorder:(SCRecorder *)recorder didAppendVideoSampleBuffer:(SCRecordSession *)recordSession {
    self.timeRecordedLabel.text = [NSString stringWithFormat:@"Recorded - %.2f sec", CMTimeGetSeconds(recordSession.currentRecordDuration)];
}

- (void)handleTouchDetected:(SCTouchDetector*)touchDetector {
    if (touchDetector.state == UIGestureRecognizerStateBegan) {
//        NSLog(@"==== STARTING RECORDING ====");
        [_recorder record];
    } else if (touchDetector.state == UIGestureRecognizerStateEnded) {
//        NSLog(@"==== PAUSING RECORDING ====");
        [_recorder pause];
    }
}

- (IBAction)capturePhoto:(id)sender {
//    [self.camera capturePhoto];
}

@end
