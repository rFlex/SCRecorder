//
//  SCFilterSwitcherView.h
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 29/05/14.
//
//

#import <UIKit/UIKit.h>
#import "SCPlayer.h"
#import "SCFilterGroup.h"
#import "CIImageRendererUtils.h"

/**
 Display a Snapchat like presentation of the available filters and let the user
 choose one
 */
@interface SCFilterSwitcherView : UIView<UIScrollViewDelegate, CIImageRenderer, GLKViewDelegate>

/**
 The available filterGroups that this SCFilterSwitcherView shows
 If you want to show an empty filter (no processing), just add a [NSNull null]
 entry instead of an instance of SCFilterGroup
 */
@property (strong, nonatomic) NSArray *filterGroups;

/**
 The CIImage to render.
 */
@property (strong, nonatomic) CIImage *CIImage;

/**
 The currently selected filter group.
 This changes when scrolling in the underlying UIScrollView.
 This value is Key-Value observable.
 */
@property (readonly, nonatomic) SCFilterGroup *selectedFilterGroup;

/**
 The underlying scrollView used for scrolling between filterGroups.
 You can freely add your views inside.
 */
@property (readonly, nonatomic) UIScrollView *selectFilterScrollView;

/**
 Generates an UIImage from the currently displayed CIImage. The current selected
 filterGroup will be applied to this image if applicable.
 */
- (UIImage *)currentlyDisplayedImageWithScale:(CGFloat)scale orientation:(UIImageOrientation)orientation;

/**
 Set the CIImage using a sampleBuffer. The CIImage will be automatically generated
 when needed. This avoids creating multiple CIImage if the SCImageView can't render them
 as fast.
 */
- (void)setImageBySampleBuffer:(CMSampleBufferRef)sampleBuffer;

/**
 The preferred transform for rendering the CIImage
 */
@property (assign, nonatomic) CGAffineTransform preferredCIImageTransform;

@property (strong, nonatomic) CIImage *image DEPRECATED_MSG_ATTRIBUTE("Replaced by the CIImage property");

@end
