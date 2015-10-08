//
//  SCCIImageView.h
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <GLKit/GLKit.h>
#import "SCFilter.h"
#import "CIImageRenderer.h"
#import "SCContext.h"

typedef NS_ENUM(NSInteger, SCImageViewContextType) {

    /**
     Automatically chooses the appropriate context
     */
    SCImageViewContextTypeAuto,

    /**
     Create a hardware accelerated SCContext with Metal
     */
    SCImageViewContextTypeMetal,

    /**
     Create a hardware accelerated SCContext with CoreGraphics
     */
    SCImageViewContextTypeCoreGraphics,

    /**
     Create a hardware accelerated SCContext with EAGL (OpenGL)
     */
    SCImageViewContextTypeEAGL
};


/**
 A Core Image renderer that works like a UIView. It supports filter through the
 filterGroup property.
 */
@interface SCImageView : UIView<CIImageRenderer>

/**
 The context type to use when loading the context.
 */
@property (assign, nonatomic) SCImageViewContextType contextType;

/**
 The SCContext that hold the underlying CIContext for rendering the CIImage's
 Will be automatically loaded when setting the first CIImage or when rendering
 for the first if using a CoreGraphics context type.
 You can also set your own context.
 Supported contexts are Metal, CoreGraphics, EAGL
 */
@property (strong, nonatomic) SCContext *__nullable context;

/**
 The CIImage to render.
 */
@property (strong, nonatomic) CIImage *__nullable CIImage;

/**
 The timestamp of the CIImage
 */
@property (assign, nonatomic) CFTimeInterval CIImageTime;

/**
 The preferred transform for rendering the CIImage
 */
@property (assign, nonatomic) CGAffineTransform preferredCIImageTransform;

/**
 Set the CIImage using a sampleBuffer. The CIImage will be automatically generated
 when needed. This avoids creating multiple CIImage if the SCImageView can't render them
 as fast.
 */
- (void)setImageBySampleBuffer:(__nonnull CMSampleBufferRef)sampleBuffer;

/**
 Set the CIImage using an UIImage
 */
- (void)setImageByUIImage:(UIImage *__nullable)image;

/**
 Create the CIContext and setup the underlying rendering views. This is automatically done when setting an CIImage
 for the first time to make the initialization faster. If for some reasons you want it to be done earlier
 you can call this method.
 Returns whether the context has been successfully loaded, returns NO otherwise.
 */
- (BOOL)loadContextIfNeeded;

/**
 Returns whether the contextType is supported.
 */
+ (BOOL)supportsContextType:(SCImageViewContextType)contextType;

/**
 Subclass can override this method to render the given CIImage into the CIContext.
 */
- (void)drawCIImage:(CIImage *)CIImage inRect:(CGRect)rect;

- (void)drawCIImage:(CIImage *)CIImage inRect:(CGRect)inRect fromRect:(CGRect)fromRect;

/**
 Subclass can override this method to prevent the CIImage to be rescaled and resized automatically
 */
- (BOOL)shouldScaleAndResizeCIImageAutomatically;

@end
