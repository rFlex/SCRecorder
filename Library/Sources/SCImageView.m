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
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    self = [super initWithFrame:frame context:context];
    
    if (self) {
        NSDictionary *options = @{ kCIContextWorkingColorSpace : [NSNull null] };
        _ciContext = [CIContext contextWithEAGLContext:context options:options];
    }
    
    return self;
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
        CGFloat contentScale = self.contentScaleFactor;
        CGRect extent = self.imageSize;
        
        rect = CGRectMultiply(rect, contentScale);
        
        [_ciContext drawImage:_image inRect:rect fromRect:extent];
    }
}

- (void)setImage:(CIImage *)image {
    _image = image;
    
    [self setNeedsDisplay];
}

@end
