//
//  SCCIImageView.m
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCImageView.h"
#import "CIImageRendererUtils.h"

@interface SCImageView() {
    CIContext *_CIContext;
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
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    NSDictionary *options = @{ kCIContextWorkingColorSpace : [NSNull null] };
    _CIContext = [CIContext contextWithEAGLContext:context options:options];
    
    self.context = context;
}

- (void)drawRect:(CGRect)rect {
    CIImage *image = _CIImage;
    if (image != nil) {
        CGRect extent = [image extent];
        
        if (_filterGroup != nil) {
            image = [_filterGroup imageByProcessingImage:image];
        }
        CGRect outputRect = [CIImageRendererUtils processRect:rect withImageSize:extent.size contentScale:self.contentScaleFactor contentMode:self.contentMode];
        
        [_CIContext drawImage:image inRect:outputRect fromRect:extent];
    }
}

- (void)setImage:(CIImage *)image {
    self.CIImage = image;
}

- (CIImage *)image {
    return self.CIImage;
}

- (void)setCIImage:(CIImage *)CIImage {
    _CIImage = CIImage;
    
    [self setNeedsDisplay];
}

- (void)setFilterGroup:(SCFilterGroup *)filterGroup {
    _filterGroup = filterGroup;
    
    [self setNeedsDisplay];
}

@end
