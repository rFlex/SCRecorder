//
//  SCContext.h
//  SCRecorder
//
//  Created by Simon CORSIN on 28/05/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

@interface SCContext : NSObject

@property (readonly, nonatomic) CIContext *CIContext;
@property (readonly, nonatomic) EAGLContext *EAGLContext;

+ (SCContext *)context;

@end
