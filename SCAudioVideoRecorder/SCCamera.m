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

static NSString * const SCCameraFocusObserverContext = @"SCCameraFocusObserverContext";
static NSString * const SCCameraCaptureStillImageIsCapturingStillImageObserverContext = @"SCCameraCaptureStillImageIsCapturingStillImageObserverContext";

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
	NSString * _sessionPreset;
}

@property (strong, nonatomic) AVCaptureSession * session;
@property (weak, nonatomic) AVCaptureDeviceInput * currentVideoDeviceInput;
@property (weak, nonatomic) AVCaptureDeviceInput * currentAudioDeviceInput;
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

@synthesize flashMode = _flashMode;
@synthesize isFocusSupported = _isFocusSupported;

- (void)addObserverForSession {
    // add notification observers
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // session notifications
    [notificationCenter addObserver:self selector:@selector(_sessionRuntimeErrored:) name:AVCaptureSessionRuntimeErrorNotification object:session];
    [notificationCenter addObserver:self selector:@selector(_sessionStarted:) name:AVCaptureSessionDidStartRunningNotification object:session];
    [notificationCenter addObserver:self selector:@selector(_sessionStopped:) name:AVCaptureSessionDidStopRunningNotification object:session];
    [notificationCenter addObserver:self selector:@selector(_sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:session];
    [notificationCenter addObserver:self selector:@selector(_sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:session];
    
    // capture device notifications
    [notificationCenter addObserver:self selector:@selector(_deviceSubjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:nil];
}

- (void)removeObserverForSession {
    if (!session)
        return;
    
    // remove notification observers (we don't want to just 'remove all' because we're also observing background notifications
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // session notifications
    [notificationCenter removeObserver:self name:AVCaptureSessionRuntimeErrorNotification object:session];
    [notificationCenter removeObserver:self name:AVCaptureSessionDidStartRunningNotification object:session];
    [notificationCenter removeObserver:self name:AVCaptureSessionDidStopRunningNotification object:session];
    [notificationCenter removeObserver:self name:AVCaptureSessionWasInterruptedNotification object:session];
    [notificationCenter removeObserver:self name:AVCaptureSessionInterruptionEndedNotification object:session];
    
    // capture device notifications
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:nil];
}

- (id) init {
    return [self initWithSessionPreset:AVCaptureSessionPresetHigh];
}

- (id) initWithSessionPreset:(NSString *)sessionPreset {
    self = [super init];
    
    if (self) {
		_sessionPreset = nil;
		_useFrontCamera = NO;
        self.flashMode = SCFlashModeAuto;
        self.sessionPreset = sessionPreset;
    }
    
    return self;
}

- (void) dealloc {
	if (self.session != nil) {
        [self stopRunningSession];
        
        [self removeObserverForSession];
		
		if (self.currentAudioDeviceInput != nil) {
			[self.session removeInput:self.currentAudioDeviceInput];
		}
		if (self.currentVideoDeviceInput != nil) {
            [self.currentVideoDeviceInput.device removeObserver:self forKeyPath:@"adjustingFocus"];
			[self.session removeInput:self.currentVideoDeviceInput];
		}
		[self.session removeOutput:self.audioOutput];
		[self.session removeOutput:self.videoOutput];
        if (self.stillImageOutput) {
            [self.stillImageOutput removeObserver:self forKeyPath:@"capturingStillImage" context:(__bridge void *)(SCCameraCaptureStillImageIsCapturingStillImageObserverContext)];
            [self.session removeOutput:self.stillImageOutput];
        }
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

// Session
- (void)startRunningSession {
    if (!session)
        return;
    
    [session startRunning];
    if ([self.delegate respondsToSelector:@selector(cameraSessionWillStart:)]) {
        [self.delegate cameraSessionWillStart:self];
    }
}

- (void)stopRunningSession {
    if (!session)
        return;
    
    [session stopRunning];
    if ([self.delegate respondsToSelector:@selector(cameraSessionWillStop:)]) {
        [self.delegate cameraSessionWillStop:self];
    }
}

- (void) initialize:(void(^)(NSError * audioError, NSError * videoError))completionHandler {
    if (![self isReady]) {
        dispatch_async(self.dispatch_queue, ^ {
            AVCaptureSession * captureSession = [[AVCaptureSession alloc] init];
            captureSession.sessionPreset = self.sessionPreset;
			
            NSError * audioError;
            self.currentAudioDeviceInput = [self addInputToSession:captureSession device:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio]
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
            // KVO is only used to monitor focus and capture events
            [self.stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:(__bridge void *)(SCCameraCaptureStillImageIsCapturingStillImageObserverContext)];
            [captureSession addOutput:self.stillImageOutput];
			
            self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
            self.previewLayer.videoGravity = [self previewVideoGravityToString];
            
            self.session = captureSession;
			
			// Apply the video orientation is it was set before the session was created
			self.videoOrientation = self.cachedVideoOrientation;
            
            // add session Observer
            [self addObserverForSession];
			
			[self startRunningSession];
			
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

- (void)_willCapturePhoto
{
    if ([self.delegate respondsToSelector:@selector(audioVideoRecorderWillCapturePhoto:)])
        [self.delegate audioVideoRecorderWillCapturePhoto:self];
}

- (void)_didCapturePhoto
{
    if ([self.delegate respondsToSelector:@selector(audioVideoRecorderDidCapturePhoto:)])
        [self.delegate audioVideoRecorderDidCapturePhoto:self];
}

- (NSString*) sessionPreset {
	return _sessionPreset;
}

- (void) setSessionPreset:(NSString *)sessionPreset {
	if (_sessionPreset != sessionPreset) {
		_sessionPreset = [sessionPreset copy];
		
		if (self.session != nil) {
			[self.session beginConfiguration];
			self.session.sessionPreset = _sessionPreset;
			[self.session commitConfiguration];
		}
	}
}

- (void)setFlashMode:(SCFlashMode)flashMode {
    AVCaptureDevice *_currentDevice = self.currentVideoDeviceInput.device;
    BOOL shouldChangeFlashMode = (_flashMode != flashMode);
    if (![_currentDevice hasFlash] || !shouldChangeFlashMode)
        return;
    
    _flashMode = flashMode;
    
    NSError *error = nil;
    if (_currentDevice && [_currentDevice lockForConfiguration:&error]) {
        [_currentDevice setTorchMode:(AVCaptureTorchMode)AVCaptureFlashModeOff];
        
        if (self.sessionPreset == AVCaptureSessionPresetHigh) {
            if ([_currentDevice isTorchModeSupported:(AVCaptureTorchMode)_flashMode]) {
                [_currentDevice setTorchMode:(AVCaptureTorchMode)_flashMode];
            }
        } else if (self.sessionPreset == AVCaptureSessionPresetPhoto) {
            if ([_currentDevice isFlashModeSupported:(AVCaptureFlashMode)_flashMode]) {
                [_currentDevice setFlashMode:(AVCaptureFlashMode)_flashMode];
            }
            
            if (_flashMode == SCFlashModeLigth) {
                if ([_currentDevice isTorchModeSupported:(AVCaptureTorchMode)AVCaptureFlashModeOn]) {
                    [_currentDevice setTorchMode:(AVCaptureTorchMode)AVCaptureFlashModeOn];
                }
            }
        }
        
        [_currentDevice unlockForConfiguration];
        
    } else if (error) {
        NSLog(@"error locking device for flash mode change (%@)", error);
    }
}

- (SCFlashMode)flashMode {
    return _flashMode;
}

- (BOOL)focusSupported {
    return [[self.currentVideoDeviceInput device] isFocusPointOfInterestSupported];
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
        [self.currentVideoDeviceInput.device removeObserver:self forKeyPath:@"adjustingFocus"];
		[captureSession removeInput:self.currentVideoDeviceInput];
		self.currentVideoDeviceInput = nil;
	}
	
	AVCaptureDevice * device = [self videoDeviceWithPosition:(self.useFrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack)];
	
	if (device != nil) {
		self.currentVideoDeviceInput = [self addInputToSession:captureSession device:device withMediaType:@"Video" error:error];
        [self.currentVideoDeviceInput.device addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:(__bridge void *)SCCameraFocusObserverContext];
	} else {
		if (error != nil) {
			*error = [SCAudioVideoRecorder createError:(self.useFrontCamera ? @"Front camera not found" : @"Back camera not found")];
		}
	}
    
    [captureSession setSessionPreset:self.sessionPreset];
}

- (BOOL) useFrontCamera {
	return _useFrontCamera;
}

- (void) setUseFrontCamera:(BOOL)value {
	_useFrontCamera = value;
	[self reconfigureSessionInputs];
}

- (void) reconfigureSessionInputs {
    if (self.session != nil) {
		[self.session beginConfiguration];
		
		NSError * error;
		[self initializeCamera:self.session error:&error];
		
		self.videoOrientation = self.cachedVideoOrientation;
		[self.session commitConfiguration];
	}
}

#endif

#pragma mark - AV NSNotifications

// capture session

// TODO: add in a better error recovery

- (void)_sessionRuntimeErrored:(NSNotification *)notification
{
    [self dispatchBlockOnAskedQueue:^{
        if ([notification object] == session) {
            NSError *error = [[notification userInfo] objectForKey:AVCaptureSessionErrorKey];
            if (error) {
                NSInteger errorCode = [error code];
                switch (errorCode) {
                    case AVErrorMediaServicesWereReset:
                    {
                        DLog(@"error media services were reset");
                        break;
                    }
                    case AVErrorDeviceIsNotAvailableInBackground:
                    {
                        DLog(@"error media services not available in background");
                        break;
                    }
                    default:
                    {
                        DLog(@"error media services failed, error (%@)", error);
                        break;
                    }
                }
            }
        }
    }];
}

- (void)_sessionStarted:(NSNotification *)notification
{
    [self dispatchBlockOnAskedQueue:^{
        if ([notification object] == session) {
            DLog(@"session was started");
            
            if ([self.delegate respondsToSelector:@selector(cameraSessionDidStart:)]) {
                [self.delegate cameraSessionDidStart:self];
            }
        }
    }];
}

- (void)_sessionStopped:(NSNotification *)notification
{
    [self dispatchBlockOnAskedQueue:^{
        if ([notification object] == session) {
            if ([self.delegate respondsToSelector:@selector(cameraSessionDidStop:)]) {
                [self.delegate cameraSessionDidStop:self];
            }
        }
    }];
}

- (void)_sessionWasInterrupted:(NSNotification *)notification
{
    [self dispatchBlockOnAskedQueue:^{
        if ([notification object] == session) {
            DLog(@"session was interrupted");
            // notify stop?
        }
    }];
}

- (void)_sessionInterruptionEnded:(NSNotification *)notification
{
    [self dispatchBlockOnAskedQueue:^{
        if ([notification object] == session) {
            DLog(@"session interruption ended");
            // notify ended?
        }
    }];
}

// capture device

- (void)_deviceSubjectAreaDidChange:(NSNotification *)notification
{
    [self _focus];
}

#pragma mark - focus, exposure, white balance

// Convert from view coordinates to camera coordinates, where {0,0} represents the top left of the picture area, and {1,1} represents
// the bottom right in landscape mode with the home button on the right.
- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates
{
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = self.previewView.frame.size;
    
    if ([self.previewLayer.connection isVideoMirrored]) {
        viewCoordinates.x = frameSize.width - viewCoordinates.x;
    }
    
    if ( [[self.previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize] ) {
		// Scale, switch x and y, and reverse x
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for (AVCaptureInputPort *port in [self.currentVideoDeviceInput ports]) {
            if ([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if ( [[self.previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect] ) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
						// If point is inside letterboxed area, do coordinate conversion; otherwise, don't change the default value returned (.5,.5)
                        if (point.x >= blackBar && point.x <= blackBar + x2) {
							// Scale (accounting for the letterboxing on the left and right of the video preview), switch x and y, and reverse x
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
						// If point is inside letterboxed area, do coordinate conversion. Otherwise, don't change the default value returned (.5,.5)
                        if (point.y >= blackBar && point.y <= blackBar + y2) {
							// Scale (accounting for the letterboxing on the top and bottom of the video preview), switch x and y, and reverse x
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if ([[self.previewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
					// Scale, switch x and y, and reverse x
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2; // Account for cropped height
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2); // Account for cropped width
                        xc = point.y / frameSize.height;
                    }
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}

// Perform an auto focus at the specified point. The focus mode will automatically change to locked once the auto focus is complete.
- (void) autoFocusAtPoint:(CGPoint)point
{
    AVCaptureDevice *device = [self.currentVideoDeviceInput device];
    if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device unlockForConfiguration];
        } else {
            if ([[self delegate] respondsToSelector:@selector(audioVideoRecorder::didFailWithError:)]) {
                [[self delegate] audioVideoRecorder:self didFailWithError:error];
            }
        }
    }
}

// Switch to continuous auto focus mode at the specified point
- (void) continuousFocusAtPoint:(CGPoint)point
{
    AVCaptureDevice *device = [self.currentVideoDeviceInput device];
	
    if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
		NSError *error;
		if ([device lockForConfiguration:&error]) {
			[device setFocusPointOfInterest:point];
			[device setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
			[device unlockForConfiguration];
		} else {
			if ([[self delegate] respondsToSelector:@selector(audioVideoRecorder:didFailWithError:)]) {
                [[self delegate] audioVideoRecorder:self didFailWithError:error];
			}
		}
	}
}

- (void)_focusStarted
{
    if ([self.delegate respondsToSelector:@selector(audioVideoRecorderWillStartFocus:)])
        [self.delegate audioVideoRecorderWillStartFocus:self];
}

- (void)_focusEnded
{
    if ([self.delegate respondsToSelector:@selector(audioVideoRecorderDidStopFocus:)])
        [self.delegate audioVideoRecorderDidStopFocus:self];
}

- (void)_focus
{
    AVCaptureDevice *device = [self.currentVideoDeviceInput device];
    if ([device isAdjustingFocus] || [device isAdjustingExposure])
        return;
    
    // only notify clients when focus is triggered from an event
    if ([self.delegate respondsToSelector:@selector(visionWillStartFocus:)])
        [self.delegate audioVideoRecorderWillStartFocus:self];
    
    CGPoint focusPoint = CGPointMake(0.5f, 0.5f);
    [self autoFocusAtPoint:focusPoint];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ( context == (__bridge void *)SCCameraFocusObserverContext ) {
        
        BOOL isFocusing = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (isFocusing) {
            [self _focusStarted];
        } else {
            [self _focusEnded];
        }
        
	} else if ( context == (__bridge void *)(SCCameraCaptureStillImageIsCapturingStillImageObserverContext) ) {
        
		BOOL isCapturingStillImage = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
		if ( isCapturingStillImage ) {
            [self _willCapturePhoto];
		} else {
            [self _didCapturePhoto];
        }
        
	}
}

@end
