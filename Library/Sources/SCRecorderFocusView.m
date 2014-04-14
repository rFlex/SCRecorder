//
//  SCCameraFocusView.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 19/12/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCRecorderFocusView.h"
#import "SCRecorderFocusTargetView.h"

#define BASE_FOCUS_TARGET_WIDTH 60
#define BASE_FOCUS_TARGET_HEIGHT 60

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface SCRecorderFocusView()
{
    CGPoint _currentFocusPoint;
}

@property (strong, nonatomic) SCRecorderFocusTargetView *cameraFocusTargetView;

@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCRecorderFocusView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (void)commonInit
{
    _currentFocusPoint = CGPointMake(0.5, 0.5);
    self.cameraFocusTargetView = [[SCRecorderFocusTargetView alloc] init];
    self.cameraFocusTargetView.hidden = YES;
    [self addSubview:self.cameraFocusTargetView];
    
    self.focusTargetSize = CGSizeMake(BASE_FOCUS_TARGET_WIDTH, BASE_FOCUS_TARGET_HEIGHT);
    
    // Add a single tap gesture to focus on the point tapped, then lock focus
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToAutoFocus:)];
    [singleTap setNumberOfTapsRequired:1];
    [self addGestureRecognizer:singleTap];

    // Desactivating this as this heavily slow down the focus process
//    // Add a double tap gesture to reset the focus mode to continuous auto focus
//    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToContinouslyAutoFocus:)];
//    [doubleTap setNumberOfTapsRequired:2];
//    [singleTap requireGestureRecognizerToFail:doubleTap];
//    [self addGestureRecognizer:doubleTap];
}

- (void)showFocusAnimation
{
    self.cameraFocusTargetView.hidden = NO;
    [self.cameraFocusTargetView startTargeting];
}

- (void)hideFocusAnimation
{
    [self.cameraFocusTargetView stopTargeting];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    [self adjustFocusView];
}

- (void)adjustFocusView
{
    self.cameraFocusTargetView.center = CGPointMake(self.frame.size.width * _currentFocusPoint.x, self.frame.size.height * _currentFocusPoint.y);
}

// Auto focus at a particular point. The focus mode will change to locked once the auto focus happens.
- (void)tapToAutoFocus:(UIGestureRecognizer *)gestureRecognizer
{
    SCRecorder *recorder = self.recorder;
    if (recorder.focusSupported) {
        CGPoint tapPoint = [gestureRecognizer locationInView:self];
        CGPoint convertedFocusPoint = [recorder convertToPointOfInterestFromViewCoordinates:tapPoint];
        self.cameraFocusTargetView.center = tapPoint;
        [recorder autoFocusAtPoint:convertedFocusPoint];
        _currentFocusPoint = convertedFocusPoint;
    }
}

// Change to continuous auto focus. The camera will constantly focus at the point choosen.
- (void)tapToContinouslyAutoFocus:(UIGestureRecognizer *)gestureRecognizer
{
    SCRecorder *recorder = self.recorder;
    if (recorder.focusSupported) {
        self.cameraFocusTargetView.center = self.center;
        [recorder continuousFocusAtPoint:CGPointMake(.5f, .5f)];
    }
}

- (void)setFocusTargetSize:(CGSize)focusTargetSize
{
    CGRect rect = self.cameraFocusTargetView.frame;
    rect.size = focusTargetSize;
    self.cameraFocusTargetView.frame = rect;
    [self adjustFocusView];
}

- (CGSize)focusTargetSize
{
    return self.cameraFocusTargetView.frame.size;
}

- (UIImage*)outsideFocusTargetImage
{
    return self.cameraFocusTargetView.outsideFocusTargetImage;
}

- (void)setOutsideFocusTargetImage:(UIImage *)outsideFocusTargetImage
{
    self.cameraFocusTargetView.outsideFocusTargetImage = outsideFocusTargetImage;
}

- (UIImage*)insideFocusTargetImage
{
    return self.cameraFocusTargetView.insideFocusTargetImage;
}

- (void)setInsideFocusTargetImage:(UIImage *)insideFocusTargetImage
{
    self.cameraFocusTargetView.insideFocusTargetImage = insideFocusTargetImage;
}

@end
