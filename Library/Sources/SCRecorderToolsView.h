//
//  SCRecorderToolsView.h
//  SCRecorder
//
//  Created by Simon CORSIN on 16/02/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCRecorder.h"

@class SCRecorder;

@interface SCRecorderToolsView : UIView

/**
 The instance of the SCRecorder to use.
 */
@property (strong, nonatomic) SCRecorder *recorder;

/**
 The outside image used when focusing.
 */
@property (strong, nonatomic) UIImage *outsideFocusTargetImage;

/**
 The inside image used when focusing.
 */
@property (strong, nonatomic) UIImage *insideFocusTargetImage;

/**
 The size of the focus target.
 */
@property (assign, nonatomic) CGSize focusTargetSize;

/**
 The minimum zoom allowed for the pinch to zoom.
 Default is 1
 */
@property (assign, nonatomic) CGFloat minZoomFactor;

/**
 The maximum zoom allowed for the pinch to zoom.
 Default is 4
 */
@property (assign, nonatomic) CGFloat maxZoomFactor;


/**
 Whether the tap to focus should be enabled.
 */
@property (assign, nonatomic) BOOL tapToFocusEnabled;

/**
 Whether the double tap to reset the focus should be enabled.
 */
@property (assign, nonatomic) BOOL doubleTapToResetFocusEnabled;

/**
 Whether the pinch to zoom should be enabled.
 */
@property (assign, nonatomic) BOOL pinchToZoomEnabled;

/**
 Whether the SCRecorderToolsView should show the focus animation automatically
 when the focusing state changes. If set to NO, you will have to call
 "showFocusAnimation" and "hideFocusAnimation" yourself.
 */
@property (assign, nonatomic) BOOL showsFocusAnimationAutomatically;

/**
 Manually show the focus animation.
 This method is called automatically if showsFocusAnimationAutomatically
 is set to YES.
 */
- (void)showFocusAnimation;

/**
 Manually hide the focus animation.
 This method is called automatically if showsFocusAnimationAutomatically
 is set to YES.
 */
- (void)hideFocusAnimation;

@end
