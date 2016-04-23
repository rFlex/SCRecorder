//
//  SCFilter+UIImage.h
//  SCRecorder
//
//  Created by Simon Corsin on 10/18/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCFilter.h"

@interface SCFilter (UIImage)

/**
 Returns a UIImage by processing this filter into the given UIImage
 */
- (UIImage *__nullable)UIImageByProcessingUIImage:(UIImage *__nullable)image atTime:(CFTimeInterval)time;

/**
 Returns a UIImage by processing this filter into the given UIImage
 */
- (UIImage *__nullable)UIImageByProcessingUIImage:(UIImage *__nullable)image;

@end
