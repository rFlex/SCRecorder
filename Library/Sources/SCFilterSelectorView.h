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
@property (strong, nonatomic) NSArray *__nullable filters;

/**
 The CIImage to render.
 */
@property (strong, nonatomic) CIImage *__nullable CIImage;

/**
 The timestamp of the CIImage
 */
@property (assign, nonatomic) CFTimeInterval CIImageTime;

/**
 The currently selected filter group.
 This changes when scrolling in the underlying UIScrollView.
 This value is Key-Value observable.
 */
@property (strong, nonatomic) SCFilter *__nullable selectedFilter;

/**
 The preferred transform for rendering the CIImage
 */
@property (assign, nonatomic) CGAffineTransform preferredCIImageTransform;

/**
 A filter that is applied before applying the selected filter
 */
@property (strong, nonatomic) SCFilter *__nullable preprocessingFilter;

/**
 Set the CIImage using a sampleBuffer. The CIImage will be automatically generated
 when needed. This avoids creating multiple CIImage if the SCImageView can't render them
 as fast.
 */
- (void)setImageBySampleBuffer:(__nonnull CMSampleBufferRef)sampleBuffer;

/**
 Set the CIImage using an UIImage
 */
- (void)setImageByUIImage:(UIImage *__nullable)image;

/**
 Creates and returns the processed image as UIImage
 */
- (UIImage *__nullable)processedUIImage;

/**
 Creates and returns the processed image as CIImage
 */
- (CIImage *__nullable)processedCIImage;

@end
