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

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface SCViewController () {

}

@property (strong, nonatomic) SCCamera * camera;

@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCViewController

@synthesize camera;

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

- (void)viewDidLoad
{
    [super viewDidLoad];
	
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
//	self.navigationController.navigationBarHidden = YES;
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

- (void) showAlertViewWithTitle:(NSString*)title message:(NSString*) message {
    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alertView show];
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

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
	if (self.camera.isPrepared) {
		[self.camera.session startRunning];
	}
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	
	[self.camera cancel];
}

- (void) updateLabelForSecond:(Float64)totalRecorded {
    self.timeRecordedLabel.text = [NSString stringWithFormat:@"Recorded - %.2f sec", totalRecorded];
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didRecordVideoFrame:(CMTime)frameTime {
    [self updateLabelForSecond:CMTimeGetSeconds(frameTime)];
}

- (void) showVideo:(NSURL*)videoUrl {
	SCVideoPlayerViewController * videoPlayerViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"SCVideoPlayerViewController"];
	videoPlayerViewController.videoUrl = videoUrl;
	
	[self.navigationController pushViewController:videoPlayerViewController animated:YES];
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

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeVideoEncoder:(NSError *)error {
    NSLog(@"Failed to initialize VideoEncoder");
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeAudioEncoder:(NSError *)error {
    NSLog(@"Failed to initialize AudioEncoder");
}

- (UIStatusBarStyle) preferredStatusBarStyle {
	return UIStatusBarStyleLightContent;
}


@end
