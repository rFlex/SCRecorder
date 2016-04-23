//
//  SCRecorderToolsView.m
//  SCRecorder
//
//  Created by Simon CORSIN on 16/02/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import "SCRecorderToolsView.h"
#import "SCRecorderFocusTargetView.h"

#define BASE_FOCUS_TARGET_WIDTH 60
#define BASE_FOCUS_TARGET_HEIGHT 60
#define kDefaultMinZoomFactor 1
#define kDefaultMaxZoomFactor 4

@interface SCRecorderToolsView()
{
    UITapGestureRecognizer *_tapToFocusGesture;
    UITapGestureRecognizer *_doubleTapToResetFocusGesture;
    UIPinchGestureRecognizer *_pinchZoomGesture;
    CGFloat _zoomAtStart;
}

@property (strong, nonatomic) SCRecorderFocusTargetView *cameraFocusTargetView;

@end

@implementation SCRecorderToolsView

static char *ContextAdjustingFocus = "AdjustingFocus";
static char *ContextAdjustingExposure = "AdjustingExposure";
static char *ContextDidChangeDevice = "DidChangeDevice";

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (void)dealloc {
    self.recorder = nil;
}

- (void)commonInit {
    _minZoomFactor = kDefaultMinZoomFactor;
    _maxZoomFactor = kDefaultMaxZoomFactor;
    self.showsFocusAnimationAutomatically = YES;
    self.cameraFocusTargetView = [[SCRecorderFocusTargetView alloc] init];
    self.cameraFocusTargetView.hidden = YES;
    [self addSubview:self.cameraFocusTargetView];
    
    self.focusTargetSize = CGSizeMake(BASE_FOCUS_TARGET_WIDTH, BASE_FOCUS_TARGET_HEIGHT);
    
    _tapToFocusGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToAutoFocus:)];
    [self addGestureRecognizer:_tapToFocusGesture];
    
    _doubleTapToResetFocusGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToContinouslyAutoFocus:)];
    _doubleTapToResetFocusGesture.numberOfTapsRequired = 2;
    [_tapToFocusGesture requireGestureRecognizerToFail:_doubleTapToResetFocusGesture];
    
    [self addGestureRecognizer:_doubleTapToResetFocusGesture];
    
    _pinchZoomGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchToZoom:)];
    
    [self addGestureRecognizer:_pinchZoomGesture];
}

- (void)showFocusAnimation {
    [self adjustFocusView];
    self.cameraFocusTargetView.hidden = NO;
    [self.cameraFocusTargetView startTargeting];
}

- (void)hideFocusAnimation {
    [self.cameraFocusTargetView stopTargeting];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    [self adjustFocusView];
}

- (void)adjustFocusView {
    CGPoint currentFocusPoint = CGPointMake(0.5, 0.5);
    
    if (self.recorder.focusSupported) {
        currentFocusPoint = self.recorder.focusPointOfInterest;
    } else if (self.recorder.exposureSupported) {
        currentFocusPoint = self.recorder.exposurePointOfInterest;
    }
    
    CGPoint viewPoint = [self.recorder convertPointOfInterestToViewCoordinates:currentFocusPoint];
    viewPoint = [self convertPoint:viewPoint fromView:self.recorder.previewView];
    self.cameraFocusTargetView.center = viewPoint;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == ContextAdjustingFocus) {
        if (self.showsFocusAnimationAutomatically) {
            if (self.recorder.isAdjustingFocus) {
                [self showFocusAnimation];
            } else {
                [self hideFocusAnimation];
            }
        }
    } else if (context == ContextAdjustingExposure) {
        if (self.showsFocusAnimationAutomatically && !self.recorder.focusSupported) {
            if (self.recorder.isAdjustingExposure) {
                [self showFocusAnimation];
            } else {
                [self hideFocusAnimation];
            }
        }
    } else if (context == ContextDidChangeDevice) {
        [self hideFocusAnimation];
    }
}

