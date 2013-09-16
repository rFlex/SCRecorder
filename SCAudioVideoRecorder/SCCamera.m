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
    BOOL _useFrontCamera;
}

@property (strong, nonatomic) AVCaptureSession * session;
@property (weak, nonatomic) AVCaptureDeviceInput * currentVideoDeviceInput;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer * previewLayer;
@property (assign, nonatomic) AVCaptureVideoOrientation cachedVideoOrientation;

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
		_useFrontCamera = NO;
        self.sessionPreset = AVCaptureSessionPresetHigh;
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
	if (self.session != nil) {
		[self.session stopRunning];
	}
}

+ (SCCamera*) camera {
    return [[SCCamera alloc] init];
}

- (AVCaptureDeviceInput*) addInputToSession:(AVCaptureSession*)captureSession device:(AVCaptureDevice*)device withMediaType:(NSString*)mediaType error:(NSError**)error {
    *error = nil;
	AVCaptureDeviceInput * input = nil;
    if (device != nil) {
        input = [AVCaptureDeviceInput deviceInputWithDevice:device error:error];
        if (*error == nil) {
            [captureSession addInput:input];
        }
    } else {
        *error = [SCAudioVideoRecorder createError:[NSString stringWithFormat:@"No device of type %@ were found", mediaType]];
    }
	return input;
}

- (AVCaptureDevice*) videoDeviceWithPosition:(AVCaptureDevicePosition)position {
	NSArray * videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	
	for (AVCaptureDevice * device in videoDevices) {
		if (device.position == position) {
			return device;
		}
	}
	
	return nil;
}

- (void) initialize:(void(^)(NSError * audioError, NSError * videoError))completionHandler {
    if (![self isReady]) {
        dispatch_async(self.dispatch_queue, ^ {
            AVCaptureSession * captureSession = [[AVCaptureSession alloc] init];
            captureSession.sessionPreset = self.sessionPreset;
			
            NSError * audioError;
            [self addInputToSession:captureSession device:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio]
 withMediaType:@"Audio" error:&audioError];
            if (!self.enableSound) {
                audioError = nil;
            }
            
            NSError * videoError;
			
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
			[self initializeCamera:captureSession error:&videoError];
#else
            [self addInputToSession:captureSession device:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] withMediaType:@"Video" error:&videoError];
#endif
            if (!self.enableVideo) {
                videoError = nil;
			}
            
            [captureSession addOutput:self.audioOutput];
            [captureSession addOutput:self.videoOutput];
			
            self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
            self.previewLayer.videoGravity = [self previewVideoGravityToString];
            
            self.session = captureSession;
			
			// Apply the video orientation is it was set before the session was created
			self.videoOrientation = self.cachedVideoOrientation;
			
			[captureSession startRunning];
			
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

- (AVCaptureConnection*) getVideoConnection {
	for (AVCaptureConnection * connection in self.videoOutput.connections) {
		for (AVCaptureInputPort * port in connection.inputPorts) {
			if ([port.mediaType isEqual:AVMediaTypeVideo]) {
				return connection;
			}
		}
	}
	
	return nil;
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

- (void) setVideoOrientation:(AVCaptureVideoOrientation)videoOrientation {
	AVCaptureConnection * videoConnection = [self getVideoConnection];
	
	if (videoConnection != nil) {
		[videoConnection setVideoOrientation:videoOrientation];
	}
	
	self.cachedVideoOrientation = videoOrientation;
}

- (AVCaptureVideoOrientation) videoOrientation {
	AVCaptureConnection * videoConnection = [self getVideoConnection];
	
	if (videoConnection != nil) {
		return [videoConnection videoOrientation];
	}
	
	return self.cachedVideoOrientation;
}

////////////////////////////////////////////////////////////
// IOS SPECIFIC
/////////////////////

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE

- (void) switchCamera {
	self.useFrontCamera = !self.useFrontCamera;
}

- (void) initializeCamera:(AVCaptureSession*)captureSession error:(NSError**)error {
	
	if (self.currentVideoDeviceInput != nil) {
		[captureSession removeInput:self.currentVideoDeviceInput];
		self.currentVideoDeviceInput = nil;
	}
	
	AVCaptureDevice * device = [self videoDeviceWithPosition:(self.useFrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack)];
	
	if (device != nil) {
		self.currentVideoDeviceInput = [self addInputToSession:captureSession device:device withMediaType:@"Video" error:error];
	} else {
		if (error != nil) {
			*error = [SCAudioVideoRecorder createError:(self.useFrontCamera ? @"Front camera not found" : @"Back camera not found")];
		}
	}
}

- (BOOL) useFrontCamera {
	return _useFrontCamera;
}

- (void) setUseFrontCamera:(BOOL)value {
	_useFrontCamera = value;
	
	if (self.session != nil) {
		NSError * error;
		
		BOOL wasRunning = [self.session isRunning];
		
		if (wasRunning) {
			[self.session stopRunning];
		}
		
		[self initializeCamera:self.session error:&error];
		
		if (wasRunning) {
			self.videoOrientation = self.cachedVideoOrientation;
			[self.session startRunning];
		}
	}
}

#endif

@end
