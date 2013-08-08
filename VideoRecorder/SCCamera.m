//
//  SCCamera.m
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/6/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "SCCamera.h"
#import "SCAudioVideoRecorderInternal.h"

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface SCCamera() {
    
}

@property (strong, nonatomic) AVCaptureSession * session;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer * previewLayer;

@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCCamera {
    
}

@synthesize session;
@synthesize delegate;
@synthesize enableSound;
@synthesize enableVideo;
@synthesize previewLayer;

- (id) init {
    self = [super init];
    
    if (self) {
        self.sessionPreset = AVCaptureSessionPresetHigh;
        self.enableSound = YES;
        self.enableVideo = YES;
    }
    
    return self;
}

- (id) initWithSessionPreset:(NSString *)sessionPreset {
    self = [self init];
    
    if (self) {
        self.sessionPreset = sessionPreset;
    }
    
    return self;
}

- (void) addInputToSession:(AVCaptureSession*)captureSession withMediaType:(NSString*)mediaType error:(NSError**)error {
    *error = nil;
    
    AVCaptureDevice * device = [AVCaptureDevice defaultDeviceWithMediaType:mediaType];
    
    if (device != nil) {
        AVCaptureDeviceInput * input = [AVCaptureDeviceInput deviceInputWithDevice:device error:error];
        if (*error == nil) {
            [captureSession addInput:input];
        }
    } else {
        *error = [SCAudioVideoRecorder createError:[NSString stringWithFormat:@"No device of type %@ were found", mediaType]];
    }
}

- (void) initialize:(void(^)(NSError * audioError, NSError * videoError))completionHandler {
    if (![self isReady]) {
        dispatch_async(self.dispatch_queue, ^ {
            AVCaptureSession * captureSession = [[AVCaptureSession alloc] init];
            
            self.audioEncoder.enabled = self.enableSound;
            self.videoEncoder.enabled = self.enableVideo;
            
            NSError * audioError;
            if (self.enableSound) {
                [self addInputToSession:captureSession withMediaType:AVMediaTypeAudio error:&audioError];
            }
            
            NSError * videoError;
            if (self.enableVideo) {
                [self addInputToSession:captureSession withMediaType:AVMediaTypeVideo error:&videoError];
            }
            
            [captureSession addOutput:self.audioOutput];
            [captureSession addOutput:self.videoOutput];
            
            self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
            
            [captureSession startRunning];
            
            self.session = captureSession;
            if (completionHandler != nil) {
                [self dispatchBlockOnAskedQueue:^ {
                    completionHandler(audioError, videoError);
                }];
            }
        });
    }
}

- (void) prepareRecordingAtUrl:(NSURL *)fileUrl error:(NSError **)error {
    if ([self isReady]) {
        [super prepareRecordingAtUrl:fileUrl error:error];
    } else {
        if (error != nil) {
            *error = [SCAudioVideoRecorder createError:@"The camera must be initialized before trying to record"];
        }
    }
}

- (void) dealloc {
    self.session = nil;
    self.previewLayer = nil;
}

- (BOOL) isReady {
    return self.session != nil;
}

@end
