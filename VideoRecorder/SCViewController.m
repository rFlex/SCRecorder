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

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.camera = [[SCCamera alloc] initWithSessionPreset:AVCaptureSessionPreset1280x720];
    self.camera.delegate = self;
    self.camera.enableSound = NO;
    
    [self.camera initialize:^(NSError * audioError, NSError * videoError) {
        self.camera.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        self.camera.previewLayer.frame = self.previewView.bounds;
        [self.previewView.layer addSublayer:self.camera.previewLayer];
    }];
    
    [self.retakeButton addTarget:self action:@selector(handleRetakeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.stopButton addTarget:self action:@selector(handleStopButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.recordView addGestureRecognizer:[[SCTouchDetector alloc] initWithTarget:self action:@selector(handleTouchDetected:)]];
    self.loadingView.hidden = YES;
    
}

- (void) handleStopButtonTapped:(id)sender {
    self.loadingView.hidden = NO;
    self.downBar.userInteractionEnabled = NO;
    [self.camera stop];
}

- (void) handleRetakeButtonTapped:(id)sender {
    [self.camera cancel];
    [self updateLabelForSecond:0];
}

- (void) showAlertViewWithTitle:(NSString*)title message:(NSString*) message {
    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alertView show];
}

- (void)handleTouchDetected:(SCTouchDetector*)touchDetector {
    if (touchDetector.state == UIGestureRecognizerStateBegan) {
        NSLog(@"==== STARTING RECORDING ====");
        if (![self.camera isPrepared]) {
            NSError * error;
            [self.camera prepareRecordingAtCameraRoll:&error];
            
            if (error != nil) {
                [self showAlertViewWithTitle:@"Failed to start camera" message:[error localizedFailureReason]];
                NSLog(@"%@", error);
            } else {
                [self.camera record];
            }
        } else {
            [self.camera record];
        }
    } else if (touchDetector.state == UIGestureRecognizerStateEnded) {
        NSLog(@"==== PAUSING RECORDING ====");
        [self.camera pause];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];    
}

- (void) updateLabelForSecond:(Float64)totalRecorded {
    self.timeRecordedLabel.text = [NSString stringWithFormat:@"Recorded - %.2f sec", totalRecorded];
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didRecordVideoFrame:(Float64)frameSecond {
    [self updateLabelForSecond:frameSecond];
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFinishRecordingAtUrl:(NSURL *)recordedFile error:(NSError *)error {
    self.loadingView.hidden = YES;
    self.downBar.userInteractionEnabled = YES;
    if (error != nil) {
        [self showAlertViewWithTitle:@"Failed to save video" message:[error localizedFailureReason]];
    } else {
        [self showAlertViewWithTitle:@"Video saved!" message:@"Video saved successfully"];
    }
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeVideoEncoder:(NSError *)error {
    NSLog(@"Failed to initialize VideoEncoder");
}

- (void) audioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder didFailToInitializeAudioEncoder:(NSError *)error {
    NSLog(@"Failed to initialize AudioEncoder");
}


@end
