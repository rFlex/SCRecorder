//
//  SCAudioVideoRecorderInternal.h
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/6/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCAudioVideoRecorder.h"

@interface SCAudioVideoRecorder() {
    
}

//
// Internal methods and fields
//
- (void) prepareWriterAtSourceTime:(CMTime)sourceTime fromEncoder:(SCDataEncoder*)encoder;
+ (NSError*) createError:(NSString*)name;

@property (assign, nonatomic) BOOL shouldComputeOffset;
@property (assign, nonatomic) CMTime startedTime;
@property (assign, nonatomic) CMTime currentTimeOffset;
@property (assign, nonatomic) CMTime lastFrameTimeBeforePause;

@end
