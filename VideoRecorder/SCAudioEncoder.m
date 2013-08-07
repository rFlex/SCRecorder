//
//  SCAudioEncoder.m
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/5/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCAudioEncoder.h"

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////


////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCAudioEncoder {
    
}

- (id) initWithAudioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder {
    self = [super initWithAudioVideoRecorder:audioVideoRecorder];
    
    return self;
}

- (AVAssetWriterInput*) createWriterInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer error:(NSError **)error {
    return nil;
}

@end
