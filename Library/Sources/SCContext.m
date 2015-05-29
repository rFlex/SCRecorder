//
//  SCContext.m
//  SCRecorder
//
//  Created by Simon CORSIN on 28/05/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import "SCContext.h"

@implementation SCContext

- (id)init {
    self = [super init];
    
    if (self) {
        _EAGLContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        NSDictionary *options = @{ kCIContextWorkingColorSpace : [NSNull null], kCIContextOutputColorSpace : [NSNull null] };

        _CIContext = [CIContext contextWithEAGLContext:_EAGLContext options:options];
    }
    
    return self;
}

@end
