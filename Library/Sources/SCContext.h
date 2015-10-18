//
//  SCContext.h
//  SCRecorder
//
//  Created by Simon CORSIN on 28/05/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <Metal/Metal.h>

typedef NS_ENUM(NSInteger, SCContextType) {

    /**
     Automatically choose an appropriate SCContext context
     */
    SCContextTypeAuto,

    /**
     Create a hardware accelerated SCContext with Metal
     */
    SCContextTypeMetal,

    /**
     Create a hardware accelerated SCContext with CoreGraphics
     */
    SCContextTypeCoreGraphics,

    /**
     Create a hardware accelerated SCContext with EAGL (OpenGL)
     */
    SCContextTypeEAGL,

    /**
     Creates a standard SCContext hardware accelerated.
     */
    SCContextTypeDefault,

    /**
     Create a software rendered SCContext (no hardware acceleration)
     */
    SCContextTypeCPU
};

extern NSString *__nonnull const SCContextOptionsCGContextKey;
extern NSString *__nonnull const SCContextOptionsEAGLContextKey;
extern NSString *__nonnull const SCContextOptionsMTLDeviceKey;

/**
 Simple abstraction over CIContext.
 */
@interface SCContext : NSObject

/**
 The CIContext
 */
@property (readonly, nonatomic) CIContext *__nonnull CIContext;

/**
 The type with with which this SCContext was created
 */
@property (readonly, nonatomic) SCContextType type;

/**
 Will be non null if the type is SCContextTypeEAGL
 */
@property (readonly, nonatomic) EAGLContext *__nullable EAGLContext;

/**
 Will be non null if the type is SCContextTypeMetal
 */
@property (readonly, nonatomic) id<MTLDevice> __nullable MTLDevice;

/**
 Will be non null if the type is SCContextTypeCoreGraphics
 */
@property (readonly, nonatomic) CGContextRef __nullable CGContext;

/**
 Create and returns a new context with the given type. You must check
 whether the contextType is supported by calling +[SCContext supportsType:] before.
 */
+ (SCContext *__nonnull)contextWithType:(SCContextType)type options:(NSDictionary *__nullable)options;

/**
 Returns whether the contextType can be safely created and used using +[SCContext contextWithType:]
 */
+ (BOOL)supportsType:(SCContextType)contextType;

/**
 The context that will be used when using an Auto context type;
 */
+ (SCContextType)suggestedContextType;

@end
