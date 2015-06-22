//
//  SCCIImageView.m
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCImageView.h"
#import "CIImageRendererUtils.h"
#import "SCSampleBufferHolder.h"
#import "SCContext.h"

@interface SCImageView() {
    CIContext *_CIContext;
    SCSampleBufferHolder *_sampleBufferHolder;
}

@end

@implementation SCImageView

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (void)commonInit {
    self.preferredCIImageTransform = CGAffineTransformIdentity;
    
    _sampleBufferHolder = [SCSampleBufferHolder new];
}

- (void)_loadContext {
    if (_CIContext == nil) {
        SCContext *context = [SCContext context];
        _CIContext = context.CIContext;
        self.context = context.EAGLContext;
    }
}

- (void)drawRect:(CGRect)rect {
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    CIImage *newImage = [CIImageRendererUtils generateImageFromSampleBufferHolder:_sampleBufferHolder];
    
    if (newImage != nil) {
        _CIImage = newImage;
    }
    
    CIImage *image = [self processedCIImage];
    
    if (image != nil) {
        CGRect extent = [image extent];
        
        CGRect outputRect = [CIImageRendererUtils processRect:self.bounds withImageSize:extent.size contentScale:self.contentScaleFactor contentMode:self.contentMode];
        
        [_CIContext drawImage:image inRect:outputRect fromRect:extent];
    }
}

- (CIImage *)processedCIImage {
    CIImage *image = _CIImage;
    
    if (image != nil) {
        image = [image imageByApplyingTransform:self.preferredCIImageTransform];
        
        if (_filter != nil) {
            image = [_filter imageByProcessingImage:image atTime:_CIImageTime];
        }
        
        return image;
    }
    
    return image;
}

- (UIImage *)processedUIImage {
    CIImage *image = [self processedCIImage];
    
    if (image != nil) {
        CGImageRef CGImage = [_CIContext createCGImage:image fromRect:[image extent]];
        
        UIImage *uiImage = [UIImage imageWithCGImage:CGImage scale:self.contentScaleFactor orientation:UIImageOrientationUp];
        
        CGImageRelease(CGImage);
        
        return uiImage;
    } else {
        return nil;
    }
}

- (void)setImageBySampleBuffer:(CMSampleBufferRef)sampleBuffer {
    _sampleBufferHolder.sampleBuffer = sampleBuffer;
    
    [self setNeedsDisplay];
}

- (void)setImageByUIImage:(UIImage *)image {
    [CIImageRendererUtils putUIImage:image toRenderer:self];
}

- (void)setCIImage:(CIImage *)CIImage {
    _CIImage = CIImage;
    
    if (CIImage != nil) {
        [self _loadContext];
    }
    
    [self setNeedsDisplay];
}

- (void)setFilter:(SCFilter *)filter {
    _filter = filter;
    
    [self setNeedsDisplay];
}

@end
