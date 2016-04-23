//
//  SCSampleBufferHolder.m
//  SCRecorder
//
//  Created by Simon CORSIN on 10/09/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCSampleBufferHolder.h"

@implementation SCSampleBufferHolder

- (void)dealloc {
    if (_sampleBuffer != nil) {
        CFRelease(_sampleBuffer);
    }
}

- (void)setSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (_sampleBuffer != nil) {
        CFRelease(_sampleBuffer);
        _sampleBuffer = nil;
    }
    
    _sampleBuffer = sampleBuffer;
    
    if (sampleBuffer != nil) {
        CFRetain(sampleBuffer);
    }
}

+ (SCSampleBufferHolder *)sampleBufferHolderWithSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    SCSampleBufferHolder *sampleBufferHolder = [SCSampleBufferHolder new];
    
    sampleBufferHolder.sampleBuffer = sampleBuffer;
    
    return sampleBufferHolder;
}

@end
