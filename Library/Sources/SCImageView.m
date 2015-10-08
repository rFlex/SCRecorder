//
//  SCCIImageView.m
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <MetalKit/MetalKit.h>
#import "SCImageView.h"
#import "CIImageRendererUtils.h"
#import "SCSampleBufferHolder.h"
#import "SCContext.h"

@interface SCImageView()<GLKViewDelegate, MTKViewDelegate> {
    SCSampleBufferHolder *_sampleBufferHolder;
}

@property (nonatomic, strong) GLKView *GLKView;
@property (nonatomic, strong) MTKView *MTKView;

@end

@implementation SCImageView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self commonInit];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
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

- (SCImageViewContextType)suggestedContextType {
    SCImageViewContextType contextType = _contextType;

    if (contextType == SCImageViewContextTypeAuto) {
        if ([SCImageView supportsContextType:SCImageViewContextTypeMetal]) {
            contextType = SCImageViewContextTypeMetal;
        } else if ([SCImageView supportsContextType:SCImageViewContextTypeEAGL]) {
            contextType = SCImageViewContextTypeEAGL;
        } else if ([SCImageView supportsContextType:SCImageViewContextTypeCoreGraphics]) {
            contextType = SCImageViewContextTypeCoreGraphics;
        } else {
            [NSException raise:@"NoContextSupported" format:@"Unable to find a compatible context for the SCImageView"];
        }
    }
    return contextType;
}

- (BOOL)loadContextIfNeeded {
    if (_context == nil) {
        SCImageViewContextType contextType = [self suggestedContextType];

        SCContextType sccontextType = -1;
        NSDictionary *options = nil;
        switch (contextType) {
            case SCImageViewContextTypeCoreGraphics:
                sccontextType = SCContextTypeCoreGraphics;
                CGContextRef contextRef = UIGraphicsGetCurrentContext();

                if (contextRef == nil) {
                    return NO;
                }
                options = @{SCContextOptionsCGContextKey: (__bridge id)contextRef};
                break;
            case SCImageViewContextTypeEAGL:
                sccontextType = SCContextTypeEAGL;
                break;
            case SCImageViewContextTypeMetal:
                sccontextType = SCContextTypeMetal;
                break;
            default:
                break;
        }

        self.context = [SCContext contextWithType:sccontextType options:options];
    }

    return YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    _GLKView.frame = self.bounds;
    _MTKView.frame = self.bounds;
}

- (void)unloadContext {
    if (_GLKView != nil) {
        [_GLKView removeFromSuperview];
        _GLKView = nil;
    }
    if (_MTKView != nil) {
        [_MTKView removeFromSuperview];
        [_MTKView releaseDrawables];
        _MTKView = nil;
    }
    _context = nil;
}

- (void)setContext:(SCContext * _Nullable)context {
    [self unloadContext];

    if (context != nil) {
        switch (context.type) {
            case SCContextTypeCoreGraphics:
                break;
            case SCContextTypeEAGL:
                _GLKView = [[GLKView alloc] initWithFrame:self.bounds context:context.EAGLContext];
                _GLKView.delegate = self;
                [self insertSubview:_GLKView atIndex:0];
                break;
            case SCContextTypeMetal:
                _MTKView = [[MTKView alloc] initWithFrame:self.bounds device:context.MTLDevice];
                _MTKView.delegate = self;
                _MTKView.enableSetNeedsDisplay = YES;
                [self insertSubview:_MTKView atIndex:0];
                break;
            default:
                [NSException raise:@"InvalidContext" format:@"Unsupported context type: %d. SCImageView only supports CoreGraphics, EAGL and Metal", (int)context.type];
                break;
        }
    }

    _context = context;
}

- (void)setNeedsDisplay {
    [super setNeedsDisplay];

    [_GLKView setNeedsDisplay];
    [_MTKView setNeedsDisplay];
}

+ (BOOL)supportsContextType:(SCImageViewContextType)contextType {
    switch (contextType) {
        case SCImageViewContextTypeAuto:
            return YES;
        case SCImageViewContextTypeMetal:
            return [SCContext supportsType:SCContextTypeMetal];
        case SCImageViewContextTypeCoreGraphics:
            return [SCContext supportsType:SCContextTypeCoreGraphics];
        case SCImageViewContextTypeEAGL:
            return [SCContext supportsType:SCContextTypeCoreGraphics];
    }
    return NO;
}

- (void)drawCIImageInRect:(CGRect)rect MTLTexture:(id<MTLTexture>)texture {
    CIImage *newImage = [CIImageRendererUtils generateImageFromSampleBufferHolder:_sampleBufferHolder];

    if (newImage != nil) {
        _CIImage = newImage;
    }

    CIImage *image = _CIImage;

    if (image != nil) {
        image = [image imageByApplyingTransform:self.preferredCIImageTransform];
        [self drawCIImage:image inRect:rect andCIContext:self.context.CIContext MTLTexture:texture];
    }
}

- (void)drawCIImage:(CIImage *)CIImage inRect:(CGRect)rect andCIContext:(CIContext *)CIContext MTLTexture:(id<MTLTexture>)texture {
    CGRect extent = [CIImage extent];

    CGRect outputRect = [CIImageRendererUtils processRect:self.bounds withImageSize:extent.size contentScale:self.contentScaleFactor contentMode:self.contentMode];

    if (texture != nil) {
        CGColorSpaceRef deviceRGB = CGColorSpaceCreateDeviceRGB();
        [CIContext render:CIImage toMTLTexture:texture commandBuffer:nil bounds:outputRect colorSpace:deviceRGB];
        CGColorSpaceRelease(deviceRGB);
    } else {
        [CIContext drawImage:CIImage inRect:outputRect fromRect:extent];
    }
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    if (_CIImage != nil && [self loadContextIfNeeded]) {
        if (self.context.type == SCContextTypeCoreGraphics) {
            [self drawCIImageInRect:rect MTLTexture:nil];
        }
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
        [self loadContextIfNeeded];
    }
    
    [self setNeedsDisplay];
}

- (void)setContextType:(SCImageViewContextType)contextType {
    if (_contextType != contextType) {
        self.context = nil;
        _contextType = contextType;
    }
}

#pragma mark -- MTKViewDelegate

- (void)drawInMTKView:(nonnull MTKView *)view {
    [self drawCIImageInRect:view.bounds MTLTexture:view.currentDrawable.texture];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {

}

#pragma mark -- GLKViewDelegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    [self drawCIImageInRect:rect MTLTexture:nil];
}

@end
