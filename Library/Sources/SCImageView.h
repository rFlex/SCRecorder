//
//  SCCIImageView.h
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <GLKit/GLKit.h>
#import "SCFilter.h"
#import "CIImageRenderer.h"

/**
 A Core Image renderer that works like a UIView. It supports filter through the
 filterGroup property.
 */
@interface SCImageView : GLKView<CIImageRenderer>

/**
 The filter to apply when rendering. If nil is set, no filter will be applied
 */
@property (strong, nonatomic) SCFilter *__nullable filter;

/**
 The CIImage to render.
 */
@property (strong, nonatomic) CIImage *__nullable CIImage;

/**
 The timestamp of the CIImage
 */
@property (assign, nonatomic) CFTimeInterval CIImageTime;

/**
 The preferred transform for rendering the CIImage
 */
@property (assign, nonatomic) CGAffineTransform preferredCIImageTransform;

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
