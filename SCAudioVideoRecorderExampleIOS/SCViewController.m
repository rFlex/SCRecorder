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

#import "SCCameraTargetView.h"

#import <CoreMotion/CoreMotion.h>

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

typedef NS_ENUM(NSInteger, CapturePhotoType) {
    kNormal = 0,
    kMotion,
    kContinuous,
};

@interface SCViewController () <UIGestureRecognizerDelegate> {
    CGFloat beginGestureScale;
	CGFloat effectiveScale;
}

@property (strong, nonatomic) SCCamera * camera;
@property (strong, nonatomic) SCCameraTargetView *cameraTagetView;

@property (strong, nonatomic) UIView *flashView;

@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) NSOperationQueue *motionGyroUpdatesQueue;

@property (assign, nonatomic) CapturePhotoType capturePhotoType;
@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCViewController

@synthesize camera;

#pragma mark - setter / getter

- (void)_motion {
    [self.motionGyroUpdatesQueue cancelAllOperations];
    self.motionGyroUpdatesQueue = nil;
    
    [self.motionManager stopAccelerometerUpdates];
    [self.motionManager stopDeviceMotionUpdates];
    [self.motionManager stopMagnetometerUpdates];
    [self.motionManager stopGyroUpdates];
    self.motionManager = nil;
    
    self.shakeproofProgressView.progress = 0.0;
    
    self.capturePhotoType = kNormal;
    
    [self capturePhoto:nil];
}

- (void)setCapturePhotoType:(CapturePhotoType)capturePhotoType {
    _capturePhotoType = capturePhotoType;
    switch (_capturePhotoType) {
        case kMotion:
            [self _motion];
            break;
        default:
            break;
    }
}

