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

- (CGRect)rectByApplyingContentScale:(CGRect)rect {
    CGFloat scale = self.contentScaleFactor;
    rect.origin.x *= scale;
    rect.origin.y *= scale;
    rect.size.width *= scale;
    rect.size.height *= scale;
    
    return rect;
}

- (void)makeDirty {
    _dirty = YES;
}

- (void)setNeedsDisplay {
    _dirty = NO;
    
    [super setNeedsDisplay];
}

- (void)setImage:(CIImage *)image {
    _image = image;
    
    [self makeDirty];
}

- (CIContext *)ciContext {
    return _ciContext;
}

@end
