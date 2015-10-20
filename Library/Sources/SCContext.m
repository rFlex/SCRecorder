//
//  SCContext.m
//  SCRecorder
//
//  Created by Simon CORSIN on 28/05/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import "SCContext.h"

@implementation SCContext

NSString *__nonnull const SCContextOptionsCGContextKey = @"CGContext";
NSString *__nonnull const SCContextOptionsEAGLContextKey = @"EAGLContext";
NSString *__nonnull const SCContextOptionsMTLDeviceKey = @"MTLDevice";

static NSDictionary *SCContextCreateCIContextOptions() {
    return @{kCIContextWorkingColorSpace : [NSNull null], kCIContextOutputColorSpace : [NSNull null]};
}

- (instancetype)initWithSoftwareRenderer:(BOOL)softwareRenderer {
    self = [super init];

    if (self) {
        NSMutableDictionary *options = SCContextCreateCIContextOptions().mutableCopy;
        options[kCIContextUseSoftwareRenderer] = @(softwareRenderer);
        _CIContext = [CIContext contextWithOptions:options];
        if (softwareRenderer) {
            _type = SCContextTypeCPU;
        } else {
            _type = SCContextTypeDefault;
        }
    }

    return self;
}

- (instancetype)initWithCGContextRef:(CGContextRef)contextRef {
    self = [super init];

    if (self) {
        _CIContext = [CIContext contextWithCGContext:contextRef options:SCContextCreateCIContextOptions()];
        _type = SCContextTypeCoreGraphics;
    }

    return self;
}

- (instancetype)initWithEAGLContext:(EAGLContext *)context {
    self = [super init];
    
    if (self) {
        _EAGLContext = context;

        _CIContext = [CIContext contextWithEAGLContext:_EAGLContext options:SCContextCreateCIContextOptions()];
        _type = SCContextTypeEAGL;
    }
    
    return self;
}

- (instancetype)initWithMTLDevice:(id<MTLDevice>)device {
    self = [super init];

    if (self) {
        _MTLDevice = device;

        _CIContext = [CIContext contextWithMTLDevice:device options:SCContextCreateCIContextOptions()];
        _type = SCContextTypeMetal;
    }

    return self;
}

+ (BOOL)supportsType:(SCContextType)contextType {
    id CIContextClass = [CIContext class];

    switch (contextType) {
        case SCContextTypeMetal:
            return [CIContextClass respondsToSelector:@selector(contextWithMTLDevice:options:)];
        case SCContextTypeCoreGraphics:
            return [CIContextClass respondsToSelector:@selector(contextWithCGContext:options:)];
        case SCContextTypeEAGL:
            return [CIContextClass respondsToSelector:@selector(contextWithEAGLContext:options:)];
        case SCContextTypeAuto:
        case SCContextTypeDefault:
        case SCContextTypeCPU:
            return YES;
    }
    return NO;
}

+ (SCContextType)suggestedContextType {
    // On iOS 9.0, Metal does not behave nicely with gaussian blur filters
//    if ([SCContext supportsType:SCContextTypeMetal]) {
//        return SCContextTypeMetal;
//    } else
    if ([SCContext supportsType:SCContextTypeEAGL]) {
        return SCContextTypeEAGL;
    } else if ([SCContext supportsType:SCContextTypeCoreGraphics]) {
        return SCContextTypeCoreGraphics;
    } else {
        return SCContextTypeDefault;
    }
}

+ (SCContext *)contextWithType:(SCContextType)contextType options:(NSDictionary *)options {
    switch (contextType) {
        case SCContextTypeAuto:
            return [SCContext contextWithType:[SCContext suggestedContextType] options:options];
        case SCContextTypeMetal: {
            id<MTLDevice> device = options[SCContextOptionsMTLDeviceKey];
            if (device == nil) {
                device = MTLCreateSystemDefaultDevice();
            }

            return [[SCContext alloc] initWithMTLDevice:device];
        }
        case SCContextTypeCoreGraphics: {
            CGContextRef context = (__bridge CGContextRef)(options[SCContextOptionsCGContextKey]);

            if (context == nil) {
                [NSException raise:@"MissingCGContext" format:@"SCContextTypeCoreGraphics needs to have a CGContext attached to the SCContextOptionsCGContextKey in the options"];
            }

            return [[SCContext alloc] initWithCGContextRef:context];
        }
        case SCContextTypeCPU:
            return [[SCContext alloc] initWithSoftwareRenderer:YES];
        case SCContextTypeDefault:
            return [[SCContext alloc] initWithSoftwareRenderer:NO];
        case SCContextTypeEAGL: {
            EAGLContext *context = options[SCContextOptionsEAGLContextKey];

            if (context == nil) {
                static dispatch_once_t onceToken;
                static EAGLSharegroup *shareGroup;
                dispatch_once(&onceToken, ^{
                    shareGroup = [EAGLSharegroup new];
                });

                context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:shareGroup];
            }

            return [[SCContext alloc] initWithEAGLContext:context];
        }
        default:
            [NSException raise:@"InvalidContextType" format:@"Invalid context type %d", (int)contextType];
            break;
    }

    return nil;
}

@end
