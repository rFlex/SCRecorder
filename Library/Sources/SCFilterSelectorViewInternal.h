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
}

@property (strong, nonatomic) SCFilterGroup *selectedFilterGroup;

@property (readonly, nonatomic) float glkViewContentScaleFactor;

- (void)commonInit;

- (void)refresh;

- (void)render:(CIImage *)image toContext:(CIContext *)context inRect:(CGRect)rect;

@end
