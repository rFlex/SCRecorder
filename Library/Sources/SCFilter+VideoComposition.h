//
//  SCFilter+VideoComposition.h
//  SCRecorder
//
//  Created by Simon Corsin on 10/17/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "SCFilter.h"

@interface SCFilter (VideoComposition)

/**
 Creates and returns a videoComposition that will process the given asset with this filter.
 Returns nil on unsupported platforms.
 */
- (AVMutableVideoComposition *__nullable)videoCompositionWithAsset:(AVAsset *__nonnull)asset NS_AVAILABLE(10_11, 9_0);

@end
