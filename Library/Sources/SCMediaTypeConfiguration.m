//
//  SCConfiguration.m
//  SCRecorder
//
//  Created by Simon CORSIN on 21/11/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCMediaTypeConfiguration.h"

@implementation SCMediaTypeConfiguration

- (id)init {
    self = [super init];
    
    if (self) {
        _enabled = YES;
    }
    
    return self;
}

- (NSDictionary *)createAssetWriterOptionsUsingSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    return nil;
}

- (void)setEnabled:(BOOL)enabled {
    if (_enabled != enabled) {
        [self willChangeValueForKey:@"enabled"];
        _enabled = enabled;
        [self didChangeValueForKey:@"enabled"];
    }
}

@end
