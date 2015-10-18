//
//  SCFilter+VideoComposition.m
//  SCRecorder
//
//  Created by Simon Corsin on 10/17/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import "SCFilter+VideoComposition.h"

@implementation SCFilter (VideoComposition)

- (AVMutableVideoComposition *)videoCompositionWithAsset:(AVAsset *)asset {
    if ([[AVVideoComposition class] respondsToSelector:@selector(videoCompositionWithAsset:applyingCIFiltersWithHandler:)]) {
        CIContext *context = [CIContext contextWithOptions:@{kCIContextWorkingColorSpace : [NSNull null], kCIContextOutputColorSpace : [NSNull null]}];
        return [AVMutableVideoComposition videoCompositionWithAsset:asset applyingCIFiltersWithHandler:^(AVAsynchronousCIImageFilteringRequest * _Nonnull request) {
            CIImage *image = [self imageByProcessingImage:request.sourceImage atTime:CMTimeGetSeconds(request.compositionTime)];

            [request finishWithImage:image context:context];
        }];

    }
    return nil;
}

@end
