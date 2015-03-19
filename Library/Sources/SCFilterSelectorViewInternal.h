//
//  SCFilterSelectorViewInternal.h
//  SCRecorder
//
//  Created by Simon CORSIN on 16/09/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCFilterSelectorView.h"
#import "SCSampleBufferHolder.h"

@interface SCFilterSelectorView() {
    CIContext *_CIContext;
    EAGLContext *_EAGLContext;
    GLKView *_glkView;
    SCSampleBufferHolder *_sampleBufferHolder;
    CIFilter *_imageTransformFilter;
}

@property (strong, nonatomic) SCFilter *selectedFilter;

/**
 Called when init. Don't forget to call super
 */
- (void)commonInit;

/**
 Ask the GLKView to redraw without asking the whole SCFilterSelectorView to redraw.
 */
- (void)refresh;

/**
 The default implementation draws the image fullscreen with the current selectedFilterGroup
 Override if you want a custom drawing
 */
- (void)render:(CIImage *)image toContext:(CIContext *)context inRect:(CGRect)rect;

@end
