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
#import "SCContext.h"

/**
 A view capable of rendering CIImages.
 */
@interface SCImageView : UIView

/**
 The context type to use when loading the context.
 */
@property (assign, nonatomic) SCContextType contextType;

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
 Whether the CIImage should be scaled and resized according to the contentMode of this view.
 Default is YES.
 */
@property (assign, nonatomic) BOOL scaleAndResizeCIImageAutomatically;

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
 Returns the rendered CIImage in the given rect.
 Subclass can override this method to alterate the rendered image.
 */
- (CIImage *__nullable)renderedCIImageInRect:(CGRect)rect;

/**
 Returns the rendered CIImage in the given rect.
 It internally calls renderedCIImageInRect:
 Subclass should not override this method.
 */
- (UIImage *__nullable)renderedUIImageInRect:(CGRect)rect;

/**
 Returns the rendered CIImage in its natural size.
 Subclass should not override this method.
 */
- (CIImage *__nullable)renderedCIImage;

/**
 Returns the rendered UIImage in its natural size.
 Subclass should not override this method.
 */
- (UIImage *__nullable)renderedUIImage;


@end
