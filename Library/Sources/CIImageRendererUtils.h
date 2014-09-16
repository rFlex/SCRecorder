//
//  CIImageRendererUtils.h
//  SCRecorder
//
//  Created by Simon CORSIN on 13/09/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "SCSampleBufferHolder.h"

@interface CIImageRendererUtils : NSObject

+ (CGRect)processRect:(CGRect)rect withImageSize:(CGSize)imageSize contentScale:(CGFloat)contentScale contentMode:(UIViewContentMode)mode;

+ (CIImage *)generateImageFromSampleBufferHolder:(SCSampleBufferHolder *)sampleBufferHolder;

+ (CGAffineTransform)preferredCIImageTransformFromUIImage:(UIImage *)image;

@end
