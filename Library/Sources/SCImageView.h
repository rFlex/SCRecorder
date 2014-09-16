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
#import "SCFilterGroup.h"
#import "CIImageRenderer.h"

/**
 A Core Image renderer that works like a UIView. It supports filter through the
 filterGroup property.
 */
@interface SCImageView : GLKView<CIImageRenderer>

/**
 The filterGroup to apply when rendering. If nil is set, no filter will be applied
 */
@property (strong, nonatomic) SCFilterGroup *filterGroup;

/**
 The CIImage to render.
 */
@property (strong, nonatomic) CIImage *CIImage;

/**
 Set the CIImage using a sampleBuffer. The CIImage will be automatically generated
 when needed. This avoids creating multiple CIImage if the SCImageView can't render them
 as fast.
 */
- (void)setImageBySampleBuffer:(CMSampleBufferRef)sampleBuffer;

@property (strong, nonatomic) CIImage *image DEPRECATED_MSG_ATTRIBUTE("Replaced by the CIImage property");

@end
