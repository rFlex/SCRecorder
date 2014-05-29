//
//  SCCIImageView.m
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCImageView.h"

@interface SCImageView() {
    EAGLContext *_eaglContext;
    CIContext *_ciContext;
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
    _ciContext = [CIContext contextWithEAGLContext:context options:options];
    
    self.context = context;
}

CGRect CGRectMultiply(CGRect rect, CGFloat scale) {
    rect.origin.x *= scale;
    rect.origin.y *= scale;
    rect.size.width *= scale;
    rect.size.height *= scale;
    
    return rect;
}

- (void)drawRect:(CGRect)rect {
    if (_image != nil) {
        CIImage *outputImage = _image;
        CGFloat contentScale = self.contentScaleFactor;
        CGRect extent = self.imageSize;
        
        rect = CGRectMultiply(rect, contentScale);
        
        [_ciContext drawImage:outputImage inRect:rect fromRect:extent];
    }
}

- (void)setImage:(CIImage *)image {
    _image = image;
    
    [self setNeedsDisplay];
}

- (CIContext *)ciContext {
    return _ciContext;
}

@end
