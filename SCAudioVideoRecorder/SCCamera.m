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

static void *SCCameraFocusModeObserverContext = &SCCameraFocusModeObserverContext;

typedef UIView View;

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface SCCamera() {
    BOOL _useFrontCamera;
    BOOL _openingSession;
    NSInteger _configurationBeganCount;
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
@synthesize delegate = _delegate;
@synthesize previewLayer;
@synthesize flashMode = _flashMode;
@synthesize isFocusSupported = _isFocusSupported;
@synthesize cameraDevice = _cameraDevice;


- (id) init {
    return [self initWithSessionPreset:AVCaptureSessionPresetHigh];
}

- (id) initWithSessionPreset:(NSString *)sessionPreset {
    self = [super init];
    
    if (self) {
        _configurationBeganCount = 0;
		_sessionPreset = nil;
		_useFrontCamera = NO;
        self.sessionPreset = sessionPreset;
        _cameraDevice = SCCameraDeviceBack;
        self.flashMode = SCFlashModeAuto;
    }
    
    return self;
}

- (void) dealloc {
    [self disposeSession];
}

+ (SCCamera*) camera {
    return [[SCCamera alloc] init];
}

- (AVCaptureDeviceInput*) addInputToSession:(AVCaptureSession*)captureSession device:(AVCaptureDevice*)device withMediaType:(NSString*)mediaType error:(NSError**)error {
    if (error != nil)
        *error = nil;
	AVCaptureDeviceInput * input = nil;
    if (device != nil) {
        NSError *outError = nil;
        input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&outError];
        if (error != nil)
            *error = outError;
        if (outError == nil) {
            [captureSession addInput:input];
        }
    } else {
        if (error != nil)
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
    if (!session && session.isRunning)
        return;
    
    [session startRunning];
    
    id<SCCameraDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(cameraSessionWillStart:)]) {
        [delegate cameraSessionWillStart:self];
    }
}

- (void)stopRunningSession {
    if (!session && !session.isRunning)
        return;
    
    [session stopRunning];
    
    id<SCCameraDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(cameraSessionWillStop:)]) {
        [delegate cameraSessionWillStop:self];
    }
}

- (void)initialize:(void (^)(NSError *, NSError *))completionHandler {
    [self openSession:completionHandler];
}

- (void) openSession:(void(^)(NSError * audioError, NSError * videoError))completionHandler {
    if (![self isSessionOpened]) {
        _openingSession = YES;
        dispatch_async(self.dispatch_queue, ^{
            AVCaptureSession * captureSession = [[AVCaptureSession alloc] init];
            captureSession.sessionPreset = self.sessionPreset;
			
            NSError * audioError;
            self.currentAudioDeviceInput = [self addInputToSession:captureSession device:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio]
 withMediaType:@"Audio" error:&audioError];
            if (!self.enableSound) {
                audioError = nil;
            }
            
            NSError * videoError;
			
			[self initializeCamera:captureSession error:&videoError];

            if (!self.enableVideo) {
                videoError = nil;
			}
            
            [captureSession addOutput:self.audioOutput];
            [captureSession addOutput:self.videoOutput];
            // KVO is only used to monitor focus and capture events
//            [self.stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:(__bridge void *)(SCCameraCaptureStillImageIsCapturingStillImageObserverContext)];
//            [captureSession addOutput:self.stillImageOutput];
			
            self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
            self.previewLayer.videoGravity = [self previewVideoGravityToString];
            
            [self addObserverForSession:captureSession];
            
            self.session = captureSession;
			
			// Apply the video orientation is it was set before the session was created
			self.videoOrientation = self.cachedVideoOrientation;
			
            dispatch_async(dispatch_get_main_queue(), ^ {
                View * settedPreviewView = self.previewView;
                
                // We force the setter to add the setted preview to the previewLayer
                if (settedPreviewView != nil) {
                    self.previewView = nil;
                    self.previewView = settedPreviewView;
                }
            });
            _openingSession = NO;
            if (completionHandler != nil) {
                [self dispatchBlockOnAskedQueue:^ {
                    completionHandler(audioError, videoError);
                }];
            }
        });
    } else {
        if (completionHandler != nil) {
            completionHandler(nil, nil);
        }
    }
}

