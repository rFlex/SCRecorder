//
//  SCFilterSelectorView.h
//  SCRecorder
//
//  Created by Simon CORSIN on 16/09/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import "SCFilter.h"
#import "CIImageRenderer.h"

/**
 A base class that supports multiple filters and let the user choose one.
 The default drawing implementation just draws the image fullscreen with the
 current selectedFilterGroup.
 You would typically use the currently only available subclass SCSwipeableFilterView.
 Subclass note: see SCFilterSelectorViewInternal.h
 */
@interface SCFilterSelectorView : UIView<CIImageRenderer, GLKViewDelegate>

/**
 The available filterGroups that this SCFilterSwitcherView shows
 If you want to show an empty filter (no processing), just add a [NSNull null]
 entry instead of an instance of SCFilterGroup
 */
@property (strong, nonatomic) NSArray *filters;

/**
 The CIImage to render.
 */
@property (strong, nonatomic) CIImage *CIImage;

/**
 The currently selected filter group.
 This changes when scrolling in the underlying UIScrollView.
 This value is Key-Value observable.
 */
@property (readonly, nonatomic) SCFilter *selectedFilter;

/**
 The preferred transform for rendering the CIImage
 */
@property (assign, nonatomic) CGAffineTransform preferredCIImageTransform;

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
 Set the CIImage using an UIImage
 */
- (void)setImageByUIImage:(UIImage *)image;

@end
