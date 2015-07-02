//
//  SCVideoBuffer.m
//  SCRecorder
//
//  Created by Simon CORSIN on 02/07/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import "SCIOPixelBuffers.h"

@implementation SCIOPixelBuffers

- (instancetype)initWithInputPixelBuffer:(CVPixelBufferRef)inputPixelBuffer outputPixelBuffer:(CVPixelBufferRef)outputPixelBuffer time:(CMTime)time {
    self = [super init];
    
    if (self) {
        _inputPixelBuffer = inputPixelBuffer;
        _outputPixelBuffer = outputPixelBuffer;
        _time = time;
        
        CVPixelBufferRetain(inputPixelBuffer);
        CVPixelBufferRetain(outputPixelBuffer);
    }
    
    return self;
}

- (void)dealloc {
    CVPixelBufferRelease(_inputPixelBuffer);
    CVPixelBufferRelease(_outputPixelBuffer);
}

+ (SCIOPixelBuffers *)IOPixelBuffersWithInputPixelBuffer:(CVPixelBufferRef)inputPixelBuffer outputPixelBuffer:(CVPixelBufferRef)outputPixelBuffer time:(CMTime)time {
    return [[SCIOPixelBuffers alloc] initWithInputPixelBuffer:inputPixelBuffer outputPixelBuffer:outputPixelBuffer time:time];
}

@end
