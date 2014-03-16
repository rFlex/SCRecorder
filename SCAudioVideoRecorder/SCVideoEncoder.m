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

@synthesize outputBitsPerPixel;
@synthesize outputAffineTransform;
@synthesize outputVideoSize;

- (id) initWithAudioVideoRecorder:(SCAudioVideoRecorder *)audioVideoRecorder {
    self = [super initWithAudioVideoRecorder:audioVideoRecorder];
    
    if (self) {
        // Extra quality!
		self.outputAffineTransform = CGAffineTransformIdentity;
        self.outputBitsPerPixel = 12;
        self.outputVideoSize = CGSizeZero;
    }
    
    return self;
}

+ (NSInteger) getBitsPerSecondForOutputVideoSize:(CGSize)size andBitsPerPixel:(Float32)bitsPerPixel {
    int numPixels = size.width * size.height;
    
    return (NSInteger)((Float32)numPixels * bitsPerPixel);
}

- (AVAssetWriterInput*) createWriterInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer error:(NSError **)error {
    CGSize videoSize = self.outputVideoSize;
    
    if (CGSizeEqualToSize(videoSize, CGSizeZero)) {
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        videoSize.width = width;
        videoSize.height = height;
    }
    
    NSInteger bitsPerSecond = [SCVideoEncoder getBitsPerSecondForOutputVideoSize:videoSize andBitsPerPixel:self.outputBitsPerPixel];
		    
    AVAssetWriterInput * assetWriterVideoIn = nil;
	
	NSDictionary *videoCompressionSettings = [NSDictionary dictionaryWithObjectsAndKeys:
											  AVVideoCodecH264, AVVideoCodecKey,
                                              AVVideoScalingModeResizeAspectFill, AVVideoScalingModeKey,
											  [NSNumber numberWithInteger:videoSize.width], AVVideoWidthKey,
											  [NSNumber numberWithInteger:videoSize.height], AVVideoHeightKey,
                                              [NSDictionary dictionaryWithObjectsAndKeys:
                                               [NSNumber numberWithInteger:bitsPerSecond], AVVideoAverageBitRateKey,
                                               nil],
                                              AVVideoCompressionPropertiesKey,
											  nil];
    
	if ([self.audioVideoRecorder.assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]) {
		assetWriterVideoIn = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
		assetWriterVideoIn.expectsMediaDataInRealTime = YES;
        assetWriterVideoIn.transform = self.outputAffineTransform;
        if (error != nil)
            *error = nil;
	} else {
        if (error != nil)
            *error = [SCAudioVideoRecorder createError:@"Unable to configure output settings"];
	}
    
    return assetWriterVideoIn;
}

@end