// Auto focus at a particular point. The focus mode will change to locked once the auto focus happens.
- (void)tapToAutoFocus:(UIGestureRecognizer *)gestureRecognizer {
    SCRecorder *recorder = self.recorder;
    
    CGPoint tapPoint = [gestureRecognizer locationInView:recorder.previewView];
    CGPoint convertedFocusPoint = [recorder convertToPointOfInterestFromViewCoordinates:tapPoint];
    [recorder autoFocusAtPoint:convertedFocusPoint];
    
    id<SCRecorderToolsViewDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(recorderToolsView:didTapToFocusWithGestureRecognizer:)]) {
        [delegate recorderToolsView:self didTapToFocusWithGestureRecognizer:gestureRecognizer];
    }
}

// Change to continuous auto focus. The camera will constantly focus at the point choosen.
- (void)tapToContinouslyAutoFocus:(UIGestureRecognizer *)gestureRecognizer {
    SCRecorder *recorder = self.recorder;
    if (recorder.focusSupported) {
        self.cameraFocusTargetView.center = self.center;
        [recorder continuousFocusAtPoint:CGPointMake(.5f, .5f)];
    }
}

- (void)pinchToZoom:(UIPinchGestureRecognizer *)gestureRecognizer {
    SCRecorder *strongRecorder = self.recorder;
    
    if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
        _zoomAtStart = strongRecorder.videoZoomFactor;
    }
    
    CGFloat newZoom = gestureRecognizer.scale * _zoomAtStart;
    
    if (newZoom > _maxZoomFactor) {
        newZoom = _maxZoomFactor;
    } else if (newZoom < _minZoomFactor) {
        newZoom = _minZoomFactor;
    }
        
    strongRecorder.videoZoomFactor = newZoom;
}

- (void)setFocusTargetSize:(CGSize)focusTargetSize {
    CGRect rect = self.cameraFocusTargetView.frame;
    rect.size = focusTargetSize;
    self.cameraFocusTargetView.frame = rect;
    [self adjustFocusView];
}

- (CGSize)focusTargetSize {
    return self.cameraFocusTargetView.frame.size;
}

- (UIImage*)outsideFocusTargetImage {
    return self.cameraFocusTargetView.outsideFocusTargetImage;
}

- (void)setOutsideFocusTargetImage:(UIImage *)outsideFocusTargetImage {
    self.cameraFocusTargetView.outsideFocusTargetImage = outsideFocusTargetImage;
}

- (UIImage*)insideFocusTargetImage {
    return self.cameraFocusTargetView.insideFocusTargetImage;
}

- (void)setInsideFocusTargetImage:(UIImage *)insideFocusTargetImage {
    self.cameraFocusTargetView.insideFocusTargetImage = insideFocusTargetImage;
}

- (BOOL)tapToFocusEnabled {
    return _tapToFocusGesture.enabled;
}

- (void)setTapToFocusEnabled:(BOOL)tapToFocusEnabled {
    _tapToFocusGesture.enabled = tapToFocusEnabled;
}

- (BOOL)doubleTapToResetFocusEnabled {
    return _doubleTapToResetFocusGesture.enabled;
}

- (void)setDoubleTapToResetFocusEnabled:(BOOL)doubleTapToResetFocusEnabled {
    _doubleTapToResetFocusGesture.enabled = doubleTapToResetFocusEnabled;
}

- (BOOL)pinchToZoomEnabled {
    return _pinchZoomGesture.enabled;
}

- (void)setPinchToZoomEnabled:(BOOL)pinchToZoomEnabled {
    _pinchZoomGesture.enabled = pinchToZoomEnabled;
}

- (void)setRecorder:(SCRecorder *)recorder {
    SCRecorder *oldRecorder = _recorder;
    
    if (oldRecorder != nil) {
        [oldRecorder removeObserver:self forKeyPath:@"isAdjustingFocus"];
        [oldRecorder removeObserver:self forKeyPath:@"isAdjustingExposure"];
        [oldRecorder removeObserver:self forKeyPath:@"device"];
    }
    
    _recorder = recorder;
    
    if (recorder != nil) {
        [recorder addObserver:self forKeyPath:@"isAdjustingFocus" options:NSKeyValueObservingOptionNew context:ContextAdjustingFocus];
        [recorder addObserver:self forKeyPath:@"isAdjustingExposure" options:NSKeyValueObservingOptionNew context:ContextAdjustingExposure];
        [recorder addObserver:self forKeyPath:@"device"  options:NSKeyValueObservingOptionNew context:ContextDidChangeDevice];
    }
}

@end
