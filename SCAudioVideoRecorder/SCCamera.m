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

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
typedef UIView View;
#else
typedef NSView View;
#endif

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
    View * _previewView;
    SCCameraPreviewVideoGravity _previewVideoGravity;
}

@synthesize session;
@synthesize delegate;
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

- (void) dealloc {
    self.session = nil;
    self.previewLayer = nil;
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
            
            NSError * audioError;
            [self addInputToSession:captureSession withMediaType:AVMediaTypeAudio error:&audioError];
            if (!self.enableSound) {
                audioError = nil;
            }
            
            NSError * videoError;
            [self addInputToSession:captureSession withMediaType:AVMediaTypeVideo error:&videoError];
            if (!self.enableVideo) {
                videoError = nil;
            }
            
            [captureSession addOutput:self.audioOutput];
            [captureSession addOutput:self.videoOutput];
            
            self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
            self.previewLayer.videoGravity = [self previewVideoGravityToString];
            
            [captureSession startRunning];
            
            self.session = captureSession;
            dispatch_async(dispatch_get_main_queue(), ^ {
                View * settedPreviewView = self.previewView;
                
                // We force the setter to add the setted preview to the previewLayer
                if (settedPreviewView != nil) {
                    self.previewView = nil;
                    self.previewView = settedPreviewView;
                }
            });
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

- (NSString*) previewVideoGravityToString {
    switch (self.previewVideoGravity) {
        case SCVideoGravityResize:
            return AVLayerVideoGravityResize;
        case SCVideoGravityResizeAspect:
            return AVLayerVideoGravityResizeAspect;
        case SCVideoGravityResizeAspectFill:
            return AVLayerVideoGravityResizeAspectFill;
    }
    return nil;
}

- (BOOL) isReady {
    return self.session != nil;
}

- (void) setEnableSound:(BOOL)enableSound {
    self.audioEncoder.enabled = enableSound;
}

- (BOOL) enableSound {
    return self.audioEncoder.enabled;
}

- (void) setEnableVideo:(BOOL)enableVideo {
    self.videoEncoder.enabled = enableVideo;
}

- (BOOL) enableVideo {
    return self.videoEncoder.enabled;
}

- (void) setPreviewView:(View *)previewView {
    if (self.previewLayer != nil) {
        [self.previewLayer removeFromSuperlayer];
    }
    
    _previewView = previewView;
    
    if (previewView != nil && self.previewLayer != nil) {
#if !(TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE)
        self.previewLayer.autoresizingMask = self.previewView.autoresizingMask;
        [previewView setWantsLayer:YES];
#endif
        
        self.previewLayer.frame = previewView.bounds;
        [previewView.layer insertSublayer:self.previewLayer atIndex:0];
        
    }
}

- (View*) previewView {
    return _previewView;
}

- (void) setPreviewVideoGravity:(SCCameraPreviewVideoGravity)newPreviewVideoGravity {
    _previewVideoGravity = newPreviewVideoGravity;
    if (self.previewLayer) {
        self.previewLayer.videoGravity = [self previewVideoGravityToString];
    }
    
}

- (SCCameraPreviewVideoGravity) previewVideoGravity {
    return _previewVideoGravity;
}

@end
