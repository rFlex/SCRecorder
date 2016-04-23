//
//  SCFilterImageView.h
//  SCRecorder
//
//  Created by Simon Corsin on 10/8/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import "SCImageView.h"
#import "SCFilter.h"

@interface SCFilterImageView : SCImageView

/**
 The filter to apply when rendering. If nil is set, no filter will be applied
 */
@property (strong, nonatomic) SCFilter *__nullable filter;

@end