- (SCCameraTargetView *)cameraTagetView {
    if (!_cameraTagetView) {
        _cameraTagetView = [[SCCameraTargetView alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
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
		DLog(@"Downloading...");
		NSURL * url = [NSURL URLWithString:@"http://a420.phobos.apple.com/us/r1000/041/Music/v4/28/01/5a/28015aa7-72b0-d0b8-9da1-ce414cd6e61b/mzaf_4547488074890633094.plus.aac.p.m4a"];
		NSData * data = [NSData dataWithContentsOfURL:url];
		DLog(@"Saving at %@", fileUrl.absoluteString);
		[data writeToURL:fileUrl atomically:YES];
		DLog(@"OK!");
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
    
    // Add pin gesture
    UIPinchGestureRecognizer *pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    pinchGestureRecognizer.delegate = self;
    [self.previewView addGestureRecognizer:pinchGestureRecognizer];
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
		DLog(@"Starting to run");
		[self.camera startRunningSession];
	} else {
		DLog(@"Not prepared yet");
	}
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	[self.camera stopRunningSession];
	[self.camera cancel];
}

- (void)dealloc {
    self.camera = nil;
    self.cameraTagetView = nil;
}

- (void) updateLabelForSecond:(Float64)totalRecorded {
    self.timeRecordedLabel.text = [NSString stringWithFormat:@"Recorded - %.2f sec", totalRecorded];
}

#pragma mark - SCAudioVideoRecorder delegate

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didRecordVideoFrame:(CMTime)frameTime {
    [self updateLabelForSecond:CMTimeGetSeconds(frameTime)];
}

// error
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeVideoEncoder:(NSError *)error {
    DLog(@"Failed to initialize VideoEncoder");
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeAudioEncoder:(NSError *)error {
    DLog(@"Failed to initialize AudioEncoder");
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder willFinishRecordingAtTime:(CMTime)frameTime {
	self.loadingView.hidden = NO;
    self.downBar.userInteractionEnabled = NO;
}

// Video

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

#pragma mark - Camera Delegate

// Camera
- (void)camera:(SCCamera *)camera didFailWithError:(NSError *)error {
    DLog(@"error : %@", error.description);
}

// Photo
- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder capturedPhoto:(NSDictionary *)photoDict error:(NSError *)error {
    if (!error) {
//        [self.camera stopRunningSession];
//        [self showPhoto:[photoDict valueForKey:SCAudioVideoRecorderPhotoImageKey]];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
            [assetLibrary writeImageDataToSavedPhotosAlbum:[photoDict objectForKey:SCAudioVideoRecorderPhotoJPEGKey] metadata:[photoDict objectForKey:SCAudioVideoRecorderPhotoMetadataKey] completionBlock:^(NSURL *assetURL, NSError *blockError) {
                DLog(@"Saved to the camera roll.");
            }];
        });
    }
}


// Photo
- (void)cameraWillCapturePhoto:(SCCamera *)camera {
    DLog(@"Will capture photo");
    // do flash bulb like animation
    if (!_flashView) {
        _flashView = [[UIView alloc] initWithFrame:[self.previewView frame]];
        [_flashView setBackgroundColor:[UIColor whiteColor]];
        [_flashView setAlpha:0.f];
        [[[self view] window] addSubview:self.flashView];
    }
    
    [UIView animateWithDuration:.4f
                     animations:^{
                         [_flashView setAlpha:1.f];
                     }
     ];
}

- (void)cameraDidCapturePhoto:(SCCamera *)camera {
    DLog(@"Did capture photo");
    [UIView animateWithDuration:.4f
                     animations:^{
                         [_flashView setAlpha:0.f];
                     }
                     completion:^(BOOL finished){
                         [_flashView removeFromSuperview];
                         self.flashView = nil;
                     }
     ];
}

// Focus
- (void)cameraWillStartFocus:(SCCamera *)camera {
    DLog(@"WillStartFocus");
    [self.cameraTagetView startTargeting];
}

- (void)cameraDidStopFocus:(SCCamera *)camera {
    DLog(@"cameraDidStopFocus");
    [self.cameraTagetView stopTargeting];	
}

- (void)camera:(SCCamera *)camera didFailFocus:(NSError *)error {
    DLog(@"DidFailFocus");
    [self.cameraTagetView stopTargeting];
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

- (void)cameraUpdateFocusMode:(NSString *)focusModeString {
    DLog(@"%@", focusModeString);
}

- (void)camera:(SCCamera *)camera cleanApertureDidChange:(CGRect)cleanAperture {
    DLog(@"%@", NSStringFromCGRect(cleanAperture));
}

#pragma mark - UIGestureRecognizer delegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
	if ( [gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] ) {
		beginGestureScale = effectiveScale;
	}
	return [self isAllowAVCaptureSessionPresetPhoto];
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

- (BOOL)isAllowAVCaptureSessionPresetPhoto {
    return self.camera.sessionPreset == AVCaptureSessionPresetPhoto;
}

- (BOOL)isAllowAVCaptureSessionPresetHigh {
    return self.camera.sessionPreset == AVCaptureSessionPresetHigh;
}

- (IBAction)switchCameraMode:(id)sender {
    if (!self.camera.isReady)
        return;
    
    if ([self isAllowAVCaptureSessionPresetPhoto]) {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.capturePhotoButton.alpha = 0.0;
            self.recordView.alpha = 1.0;
            self.retakeButton.alpha = 1.0;
            self.stopButton.alpha = 1.0;
            self.cameraEffectiveScaleSlider.alpha = 0.0;
            self.shakeproofProgressView.alpha = 0.0;
        } completion:^(BOOL finished) {
			self.camera.sessionPreset = AVCaptureSessionPresetHigh;
            [self.switchCameraModeButton setTitle:@"Switch Photo" forState:UIControlStateNormal];
            [self.flashModeButton setTitle:@"Flash : Off" forState:UIControlStateNormal];
            self.camera.flashMode = SCFlashModeOff;
        }];
    } else if ([self isAllowAVCaptureSessionPresetHigh]) {
        [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.recordView.alpha = 0.0;
            self.retakeButton.alpha = 0.0;
            self.stopButton.alpha = 0.0;
            self.capturePhotoButton.alpha = 1.0;
            self.cameraEffectiveScaleSlider.alpha = 1.0;
            self.shakeproofProgressView.alpha = 1.0;
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
    if ([self isAllowAVCaptureSessionPresetPhoto]) {
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
                self.camera.flashMode = SCFlashModeLight;
                break;
            case SCFlashModeLight:
                flashModeString = @"Flash : Auto";
                self.camera.flashMode = SCFlashModeAuto;
                break;
            default:
                break;
        }
    } else {
        switch (self.camera.flashMode) {
            case SCFlashModeOff:
                flashModeString = @"Flash : On";
                self.camera.flashMode = SCFlashModeLight;
                break;
            case SCFlashModeLight:
                flashModeString = @"Flash : Off";
                self.camera.flashMode = SCFlashModeOff;
                break;
            default:
                break;
        }
    }
    
    [self.flashModeButton setTitle:flashModeString forState:UIControlStateNormal];
}

- (IBAction)capturePhoto:(id)sender {
    [self.camera capturePhoto];
}

- (IBAction)cameraEffectiveScaleSliderValueChange:(UISlider *)sender {
    effectiveScale = sender.value;
    [self effectiveScaleWithPreviewLayer];
}

- (void)_startTimer {
    void (^capturePhoto)() = ^{
        if (self.capturePhotoType == kContinuous)
            [self capturePhoto:nil];
    };
    __block int timeout = 10; //倒计时时间
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,queue);
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 1), 1.0*NSEC_PER_SEC, 0); //每秒执行
    dispatch_source_set_event_handler(_timer, ^{
        if(timeout <= 0){ //倒计时结束，关闭
            dispatch_async(dispatch_get_main_queue(), ^{
                //设置界面的按钮显示 根据自己需求设置
                self.capturePhotoType = kNormal;
                DLog(@"什么地方来了，是已经连拍结束了");
            });
            dispatch_source_cancel(_timer);
        } else {
            /*
            int minutes = timeout / 60;
            int seconds = timeout % 60;
            NSString *strTime = [NSString stringWithFormat:@"%d分%.2d秒后重新获取验证码",minutes, seconds];
            DLog(@"%@", strTime);
             */
            dispatch_async(dispatch_get_main_queue(), capturePhoto);
            timeout --;
        }
    });
    dispatch_resume(_timer);
}

