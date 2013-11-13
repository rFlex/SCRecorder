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

#import "SCImageViewDisPlayViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>

#import "SCCameraTagetView.h"

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface SCViewController () {

}

@property (strong, nonatomic) SCCamera * camera;
@property (strong, nonatomic) SCCameraTagetView *cameraTagetView;
@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCViewController

@synthesize camera;

#pragma mark - setter / getter

- (SCCameraTagetView *)cameraTagetView {
    if (!_cameraTagetView) {
        _cameraTagetView = [[SCCameraTagetView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
        _cameraTagetView.center = self.previewView.center;
        [self.previewView addSubview:_cameraTagetView];
    }
    return _cameraTagetView;
}

#pragma mark - UIViewController 

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0

- (UIStatusBarStyle) preferredStatusBarStyle {
	return UIStatusBarStyleLightContent;
}

#endif

#pragma mark - Left cycle

- (void) addMusic {
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
	[SCAudioTools overrideCategoryMixWithOthers];
	
	NSURL * fileUrl = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@blabla2.mp3", NSTemporaryDirectory()]];
	
	if (![[NSFileManager defaultManager] fileExistsAtPath:fileUrl.path]) {
		NSLog(@"Downloading...");
		NSURL * url = [NSURL URLWithString:@"http://a420.phobos.apple.com/us/r1000/041/Music/v4/28/01/5a/28015aa7-72b0-d0b8-9da1-ce414cd6e61b/mzaf_4547488074890633094.plus.aac.p.m4a"];
		NSData * data = [NSData dataWithContentsOfURL:url];
		NSLog(@"Saving at %@", fileUrl.absoluteString);
		[data writeToURL:fileUrl atomically:YES];
		NSLog(@"OK!");
	}
	
	AVAsset * asset = [AVAsset assetWithURL:fileUrl];
	
	self.camera.playbackAsset = asset;
//	self.camera.enableSound = NO;
}

- (void)_stupGesture {
    // Add a single tap gesture to focus on the point tapped, then lock focus
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToAutoFocus:)];
    [singleTap setNumberOfTapsRequired:1];
    [self.previewView addGestureRecognizer:singleTap];
    
    // Add a double tap gesture to reset the focus mode to continuous auto focus
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToContinouslyAutoFocus:)];
    [doubleTap setNumberOfTapsRequired:2];
    [singleTap requireGestureRecognizerToFail:doubleTap];
    [self.previewView addGestureRecognizer:doubleTap];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	self.view.backgroundColor = [UIColor grayColor];
    self.capturePhotoButton.alpha = 0.0;
    
    [self _stupGesture];
    
    self.camera = [[SCCamera alloc] initWithSessionPreset:AVCaptureSessionPresetHigh];
    self.camera.delegate = self;
    self.camera.enableSound = YES;
    self.camera.previewVideoGravity = SCVideoGravityResizeAspectFill;
    self.camera.previewView = self.previewView;
	self.camera.videoOrientation = AVCaptureVideoOrientationPortrait;
	self.camera.recordingDurationLimit = CMTimeMakeWithSeconds(10, 1);
	
