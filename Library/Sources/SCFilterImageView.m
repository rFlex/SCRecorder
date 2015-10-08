//
//  SCFilterImageView.m
//  SCRecorder
//
//  Created by Simon Corsin on 10/8/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import "SCFilterImageView.h"

@implementation SCFilterImageView

- (CIImage *)processImage:(CIImage *)image {
    image = [image imageByApplyingTransform:self.preferredCIImageTransform];

    if (_filter != nil) {
        image = [_filter imageByProcessingImage:image atTime:self.CIImageTime];
    }

    return image;
}

- (CIImage *)processedCIImage {
    CIImage *image = self.CIImage;

    if (image != nil) {
        image = [self processImage:image];
    }

    return image;
}

- (UIImage *)processedUIImage {
    CIImage *image = [self processedCIImage];

    if (image != nil) {
        if (![self loadContextIfNeeded]) {
            return nil;
        }

        CGImageRef CGImage = [self.context.CIContext createCGImage:image fromRect:[image extent]];

        UIImage *uiImage = [UIImage imageWithCGImage:CGImage scale:self.contentScaleFactor orientation:UIImageOrientationUp];

        CGImageRelease(CGImage);

        return uiImage;
    } else {
        return nil;
    }
}

- (void)drawCIImage:(CIImage *)image inRect:(CGRect)rect andCIContext:(CIContext *)CIContext MTLTexture:(id<MTLTexture>)texture {
    CIImage *processedImage = [self processImage:image];

    [super drawCIImage:processedImage inRect:rect andCIContext:CIContext MTLTexture:texture];
}

- (void)setFilter:(SCFilter *)filter {
    _filter = filter;

    [self setNeedsDisplay];
}

@end
