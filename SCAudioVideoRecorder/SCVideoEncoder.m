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
    
    if (self) {
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
        self.outputAffineTransform = CGAffineTransformMakeRotation(M_PI / 2);
#endif
    }
    
    return self;
}

- (AVAssetWriterInput*) createWriterInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer error:(NSError **)error {
    float bitsPerPixel;
    CGSize videoSize = self.outputVideoSize;
    
    if (self.useInputFormatTypeAsOutputType) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        videoSize.width = width;
        videoSize.height = height;
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
        assetWriterVideoIn.transform = self.outputAffineTransform;
        *error = nil;
	} else {
        *error = [SCAudioVideoRecorder createError:@"Unable to configure output settings"];
	}
    
    return assetWriterVideoIn;
}

@end