//	[self addMusic];
	
    [self.camera initialize:^(NSError * audioError, NSError * videoError) {
		[self prepareCamera];
    }];
    
    [self.retakeButton addTarget:self action:@selector(handleRetakeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.stopButton addTarget:self action:@selector(handleStopButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	[self.reverseCamera addTarget:self action:@selector(handleReverseCameraTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.recordView addGestureRecognizer:[[SCTouchDetector alloc] initWithTarget:self action:@selector(handleTouchDetected:)]];
    self.loadingView.hidden = YES;
}

- (void) viewWillAppear:(BOOL)animated {
	self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
	if (self.camera.isReady) {
		NSLog(@"Starting to run again");
		[self.camera.session startRunning];
	} else {
		NSLog(@"Not prepared yet");
	}
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	
	[self.camera cancel];
}

- (void) updateLabelForSecond:(Float64)totalRecorded {
    self.timeRecordedLabel.text = [NSString stringWithFormat:@"Recorded - %.2f sec", totalRecorded];
}

#pragma mark - SCAudioVideoRecorder delegate

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didRecordVideoFrame:(CMTime)frameTime {
    [self updateLabelForSecond:CMTimeGetSeconds(frameTime)];
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFinishRecordingAtUrl:(NSURL *)recordedFile error:(NSError *)error {
	[self prepareCamera];
	
    self.loadingView.hidden = YES;
    self.downBar.userInteractionEnabled = YES;
    if (error != nil) {
        [self showAlertViewWithTitle:@"Failed to save video" message:[error localizedDescription]];
    } else {
		[self showVideo:recordedFile];
    }
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder willFinishRecordingAtTime:(CMTime)frameTime {
	self.loadingView.hidden = NO;
    self.downBar.userInteractionEnabled = NO;
}

// error
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeVideoEncoder:(NSError *)error {
    NSLog(@"Failed to initialize VideoEncoder");
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeAudioEncoder:(NSError *)error {
    NSLog(@"Failed to initialize AudioEncoder");
}

- (void)audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailWithError:(NSError *)error {
    DLog(@"error : %@", error.description);
}

// Photo
- (void)audioVideoRecorderWillCapturePhoto:(SCAudioVideoRecorder *)audioVideoRecorder {
    DLog(@"Will capture photo");
}

- (void)audioVideoRecorderDidCapturePhoto:(SCAudioVideoRecorder *)audioVideoRecorder {
    DLog(@"Did capture photo");
}

// Video
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error {
    if (!error) {
        [self showPhoto:[photoDict valueForKey:SCAudioVideoRecorderPhotoImageKey]];
        ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
        [assetLibrary writeImageDataToSavedPhotosAlbum:[photoDict objectForKey:SCAudioVideoRecorderPhotoJPEGKey] metadata:[photoDict objectForKey:SCAudioVideoRecorderPhotoMetadataKey] completionBlock:^(NSURL *assetURL, NSError *blockError) {
            DLog(@"Saved to the camera roll.");
        }];
    }
}

// Focus
- (void)audioVideoRecorderWillStartFocus:(SCAudioVideoRecorder *)audioVideoRecorder {
    DLog(@"WillStartFocus");
    [self.cameraTagetView startTageting];
}

- (void)audioVideoRecorderDidStopFocus:(SCAudioVideoRecorder *)audioVideoRecorder {
    DLog(@"DidStopFocus");
    [self.cameraTagetView stopTageting];
}

// Session
- (void)cameraSessionWillStart:(SCAudioVideoRecorder *)audioVideoRecorder {
    DLog(@"SessionWillStart");
}

- (void)cameraSessionDidStart:(SCAudioVideoRecorder *)audioVideoRecorder {
    DLog(@"SessionDidStart");
}

- (void)cameraSessionWillStop:(SCAudioVideoRecorder *)audioVideoRecorder {
    DLog(@"SessionWillStop");
}

- (void)cameraSessionDidStop:(SCAudioVideoRecorder *)audioVideoRecorder {
    DLog(@"SessionDidStop");
}

#pragma mark - Handle

- (void) showAlertViewWithTitle:(NSString*)title message:(NSString*) message {
    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alertView show];
}

- (void) showVideo:(NSURL*)videoUrl {
	SCVideoPlayerViewController * videoPlayerViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"SCVideoPlayerViewController"];
	videoPlayerViewController.videoUrl = videoUrl;
	
	[self.navigationController pushViewController:videoPlayerViewController animated:YES];
}

- (void)showPhoto:(UIImage *)photo {
    SCImageViewDisPlayViewController *sc_imageViewDisPlayViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"SCImageViewDisPlayViewController"];
    sc_imageViewDisPlayViewController.photo = photo;
    [self.navigationController pushViewController:sc_imageViewDisPlayViewController animated:YES];
    sc_imageViewDisPlayViewController = nil;
}

- (void) handleReverseCameraTapped:(id)sender {
	[self.camera switchCamera];
}

- (void) handleStopButtonTapped:(id)sender {
    [self.camera stop];
}

- (void) handleRetakeButtonTapped:(id)sender {
    [self.camera cancel];
	[self prepareCamera];
    [self updateLabelForSecond:0];
}

- (IBAction)switchCameraMode:(id)sender {
    if (self.camera.sessionPreset == AVCaptureSessionPresetPhoto) {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.capturePhotoButton.alpha = 0.0;
            self.recordView.alpha = 1.0;
            self.retakeButton.alpha = 1.0;
            self.stopButton.alpha = 1.0;
        } completion:^(BOOL finished) {
			self.camera.sessionPreset = AVCaptureSessionPresetHigh;
            [self.switchCameraModeButton setTitle:@"Switch Photo" forState:UIControlStateNormal];
            [self.flashModeButton setTitle:@"Flash : Off" forState:UIControlStateNormal];
            self.camera.flashMode = SCFlashModeOff;
        }];
    } else if (self.camera.sessionPreset == AVCaptureSessionPresetHigh) {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.recordView.alpha = 0.0;
            self.retakeButton.alpha = 0.0;
            self.stopButton.alpha = 0.0;
            self.capturePhotoButton.alpha = 1.0;
        } completion:^(BOOL finished) {
			self.camera.sessionPreset = AVCaptureSessionPresetPhoto;
            [self.switchCameraModeButton setTitle:@"Switch Video" forState:UIControlStateNormal];
            [self.flashModeButton setTitle:@"Flash : Auto" forState:UIControlStateNormal];
            self.camera.flashMode = SCFlashModeAuto;
        }];
    }
}