- (IBAction)continuousBegin:(id)sender {
    self.capturePhotoType = kContinuous;
    [self _startTimer];
}

- (void) prepareCamera {
    // silder with camera stillImageOutput maxScaleAndCropFactor
    self.cameraEffectiveScaleSlider.minimumValue = 1.0;
    self.cameraEffectiveScaleSlider.maximumValue = self.camera.maxScaleAndCropFactor;
    
	if (![self.camera isPrepared]) {
		NSError * error;
		[self.camera prepareRecordingOnTempDir:&error];
        
		if (error != nil) {
			[self showAlertViewWithTitle:@"Failed to start camera" message:[error localizedFailureReason]];
			DLog(@"%@", error);
		} else {
			DLog(@"- CAMERA READY -");
		}
	}
}

// scale image depending on users pinch gesture
- (void)effectiveScaleWithPreviewLayer {
    if (effectiveScale < 1.0)
        effectiveScale = 1.0;
    CGFloat maxScaleAndCropFactor = self.camera.maxScaleAndCropFactor;
    if (effectiveScale > maxScaleAndCropFactor)
        effectiveScale = maxScaleAndCropFactor;
    
    self.camera.effectiveScale = effectiveScale;
    [CATransaction begin];
    [CATransaction setAnimationDuration:.025];
    [self.camera.previewLayer setAffineTransform:CGAffineTransformMakeScale(effectiveScale, effectiveScale)];
    [CATransaction commit];
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer
{
	BOOL allTouchesAreOnThePreviewLayer = YES;
	NSUInteger numTouches = [recognizer numberOfTouches], i;
	for ( i = 0; i < numTouches; ++i ) {
		CGPoint location = [recognizer locationOfTouch:i inView:self.previewView];
		CGPoint convertedLocation = [self.camera.previewLayer convertPoint:location fromLayer:self.camera.previewLayer.superlayer];
		if ( ! [self.camera.previewLayer containsPoint:convertedLocation] ) {
			allTouchesAreOnThePreviewLayer = NO;
			break;
		}
	}
	
	if ( allTouchesAreOnThePreviewLayer ) {
		effectiveScale = beginGestureScale * recognizer.scale;
		[self effectiveScaleWithPreviewLayer];
	}
}

- (void)handleTouchDetected:(SCTouchDetector*)touchDetector {
	if (self.camera.isPrepared) {
		if (touchDetector.state == UIGestureRecognizerStateBegan) {
			DLog(@"==== STARTING RECORDING ====");
			[self.camera record];
		} else if (touchDetector.state == UIGestureRecognizerStateEnded) {
			DLog(@"==== PAUSING RECORDING ====");
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

- (IBAction)shakeproofCapturePhoto:(UIButton *)sender {
    if (!_motionManager) {
        _motionManager = [[CMMotionManager alloc] init];
        if (_motionManager.gyroAvailable) {
            if (!_motionGyroUpdatesQueue) {
                _motionGyroUpdatesQueue = [[NSOperationQueue alloc] init];
            }
            
            _motionManager.gyroUpdateInterval = 1.0 / 60.0;
            [_motionManager startGyroUpdatesToQueue:self.motionGyroUpdatesQueue withHandler:^(CMGyroData *gyroData, NSError *error) {
                if (error) {
                    [_motionManager stopGyroUpdates];
                    DLog(@"%@", [NSString stringWithFormat:@"Gyroscope encountered error: %@", error]);
                } else {
                    double xx = fabs(gyroData.rotationRate.x);
                    double yy = fabs(gyroData.rotationRate.y);
                    double zz = fabs(gyroData.rotationRate.z);
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.shakeproofProgressView.progress = xx;
                        
                        float accelerationThreshold = 0.011;
                        //DLog(@"xx : %f yy:%f zz:%f", xx, yy, zz);
                        if (xx < accelerationThreshold && yy < accelerationThreshold && zz < accelerationThreshold) {
                            self.capturePhotoType = kMotion;
                        }
                    });
                }
            }];
        }
    }
}


@end
