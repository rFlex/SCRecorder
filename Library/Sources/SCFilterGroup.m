//
//  SCFilterGroup.m
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCFilterGroup.h"

@interface SCFilterGroup() {
    NSMutableArray *_filters;
}

@end

@implementation SCFilterGroup

- (id)init {
    self = [super init];
    
    if (self) {
        _filters = [NSMutableArray new];
    }
    
    return self;
}

- (id)initWithFilter:(CIFilter *)filter {
    self = [self init];
    
    if (self) {
        [self addFilter:filter];
    }
    
    return self;
}

- (void)addFilter:(CIFilter *)filter {
    [_filters addObject:filter];
}

- (void)removeFilter:(CIFilter *)filter {
    [_filters removeObject:filter];
}

- (CIImage *)imageByProcessingImage:(CIImage *)image {
    CIImage *result = image;
    
    for (CIFilter *filter in _filters) {
        [filter setValue:result forKey:kCIInputImageKey];
        result = [filter valueForKey:kCIOutputImageKey];
    }
    
    return result;
}

+ (SCFilterGroup *)filterGroupWithFilter:(CIFilter *)filter {
    return [[SCFilterGroup alloc] initWithFilter:filter];
}

@end