- (IBAction)switchFlash:(id)sender {
    NSString *flashModeString = nil;
    if (self.camera.sessionPreset == AVCaptureSessionPresetPhoto) {
        switch (self.camera.flashMode) {
            case SCFlashModeAuto:
                flashModeString = @"Flash : Off";
                self.camera.flashMode = SCFlashModeOff;
                break;
            case SCFlashModeOff:
                flashModeString = @"Flash : On";
                self.camera.flashMode = SCFlashModeOn;
                break;
            case SCFlashModeOn:
                flashModeString = @"Flash : Light";
                self.camera.flashMode = SCFlashModeLigth;
                break;
            case SCFlashModeLigth:
                flashModeString = @"Flash : Auto";
                self.camera.flashMode = SCFlashModeAuto;
                break;
            default:
                break;
        }
    } else if (self.camera.sessionPreset == AVCaptureSessionPresetHigh) {
        switch (self.camera.flashMode) {
            case SCFlashModeOff:
                flashModeString = @"Flash : On";
                self.camera.flashMode = SCFlashModeOn;
                break;
            case SCFlashModeOn:
                flashModeString = @"Flash : Off";
                self.camera.flashMode = SCFlashModeOff;
                break;
            default:
                break;
        }
    }
    
    [self.flashModeButton setTitle:flashModeString forState:UIControlStateNormal];
}

- (void) prepareCamera {
	if (![self.camera isPrepared]) {
		NSError * error;
		[self.camera prepareRecordingOnTempDir:&error];
		
		if (error != nil) {
			[self showAlertViewWithTitle:@"Failed to start camera" message:[error localizedFailureReason]];
			NSLog(@"%@", error);
		} else {
			NSLog(@"- CAMERA READY -");
		}
	}
}

- (void)handleTouchDetected:(SCTouchDetector*)touchDetector {
	if (self.camera.isPrepared) {
		if (touchDetector.state == UIGestureRecognizerStateBegan) {
			NSLog(@"==== STARTING RECORDING ====");
			[self.camera record];
		} else if (touchDetector.state == UIGestureRecognizerStateEnded) {
			NSLog(@"==== PAUSING RECORDING ====");
			[self.camera pause];
		}
	}
}

// Auto focus at a particular point. The focus mode will change to locked once the auto focus happens.
- (void)tapToAutoFocus:(UIGestureRecognizer *)gestureRecognizer
{
    if (self.camera.isFocusSupported) {
        CGPoint tapPoint = [gestureRecognizer locationInView:[self previewView]];
        CGPoint convertedFocusPoint = [self.camera convertToPointOfInterestFromViewCoordinates:tapPoint];
        self.cameraTagetView.center = tapPoint;
        [self.camera autoFocusAtPoint:convertedFocusPoint];
    }
}

// Change to continuous auto focus. The camera will constantly focus at the point choosen.
- (void)tapToContinouslyAutoFocus:(UIGestureRecognizer *)gestureRecognizer
{
    if (self.camera.isFocusSupported) {
        self.cameraTagetView.center = self.previewView.center;
        [self.camera continuousFocusAtPoint:CGPointMake(.5f, .5f)];
    }
}

- (IBAction)capturePhoto:(id)sender {
    [self.camera capturePhoto];
}

@end