- (void)disposeSession {
    if (self.session != nil) {
        [self.previewLayer removeFromSuperlayer];
        self.previewLayer = nil;
        
        [self removeObserverForSession];
        [self stopRunningSession];
        
		while (self.session.inputs.count > 0) {
			AVCaptureInput * input = [self.session.inputs objectAtIndex:0];
			[self.session removeInput:input];
		}
		
		while (self.session.outputs.count > 0) {
			AVCaptureOutput * output = [self.session.outputs objectAtIndex:0];
			[self.session removeOutput:output];
		}
        self.session = nil;
	}
}

- (void)closeSession {
    [self reset];
    [self disposeSession];
}

- (BOOL) prepareRecordingAtUrl:(NSURL *)fileUrl error:(NSError **)error {
    if ([self isSessionOpened]) {
        return [super prepareRecordingAtUrl:fileUrl error:error];
    } else {
        if (error != nil) {
            *error = [SCAudioVideoRecorder createError:@"The camera session must be opened before trying to record"];
        }
        return NO;
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

- (BOOL)isSessionOpened {
    return self.session != nil;
}

- (BOOL)isSessionRunning {
    return self.session.isRunning;
}

- (BOOL)isOpeningSession {
    return _openingSession;
}

- (void) setPreviewView:(View *)previewView {
    if (self.previewLayer != nil) {
        [self.previewLayer removeFromSuperlayer];
    }
    
    _previewView = previewView;
    
    if (previewView != nil && self.previewLayer != nil) {
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

- (NSString*) sessionPreset {
	return _sessionPreset;
}

- (void) setSessionPreset:(NSString *)sessionPreset {
	if (_sessionPreset != sessionPreset) {
		_sessionPreset = [sessionPreset copy];
		
		if (self.session != nil) {
            [self beginSessionConfiguration];
            
			self.session.sessionPreset = _sessionPreset;
            
            [self commitSessionConfiguration];
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
		
		if (_flashMode == SCFlashModeLight) {
			if ([_currentDevice isTorchModeSupported:AVCaptureTorchModeOn]) {
				[_currentDevice setTorchMode:AVCaptureTorchModeOn];
			}
			if ([_currentDevice isFlashModeSupported:AVCaptureFlashModeOff]) {
				[_currentDevice setFlashMode:AVCaptureFlashModeOff];
			}
		} else {
			if ([_currentDevice isTorchModeSupported:AVCaptureTorchModeOff]) {
				[_currentDevice setTorchMode:AVCaptureTorchModeOff];
			}
			if ([_currentDevice isFlashModeSupported:(AVCaptureFlashMode)_flashMode]) {
				[_currentDevice setFlashMode:(AVCaptureFlashMode)_flashMode];
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

- (void)_willCapturePhoto
{
    id<SCCameraDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(cameraWillCapturePhoto:)])
        [delegate cameraWillCapturePhoto:self];
}

- (void)_didCapturePhoto
{
    id<SCCameraDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(cameraDidCapturePhoto:)])
        [delegate cameraDidCapturePhoto:self];
}

- (void) switchCamera {
    switch (self.cameraDevice) {
        case SCCameraDeviceBack:
            self.cameraDevice = SCCameraDeviceFront;
            break;
        case SCCameraDeviceFront:
            self.cameraDevice = SCCameraDeviceBack;
            break;
        default:
            break;
    }
    
}

- (void)beginSessionConfiguration {
    _configurationBeganCount++;
    
    if (_configurationBeganCount == 1) {
        [self.session beginConfiguration];
    }
}

- (void)commitSessionConfiguration {
    _configurationBeganCount--;
    
    if (_configurationBeganCount == 0) {
        [self.session commitConfiguration];
    }
}

- (void)setCameraDevice:(SCCameraDevice)cameraDevice {
    if (_cameraDevice == cameraDevice)
        return;
    
    _cameraDevice = cameraDevice;
    [self reconfigureSessionInputs];
}

- (SCCameraDevice)cameraDevice {
    return _cameraDevice;
}

- (BOOL)isFrameRateSupported:(CMTimeScale)frameRate {
    AVCaptureDevice * device = self.currentVideoDeviceInput.device;
    
    if (device != nil) {
        for (AVCaptureDeviceFormat * format in device.formats) {
            for (AVFrameRateRange * frameRateRange in format.videoSupportedFrameRateRanges) {
                if (((CMTimeScale)frameRateRange.minFrameRate <= frameRate) && (frameRate <= (CMTimeScale)frameRateRange.maxFrameRate)) {
                    return YES;
                }
            }
        }        
    }
    
    return NO;
}

- (void)setFrameRate:(CMTimeScale)framePerSeconds {
    CMTime fps = CMTimeMake(1, framePerSeconds);
    
    AVCaptureDevice * device = self.currentVideoDeviceInput.device;
    
    if (device != nil) {
        NSError * error = nil;
        BOOL formatSupported = NO;
        for (AVFrameRateRange * frameRateRange in device.activeFormat.videoSupportedFrameRateRanges) {
            if (((NSInteger)frameRateRange.minFrameRate <= framePerSeconds) && (framePerSeconds <= (NSInteger)frameRateRange.maxFrameRate)) {
                formatSupported = YES;
                break;
            }
        }
        
        if (formatSupported) {
            if ([device respondsToSelector:@selector(activeVideoMinFrameDuration)]) {
                if ([device lockForConfiguration:&error]) {
                    device.activeVideoMaxFrameDuration = fps;
                    device.activeVideoMinFrameDuration = fps;
                    [device unlockForConfiguration];
                } else {
                    NSLog(@"Failed to set FramePerSeconds into camera device: %@", error.description);
                }
            } else {
                AVCaptureConnection * connection = [self getVideoConnection];
                if (connection.isVideoMaxFrameDurationSupported) {
                    connection.videoMaxFrameDuration = fps;
                } else {
                    NSLog(@"Failed to set FrameRate into camera device");
                }
                if (connection.isVideoMinFrameDurationSupported) {
                    connection.videoMinFrameDuration = fps;
                } else {
                    NSLog(@"Failed to set FrameRate into camera device");
                }

            }
        } else {
            NSLog(@"Unsupported frame rate %ld on current device format.", (long)framePerSeconds);
        }
    }
}

- (CMTimeScale)frameRate {
    AVCaptureDeviceInput * deviceInput = self.currentVideoDeviceInput;
    
    CMTimeScale framerate = 0;
    
    if (deviceInput != nil) {
        if ([deviceInput.device respondsToSelector:@selector(activeVideoMaxFrameDuration)]) {
            framerate = deviceInput.device.activeVideoMaxFrameDuration.timescale;
        } else {
            AVCaptureConnection * videoConnection = [self getVideoConnection];
            framerate = videoConnection.videoMaxFrameDuration.timescale;
        }
    }
    
    return framerate;
}

- (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate dimensions:(CMVideoDimensions)dimensions {
    CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
    
    if (size.width >= dimensions.width && size.height >= dimensions.height) {
        for (AVFrameRateRange * range in format.videoSupportedFrameRateRanges) {
            if ((CMTimeScale)range.minFrameRate <= frameRate && (CMTimeScale)range.maxFrameRate >= frameRate) {
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL)setActiveFormatThatSupportsFrameRate:(CMTimeScale)frameRate width:(int)width andHeight:(int)height error:(NSError *__autoreleasing *)error {
    AVCaptureDevice * device = self.currentDevice;
    CMVideoDimensions dimensions;
    dimensions.width = width;
    dimensions.height = height;
    
    BOOL foundSupported = NO;
    
    if (device != nil) {
        if (device.activeFormat != nil) {
            foundSupported = [self formatInRange:device.activeFormat frameRate:frameRate dimensions:dimensions];
        }
        
        if (!foundSupported) {
            for (AVCaptureDeviceFormat * format in device.formats) {
                if ([self formatInRange:format frameRate:frameRate dimensions:dimensions]) {
                    CMTimeScale oldFrameRate = self.frameRate;
                    if ([device lockForConfiguration:error]) {
                        device.activeFormat = format;
                        [device unlockForConfiguration];
                        foundSupported = YES;
                        self.frameRate = oldFrameRate;
                        break;
                    }
                }
            }
            
            if (!foundSupported && error != nil) {
                *error = [SCAudioVideoRecorder createError:[NSString stringWithFormat:@"No format that supports framerate %d and dimensions %d/%d was found", (int)frameRate, dimensions.width, dimensions.height]];
            }
        }
    } else {
        if (error != nil) {
            *error = [SCAudioVideoRecorder createError:@"The camera must be initialized before setting active format"];
        }
    }
    
    if (foundSupported && error != nil) {
        *error = nil;
    }
    
    return foundSupported;
}

- (BOOL) initializeCamera:(AVCaptureSession *)captureSession error:(NSError**)error {
    AVCaptureDeviceInput *currentVideoDeviceInput = self.currentVideoDeviceInput;
	if (currentVideoDeviceInput != nil) {
        [currentVideoDeviceInput.device removeObserver:self forKeyPath:@"adjustingFocus"];
        [self removeObserver:self forKeyPath:@"currentVideoDeviceInput.device.focusMode"];
		[captureSession removeInput:currentVideoDeviceInput];
		self.currentVideoDeviceInput = nil;
	}
	
	AVCaptureDevice * device = [self videoDeviceWithPosition:(AVCaptureDevicePosition)self.cameraDevice];
	
    BOOL success;
	if (device != nil) {
        currentVideoDeviceInput = [self addInputToSession:captureSession device:device withMediaType:@"Video" error:error];
		self.currentVideoDeviceInput = currentVideoDeviceInput;
        [currentVideoDeviceInput.device addObserver:self forKeyPath:@"adjustingFocus" options:NSKeyValueObservingOptionNew context:(__bridge void *)SCCameraFocusObserverContext];
        [self addObserver:self forKeyPath:@"currentVideoDeviceInput.device.focusMode" options:NSKeyValueObservingOptionNew context:SCCameraFocusModeObserverContext];
        id<SCCameraDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(cameraUpdateFocusMode:)]) {
            AVCaptureFocusMode initialFocusMode = [device focusMode];
            [delegate cameraUpdateFocusMode:[NSString stringWithFormat:@"focus: %@", [self stringForFocusMode:initialFocusMode]]];
        }
        success = currentVideoDeviceInput != nil;
	} else {
		if (error != nil) {
			*error = [SCAudioVideoRecorder createError:(self.cameraDevice ? @"Front camera not found" : @"Back camera not found")];
		}
        success = NO;
	}
    
    if ([captureSession canSetSessionPreset:self.sessionPreset]) {
        [captureSession setSessionPreset:self.sessionPreset];
    }
    return  success;
}

- (void) reconfigureSessionInputs {
    if (self.session != nil) {
        [self beginSessionConfiguration];
		
		NSError * error;
		[self initializeCamera:self.session error:&error];
		
		self.videoOrientation = self.cachedVideoOrientation;
        
        [self commitSessionConfiguration];
	}
}

- (void)addObserverForSession:(AVCaptureSession*)theSession {
    // add notification observers
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    
    // session notifications
    [notificationCenter addObserver:self selector:@selector(_sessionRuntimeErrored:) name:AVCaptureSessionRuntimeErrorNotification object:theSession];
    [notificationCenter addObserver:self selector:@selector(_sessionStarted:) name:AVCaptureSessionDidStartRunningNotification object:theSession];
    [notificationCenter addObserver:self selector:@selector(_sessionStopped:) name:AVCaptureSessionDidStopRunningNotification object:theSession];
    [notificationCenter addObserver:self selector:@selector(_sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:theSession];
    [notificationCenter addObserver:self selector:@selector(_sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:theSession];
    
    // capture input notifications
    [notificationCenter addObserver:self selector:@selector(_inputPortFormatDescriptionDidChange:) name:AVCaptureInputPortFormatDescriptionDidChangeNotification object:nil];
    
    // capture device notifications
    [notificationCenter addObserver:self selector:@selector(_deviceSubjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:nil];
    
    // Applicaton
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
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
    
    // capture input notifications
    [notificationCenter removeObserver:self name:AVCaptureInputPortFormatDescriptionDidChangeNotification object:nil];
    
    // capture device notifications
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:nil];
    
    // Applicaton
    [notificationCenter removeObserver:self];
    
    // focus
    AVCaptureDeviceInput *currentVideoDeviceInput = self.currentVideoDeviceInput;
    if (currentVideoDeviceInput) {
        [currentVideoDeviceInput.device removeObserver:self forKeyPath:@"adjustingFocus"];
		// focusMode
		[self removeObserver:self forKeyPath:@"currentVideoDeviceInput.device.focusMode"];
        self.currentVideoDeviceInput = nil;
	}
    
    // capturingStillImage
    if (self.stillImageOutput) {
        [self.stillImageOutput removeObserver:self forKeyPath:@"capturingStillImage" context:(__bridge void *)(SCCameraCaptureStillImageIsCapturingStillImageObserverContext)];
    }
}


#pragma mark - App NSNotifications

// TODO: support suspend/resume video recording

- (void)_applicationWillEnterForeground:(NSNotification *)notification
{

}

- (void)_applicationDidEnterBackground:(NSNotification *)notification
{
    if (self.isRecording) {
        [self pause];
    }
}

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
            id<SCCameraDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(cameraSessionDidStart:)]) {
                [delegate cameraSessionDidStart:self];
            }
        }
    }];
}

- (void)_sessionStopped:(NSNotification *)notification
{
    
    [self dispatchBlockOnAskedQueue:^{
        if ([notification object] == session) {
            id<SCCameraDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(cameraSessionDidStop:)]) {
                [delegate cameraSessionDidStop:self];
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

// capture input

- (void)_inputPortFormatDescriptionDidChange:(NSNotification *)notification
{
    // when the input format changes, store the clean aperture
    // (clean aperture is the rect that represents the valid image data for this display)
    AVCaptureInputPort *inputPort = (AVCaptureInputPort *)[notification object];
    if (inputPort) {
        CMFormatDescriptionRef formatDescription = [inputPort formatDescription];
        if (formatDescription) {
            _cleanAperture = CMVideoFormatDescriptionGetCleanAperture(formatDescription, YES);
            id<SCCameraDelegate> delegate = self.delegate;
            if ([delegate respondsToSelector:@selector(camera:cleanApertureDidChange:)]) {
                [delegate camera:self cleanApertureDidChange:_cleanAperture];
            }
        }
    }
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
        id<SCCameraDelegate> delegate = self.delegate;
        if ([device lockForConfiguration:&error]) {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device unlockForConfiguration];

            if ([delegate respondsToSelector:@selector(cameraWillStartFocus:)]) {
                [delegate cameraWillStartFocus:self];
            }

        } else {
            if ([delegate respondsToSelector:@selector(camera:didFailFocus:)]) {
                [delegate camera:self didFailFocus:error];
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
            id<SCCameraDelegate> delegate = self.delegate;
			if ([delegate respondsToSelector:@selector(camera:didFailFocus:)]) {
                [delegate camera:self didFailFocus:error];
			}
		}
	}
}

- (void)_focusStarted
{
    id<SCCameraDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(cameraDidStartFocus:)])
        [delegate cameraDidStartFocus:self];
}

- (void)_focusEnded
{
    id<SCCameraDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(cameraDidStopFocus:)])
        [delegate cameraDidStopFocus:self];
}

- (void)_focus
{
    AVCaptureDevice *device = [self.currentVideoDeviceInput device];
    if ([device isAdjustingFocus] || [device isAdjustingExposure])
        return;

    CGPoint focusPoint = CGPointMake(0.5f, 0.5f);
    [self autoFocusAtPoint:focusPoint];
}

// FocusMode
- (NSString *)stringForFocusMode:(AVCaptureFocusMode)focusMode
{
	NSString *focusString = @"";
	
	switch (focusMode) {
		case AVCaptureFocusModeLocked:
			focusString = @"locked";
			break;
		case AVCaptureFocusModeAutoFocus:
			focusString = @"auto";
			break;
		case AVCaptureFocusModeContinuousAutoFocus:
			focusString = @"continuous";
			break;
	}
	
	return focusString;
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
        
	} else if (context == SCCameraFocusModeObserverContext) {
        // Update the focus UI overlay string when the focus mode changes
        id<SCCameraDelegate> delegate = self.delegate;
        if ([delegate respondsToSelector:@selector(cameraUpdateFocusMode:)]) {
            [delegate cameraUpdateFocusMode:[NSString stringWithFormat:@"focus: %@", [self stringForFocusMode:(AVCaptureFocusMode)[[change objectForKey:NSKeyValueChangeNewKey] integerValue]]]];
        }
	}
}

- (AVCaptureDevice*) currentDevice {
    return self.currentVideoDeviceInput.device;
}

- (SCCameraFocusMode)focusMode
{
    return (SCCameraFocusMode)self.currentDevice.focusMode;
}

@end
