//
//  SCFilterSelectorView.m
//  SCRecorder
//
//  Created by Simon CORSIN on 16/09/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "CIImageRendererUtils.h"
#import "SCFilterSelectorViewInternal.h"
#import "SCContext.h"

@implementation SCFilterSelectorView

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
    _preferredCIImageTransform = CGAffineTransformIdentity;
    _glkView = [[GLKView alloc] initWithFrame:self.bounds context:nil];
    _glkView.backgroundColor = [UIColor clearColor];
    
    _glkView.delegate = self;
    
    _sampleBufferHolder = [SCSampleBufferHolder new];
    
    [self addSubview:_glkView];
}

- (void)_loadContext {
    if (_CIContext == nil) {
        SCContext *context = [SCContext context];
        _CIContext = context.CIContext;
        _glkView.context = context.EAGLContext;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _glkView.frame = self.bounds;
}

- (void)setNeedsDisplay {
    [super setNeedsDisplay];
    [_glkView setNeedsDisplay];
}

- (void)refresh {
    [_glkView setNeedsDisplay];
}

- (void)render:(CIImage *)image toContext:(CIContext *)context inRect:(CGRect)rect {
    CGRect extent = [image extent];
    
    if (_selectedFilter != nil) {
        image = [_selectedFilter imageByProcessingImage:image atTime:_CIImageTime];
    }
    
    CGRect outputRect = [CIImageRendererUtils processRect:rect withImageSize:extent.size contentScale:self.contentScaleFactor contentMode:self.contentMode];
    
    [_CIContext drawImage:image inRect:outputRect fromRect:extent];
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    CIImage *newImage = [CIImageRendererUtils generateImageFromSampleBufferHolder:_sampleBufferHolder];
    
    if (newImage != nil) {
        _CIImage = newImage;
    }
    
    CIImage *outputImage = _CIImage;
    
    if (outputImage != nil) {
        outputImage = [outputImage imageByApplyingTransform:self.preferredCIImageTransform];
        
        if (self.preprocessingFilter != nil) {
            outputImage = [self.preprocessingFilter imageByProcessingImage:outputImage atTime:self.CIImageTime];
        }
        
        rect = [CIImageRendererUtils processRect:rect withImageSize:outputImage.extent.size contentScale:_glkView.contentScaleFactor contentMode:self.contentMode];
        
        [self render:outputImage toContext:_CIContext inRect:rect];
    }
}

- (void)setImageBySampleBuffer:(CMSampleBufferRef)sampleBuffer {
    _sampleBufferHolder.sampleBuffer = sampleBuffer;
    
    [_glkView setNeedsDisplay];
}

- (void)setSelectedFilter:(SCFilter *)selectedFilter {
    if (_selectedFilter != selectedFilter) {
        [self willChangeValueForKey:@"selectedFilter"]
        ;
        _selectedFilter = selectedFilter;
        
        [self didChangeValueForKey:@"selectedFilter"];
        
        [self setNeedsLayout];
    }
}

- (UIImage *)currentlyDisplayedImageWithScale:(CGFloat)scale orientation:(UIImageOrientation)imageOrientation {
    CIImage *inputImage = self.CIImage;
    
    CIImage *processedImage = [self.selectedFilter imageByProcessingImage:inputImage atTime:_CIImageTime];
    
    if (processedImage == nil) {
        processedImage = inputImage;
    }
    
    if (processedImage == nil) {
        return nil;
    }
    
    CGImageRef outputImage = [_CIContext createCGImage:processedImage fromRect:inputImage.extent];
    
    UIImage *image = [UIImage imageWithCGImage:outputImage scale:scale orientation:imageOrientation];
    
    CGImageRelease(outputImage);
    
    return image;
}

- (void)setCIImage:(CIImage *)CIImage {
    _CIImage = CIImage;
    
    if (CIImage != nil) {
        [self _loadContext];
    }
    [_glkView setNeedsDisplay];
}

- (void)setImageByUIImage:(UIImage *)image {
    [CIImageRendererUtils putUIImage:image toRenderer:self];
}

@end
