//
//  CIImageRendererUtils.m
//  SCRecorder
//
//  Created by Simon CORSIN on 13/09/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "CIImageRendererUtils.h"

@implementation CIImageRendererUtils

+ (CGRect)processRect:(CGRect)rect withImageSize:(CGSize)imageSize contentScale:(CGFloat)contentScale contentMode:(UIViewContentMode)mode {
    rect = [CIImageRendererUtils rect:rect byApplyingContentScale:contentScale];
    
    if (mode != UIViewContentModeScaleToFill) {
        CGFloat horizontalScale = rect.size.width / imageSize.width;
        CGFloat verticalScale = rect.size.height / imageSize.height;
        
        BOOL shouldResizeWidth = mode == UIViewContentModeScaleAspectFit ? horizontalScale > verticalScale : verticalScale > horizontalScale;
        BOOL shouldResizeHeight = mode == UIViewContentModeScaleAspectFit ? verticalScale > horizontalScale : horizontalScale > verticalScale;
        
        if (shouldResizeWidth) {
            CGFloat newWidth = imageSize.width * verticalScale;
            rect.origin.x = (rect.size.width / 2 - newWidth / 2);
            rect.size.width = newWidth;
        } else if (shouldResizeHeight) {
            CGFloat newHeight = imageSize.height * horizontalScale;
            rect.origin.y = (rect.size.height / 2 - newHeight / 2);
            rect.size.height = newHeight;
        }
    }
    
    return rect;
}

+ (CGRect)rect:(CGRect)rect byApplyingContentScale:(CGFloat)scale {
    rect.origin.x *= scale;
    rect.origin.y *= scale;
    rect.size.width *= scale;
    rect.size.height *= scale;
    
    return rect;
}

+ (CIImage *)generateImageFromSampleBufferHolder:(SCSampleBufferHolder *)sampleBufferHolder {
    CIImage *image = nil;
    CMSampleBufferRef sampleBuffer = sampleBufferHolder.sampleBuffer;
    
    if (sampleBuffer != nil) {
        image = [CIImage imageWithCVPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer)];
        sampleBufferHolder.sampleBuffer = nil;
    }
    
    return image;
}

@end
