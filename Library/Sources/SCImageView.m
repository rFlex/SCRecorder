//
//  SCCIImageView.m
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCImageView.h"
#import "SCSampleBufferHolder.h"
#import "SCContext.h"

#if TARGET_IPHONE_SIMULATOR
@interface SCImageView()<GLKViewDelegate>

#else
@import MetalKit;

@interface SCImageView()<GLKViewDelegate, MTKViewDelegate>

@property (nonatomic, strong) MTKView *MTKView;
#endif

@property (nonatomic, strong) GLKView *GLKView;
@property (nonatomic, strong) id<MTLCommandQueue> MTLCommandQueue;
@property (nonatomic, strong) SCSampleBufferHolder *sampleBufferHolder;

@end

@implementation SCImageView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self _imageViewCommonInit];
    }
    
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self _imageViewCommonInit];
    }
    
    return self;
}

- (void)_imageViewCommonInit {
    _scaleAndResizeCIImageAutomatically = YES;
    self.preferredCIImageTransform = CGAffineTransformIdentity;
    
    _sampleBufferHolder = [SCSampleBufferHolder new];
}

- (BOOL)loadContextIfNeeded {
    if (_context == nil) {
        SCContextType contextType = _contextType;
        if (contextType == SCContextTypeAuto) {
            contextType = [SCContext suggestedContextType];
        }

        NSDictionary *options = nil;
        switch (contextType) {
            case SCContextTypeCoreGraphics: {
                CGContextRef contextRef = UIGraphicsGetCurrentContext();

                if (contextRef == nil) {
                    return NO;
                }
                options = @{SCContextOptionsCGContextKey: (__bridge id)contextRef};
            }
                break;            
            case SCContextTypeCPU:
                [NSException raise:@"UnsupportedContextType" format:@"SCImageView does not support CPU context type."];
                break;
            default:
                break;
        }

        self.context = [SCContext contextWithType:contextType options:options];
    }

    return YES;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    _GLKView.frame = self.bounds;

#if !(TARGET_IPHONE_SIMULATOR)
    _MTKView.frame = self.bounds;
#endif
}

- (void)unloadContext {
    if (_GLKView != nil) {
        [_GLKView removeFromSuperview];
        _GLKView = nil;
    }
#if !(TARGET_IPHONE_SIMULATOR)
    if (_MTKView != nil) {
        _MTLCommandQueue = nil;
        [_MTKView removeFromSuperview];
        [_MTKView releaseDrawables];
        _MTKView = nil;
    }
#endif
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
#if !(TARGET_IPHONE_SIMULATOR)
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
#endif
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
#if !(TARGET_IPHONE_SIMULATOR)
    [_MTKView setNeedsDisplay];
#endif
}

- (UIImage *)renderedUIImageInRect:(CGRect)rect {
    UIImage *returnedImage = nil;
    CIImage *image = [self renderedCIImageInRect:rect];

    if (image != nil) {
        CIContext *context = nil;
        if (![self loadContextIfNeeded]) {
            context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @(NO)}];
        } else {
            context = _context.CIContext;
        }

        CGImageRef imageRef = [context createCGImage:image fromRect:image.extent];

        if (imageRef != nil) {
            returnedImage = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
        }
    }

    return returnedImage;
}

- (CIImage *)renderedCIImageInRect:(CGRect)rect {
    CMSampleBufferRef sampleBuffer = _sampleBufferHolder.sampleBuffer;

    if (sampleBuffer != nil) {
        _CIImage = [CIImage imageWithCVPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer)];
        _sampleBufferHolder.sampleBuffer = nil;
    }

    CIImage *image = _CIImage;

    if (image != nil) {
        image = [image imageByApplyingTransform:self.preferredCIImageTransform];

        if (self.context.type != SCContextTypeEAGL) {
            image = [image imageByApplyingOrientation:4];
        }

        if (self.scaleAndResizeCIImageAutomatically) {
            image = [self scaleAndResizeCIImage:image forRect:rect];
        }
    }

    return image;
}

- (CIImage *)renderedCIImage {
    return [self renderedCIImageInRect:self.CIImage.extent];
}

- (UIImage *)renderedUIImage {
    return [self renderedUIImageInRect:self.CIImage.extent];
}

- (CIImage *)scaleAndResizeCIImage:(CIImage *)image forRect:(CGRect)rect {
    CGSize imageSize = image.extent.size;

    CGFloat horizontalScale = rect.size.width / imageSize.width;
    CGFloat verticalScale = rect.size.height / imageSize.height;

    UIViewContentMode mode = self.contentMode;

    if (mode == UIViewContentModeScaleAspectFill) {
        horizontalScale = MAX(horizontalScale, verticalScale);
        verticalScale = horizontalScale;
    } else if (mode == UIViewContentModeScaleAspectFit) {
        horizontalScale = MIN(horizontalScale, verticalScale);
        verticalScale = horizontalScale;
    }

    return [image imageByApplyingTransform:CGAffineTransformMakeScale(horizontalScale, verticalScale)];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];

    if (_CIImage != nil && [self loadContextIfNeeded]) {
        if (self.context.type == SCContextTypeCoreGraphics) {
            CIImage *image = [self renderedCIImageInRect:rect];

            if (image != nil) {
                [_context.CIContext drawImage:image inRect:rect fromRect:image.extent];
            }
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

- (void)setContextType:(SCContextType)contextType {
    if (_contextType != contextType) {
        self.context = nil;
        _contextType = contextType;
    }
}

static CGRect CGRectMultiply(CGRect rect, CGFloat contentScale) {
    rect.origin.x *= contentScale;
    rect.origin.y *= contentScale;
    rect.size.width *= contentScale;
    rect.size.height *= contentScale;

    return rect;
}

#pragma mark -- GLKViewDelegate

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect {
    @autoreleasepool {
        rect = CGRectMultiply(rect, self.contentScaleFactor);
        glClearColor(0, 0, 0, 0);
        glClear(GL_COLOR_BUFFER_BIT);

        CIImage *image = [self renderedCIImageInRect:rect];

        if (image != nil) {
            [_context.CIContext drawImage:image inRect:rect fromRect:image.extent];
        }
    }
}

#if !(TARGET_IPHONE_SIMULATOR)
#pragma mark -- MTKViewDelegate

- (void)drawInMTKView:(nonnull MTKView *)view {
    @autoreleasepool {
        CGRect rect = CGRectMultiply(view.bounds, self.contentScaleFactor);

        CIImage *image = [self renderedCIImageInRect:rect];

        if (image != nil) {
            id<MTLCommandBuffer> commandBuffer = [_MTLCommandQueue commandBuffer];
            id<MTLTexture> texture = view.currentDrawable.texture;
            CGColorSpaceRef deviceRGB = CGColorSpaceCreateDeviceRGB();
            [_context.CIContext render:image toMTLTexture:texture commandBuffer:commandBuffer bounds:image.extent colorSpace:deviceRGB];
            [commandBuffer presentDrawable:view.currentDrawable];
            [commandBuffer commit];

            CGColorSpaceRelease(deviceRGB);
        }
    }
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    
}
#endif

@end
