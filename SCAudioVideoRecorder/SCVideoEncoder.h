//
//  SCVideoEncoder.h
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/5/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SCDataEncoder.h"

@interface SCVideoEncoder : SCDataEncoder<AVCaptureVideoDataOutputSampleBufferDelegate> {
    
}


+ (NSInteger) getBitsPerSecondForOutputVideoSize:(CGSize)size andBitsPerPixel:(Float32)bitsPerPixel;

// This value is used only if useInputFormatTypeAsOutputType is false
@property (assign, nonatomic) CGSize outputVideoSize;
@property (assign, nonatomic) CGAffineTransform outputAffineTransform;
@property (assign, nonatomic) Float32 outputBitsPerPixel;

@end
