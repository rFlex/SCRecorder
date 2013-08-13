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

@property (assign, nonatomic) CGSize outputVideoSize;

@end
