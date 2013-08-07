//
//  SCVideoEncoder.m
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/5/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCVideoEncoder.h"
#import "SCAudioVideoRecorderInternal.h"

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////


////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCVideoEncoder {
    
}

- (id) initWithAudioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder {
    self = [super initWithAudioVideoRecorder:audioVideoRecorder];
    
    return self;
}

- (AVAssetWriterInput*) createWriterInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer error:(NSError **)error {
    float bitsPerPixel;
    CGSize videoSize = self.outputVideoSize;
    
    if (self.useInputFormatTypeAsOutputType) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        int width = CVPixelBufferGetWidth(imageBuffer);
        int height = CVPixelBufferGetHeight(imageBuffer);
        videoSize.width = width;
        videoSize.height = height;
        NSLog(@"VideoSize: %f/%f", videoSize.width, videoSize.height);
    }
    
	int numPixels = videoSize.width * videoSize.height;
	int bitsPerSecond;
	
    bitsPerPixel = 11.4; // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
	
	bitsPerSecond = numPixels * bitsPerPixel;
    
    AVAssetWriterInput * assetWriterVideoIn = nil;
    
	NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  AVVideoCodecH264, AVVideoCodecKey,
											  [NSNumber numberWithInteger:videoSize.width], AVVideoWidthKey,
											  [NSNumber numberWithInteger:videoSize.height], AVVideoHeightKey,
                                              //											  [NSDictionary dictionaryWithObjectsAndKeys:
                                              //											   [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
                                              //											   [NSNumber numberWithInteger:30], AVVideoMaxKeyFrameIntervalKey,
                                              //											   nil], AVVideoCompressionPropertiesKey,
											  nil];
	if ([self.audioVideoRecorder.assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
		assetWriterVideoIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
		assetWriterVideoIn.expectsMediaDataInRealTime = YES;
        assetWriterVideoIn.transform = CGAffineTransformMakeRotation(M_PI / 2);
        *error = nil;
	} else {
        *error = [SCAudioVideoRecorder createError:@"Unable to configure output settings"];
	}
    
    return assetWriterVideoIn;
}

@end
