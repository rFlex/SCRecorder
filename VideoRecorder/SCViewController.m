//
//  VRViewController.m
//  VideoRecorder
//
//  Created by Simon CORSIN on 8/3/13.
//  Copyright (c) 2013 SCorsin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "SCViewController.h"
#import "SCVideoRecorder.h"

@interface SCViewController () {
    
    AVCaptureSession * session;
    AVCaptureVideoPreviewLayer * previewLayer;
    AVCaptureInput * input;
    SCVideoRecorder * videoRecorder;
    
}

@end

@interface VRTouchDetector : UIGestureRecognizer {
    
}

@end

@implementation VRTouchDetector {
    
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.enabled) {
        self.state = UIGestureRecognizerStateBegan;
    }
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.enabled) {
        self.state = UIGestureRecognizerStateEnded;
    }
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    if (self.enabled) {
        self.State = UIGestureRecognizerStateEnded;
    }
}

@end

@implementation SCViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    videoRecorder = [[SCVideoRecorder alloc] initWithOutputVideoSize:CGSizeMake(640, 480)];
    
    session = [[AVCaptureSession alloc] init];
    
    AVCaptureDevice * captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    NSError * error;
    input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    
    if (error == nil) {
        [session addInput:input];
    } else {
        NSLog(@"Something bad happened");
    }
    
    previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    previewLayer.frame = self.previewView.bounds;
    [self.previewView.layer addSublayer:previewLayer];
    
    [session addOutput:videoRecorder];
    
    [self.retakeButton addTarget:self action:@selector(handleRetakeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.stopButton addTarget:self action:@selector(handleStopButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.recordView addGestureRecognizer:[[VRTouchDetector alloc] initWithTarget:self action:@selector(handleTouchDetected:)]];
    
}

- (void) handleStopButtonTapped:(id)sender {
    [videoRecorder stopRecording:^(NSURL *url, NSError * error) {
        if (error != nil) {
            [self showAlertViewWithTitle:@"Failed to save video" message:[error localizedFailureReason]];
        } else {
            [self showAlertViewWithTitle:@"Video saved!" message:@"Video saved successfully"];
        }
    }];
}

- (void) handleRetakeButtonTapped:(id)sender {
    [videoRecorder reset:nil];
}

- (void) showAlertViewWithTitle:(NSString*)title message:(NSString*) message {
    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alertView show];
}

- (void)handleTouchDetected:(VRTouchDetector*)touchDetector {
    if (touchDetector.state == UIGestureRecognizerStateBegan) {
        NSLog(@"==== STARTING RECORDING ====");
        if (![videoRecorder isRecordingStarted]) {
            if (![videoRecorder isInitializingRecording]) {
                [videoRecorder startRecordingAtCameraRoll:^(NSError * error) {
                    if (error != nil) {
                        [self showAlertViewWithTitle:@"Failed to start camera" message:[error localizedFailureReason]];
                        NSLog(@"%@", error);
                    }
                }];
            }
        } else {
            [videoRecorder resumeRecording];
        }
    } else if (touchDetector.state == UIGestureRecognizerStateEnded) {
        NSLog(@"==== PAUSING RECORDING ====");
        [videoRecorder pauseRecording];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [session startRunning];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
