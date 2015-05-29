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
    return [self initWithSharegroup:nil];
}

- (id)initWithSharegroup:(EAGLSharegroup *)shareGroup {
    self = [super init];
    
    if (self) {
        _EAGLContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:shareGroup];
        
        NSDictionary *options = @{ kCIContextWorkingColorSpace : [NSNull null], kCIContextOutputColorSpace : [NSNull null] };
        
        _CIContext = [CIContext contextWithEAGLContext:_EAGLContext options:options];
    }
    
    return self;
}

+ (SCContext *)context {
    static dispatch_once_t onceToken;
    static EAGLSharegroup *shareGroup;
    dispatch_once(&onceToken, ^{
        shareGroup = [EAGLSharegroup new];
    });
    
    return [[SCContext alloc] initWithSharegroup:shareGroup];
}

@end
