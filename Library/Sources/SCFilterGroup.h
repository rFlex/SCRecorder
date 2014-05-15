//
//  SCFilterGroup.h
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

@interface SCFilterGroup : NSObject

// The list of filters that this filterGroup contains
@property (readonly, nonatomic) NSArray *filters;

+ (SCFilterGroup *)filterGroupWithFilter:(CIFilter *)filter;

// Init with a single filter
- (id)initWithFilter:(CIFilter *)filter;

// Add a filter to the filterGroup
- (void)addFilter:(CIFilter *)filter;

// Remove a filter from the filterGroup
- (void)removeFilter:(CIFilter *)filter;

- (CIImage *)imageByProcessingImage:(CIImage *)image;

@end
