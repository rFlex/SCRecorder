//
//  SCCIImageView.m
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <MetalKit/MetalKit.h>
#import "SCImageView.h"
#import "SCSampleBufferHolder.h"
#import "SCContext.h"

@interface SCImageView()<GLKViewDelegate, MTKViewDelegate> {
    SCSampleBufferHolder *_sampleBufferHolder;
    id<MTLCommandBuffer> _currentCommandBuffer;
    id<MTLTexture> _currentTexture;
}

@property (nonatomic, strong) GLKView *GLKView;
@property (nonatomic, strong) MTKView *MTKView;
@property (nonatomic, strong) id<MTLCommandQueue> MTLCommandQueue;

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
        _MTLCommandQueue = nil;
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
                _GLKView.contentScaleFactor = self.contentScaleFactor;
                _GLKView.delegate = self;
                [self insertSubview:_GLKView atIndex:0];
                break;
            case SCContextTypeMetal:
                _MTLCommandQueue = [context.MTLDevice newCommandQueue];
                _MTKView = [[MTKView alloc] initWithFrame:self.bounds device:context.MTLDevice];
                _MTKView.clearColor = MTLClearColorMake(0, 0, 0, 0);
                _MTKView.contentScaleFactor = self.contentScaleFactor;
                _MTKView.delegate = self;
                _MTKView.enableSetNeedsDisplay = YES;
                _MTKView.framebufferOnly = NO;
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
            return [SCContext supportsType:SCContextTypeEAGL];
    }
    return NO;
}

- (BOOL)shouldScaleAndResizeCIImageAutomatically {
    return YES;
}

- (void)drawCIImageInRect:(CGRect)rect {
    @autoreleasepool {
        CMSampleBufferRef sampleBuffer = _sampleBufferHolder.sampleBuffer;

        if (sampleBuffer != nil) {
            _CIImage = [CIImage imageWithCVPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer)];
            _sampleBufferHolder.sampleBuffer = nil;
        }

        CIImage *image = _CIImage;

        if (image != nil) {
            image = [image imageByApplyingTransform:self.preferredCIImageTransform];

            if ([self shouldScaleAndResizeCIImageAutomatically]) {;
//                image = [self scaleAndResizeCIImage:image forRect:rect];
            }
            
            [self drawCIImage:image inRect:rect];
        }
    }
}


- (CIImage *)scaleAndResizeCIImage:(CIImage *)image forRect:(CGRect)rect {
    CGSize imageSize = image.extent.size;

    CGFloat contentScale = self.contentScaleFactor;
    CGAffineTransform transform = CGAffineTransformMakeScale(contentScale, contentScale);
    transform = CGAffineTransformTranslate(transform, 10, 0);

    rect.origin.x *= contentScale;
    rect.origin.y *= contentScale;
    rect.size.width *= contentScale;
    rect.size.height *= contentScale;

    UIViewContentMode mode = self.contentMode;
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

    return [image imageByApplyingTransform:transform];
}

- (void)drawCIImage:(CIImage *)CIImage inRect:(CGRect)rect {
    CGRect extent = [CIImage extent];
    CIContext *context = _context.CIContext;

    if (_currentTexture != nil) {
        CGColorSpaceRef deviceRGB = CGColorSpaceCreateDeviceRGB();
        [context render:CIImage toMTLTexture:_currentTexture commandBuffer:_currentCommandBuffer bounds:extent colorSpace:deviceRGB];
        CGColorSpaceRelease(deviceRGB);
    } else {
        [context drawImage:CIImage inRect:rect fromRect:extent];
    }
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    if (_CIImage != nil && [self loadContextIfNeeded]) {
        if (self.context.type == SCContextTypeCoreGraphics) {
            [self drawCIImageInRect:rect];
        }
    }
}

- (void)setImageBySampleBuffer:(CMSampleBufferRef)sampleBuffer {
    _sampleBufferHolder.sampleBuffer = sampleBuffer;
    
    [self setNeedsDisplay];
}

+ (CGAffineTransform)preferredCIImageTransformFromUIImage:(UIImage *)image {
    if (image.imageOrientation == UIImageOrientationUp) {
        return CGAffineTransformIdentity;
    }
    CGAffineTransform transform = CGAffineTransformIdentity;

    switch (image.imageOrientation) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, image.size.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;

        case UIImageOrientationLeft:
        case UIImageOrientationLeftMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, 0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;

        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, 0, image.size.height);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationUpMirrored:
            break;
    }

    switch (image.imageOrientation) {
        case UIImageOrientationUpMirrored:
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.width, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;

        case UIImageOrientationLeftMirrored:
        case UIImageOrientationRightMirrored:
            transform = CGAffineTransformTranslate(transform, image.size.height, 0);
            transform = CGAffineTransformScale(transform, -1, 1);
            break;
        case UIImageOrientationUp:
        case UIImageOrientationDown:
        case UIImageOrientationLeft:
        case UIImageOrientationRight:
            break;
    }

    return transform;
}

- (void)setImageByUIImage:(UIImage *)image {
    if (image == nil) {
        self.CIImage = nil;
    } else {
        self.preferredCIImageTransform = [SCImageView preferredCIImageTransformFromUIImage:image];
        self.CIImage = [CIImage imageWithCGImage:image.CGImage];
    }
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
    _currentCommandBuffer = [_MTLCommandQueue commandBuffer];
    _currentTexture = view.currentDrawable.texture;
    [self drawCIImageInRect:view.bounds];

    [_currentCommandBuffer presentDrawable:view.currentDrawable];
    [_currentCommandBuffer commit];
    _currentCommandBuffer = nil;
    _currentTexture = nil;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {

}

#pragma mark -- GLKViewDelegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    glClearColor(0, 0, 0, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    [self drawCIImageInRect:rect];
}

@end
