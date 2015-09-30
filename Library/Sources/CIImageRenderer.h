//
//  SCImageHolder.h
//  SCRecorder
//
//  Created by Simon CORSIN on 13/09/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <AVFoundation/AVFoundation.h>

@protocol CIImageRenderer <NSObject>

/**
 The CIImage to display
 */
@property (strong, nonatomic) CIImage *__nullable CIImage;

/**
 The timestamp of the CIImage
 */
@property (assign, nonatomic) CFTimeInterval CIImageTime;

@optional

/**
 Some objects may use this property to set a buffer instead of always creating
 a CIImage. This avoids creating multiple CIImage if it is not necesarry.
 */
- (void)setImageBySampleBuffer:(__nonnull CMSampleBufferRef)sampleBuffer;

/**
 Some objects may use this property to set a pixel buffer for further processing.
 */
- (void)setImageByPixelBuffer:(__nonnull CVPixelBufferRef)pixelBuffer;

/**
 Set the CIImage using an UIImage
 */
- (void)setImageByUIImage:(UIImage *__nullable)image;

/**
 The preferred transform for rendering the CIImage
 */
@property (assign, nonatomic) CGAffineTransform preferredCIImageTransform;

/**
 Some objects such as the SCPlayer may need to get a frame.
 */
@property (readonly, nonatomic) CGRect frame;

@end
