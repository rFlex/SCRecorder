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

- (id)initWithFilter:(SCFilter *)filter {
    self = [self init];
    
    if (self) {
        [self addFilter:filter];
    }
    
    return self;
}

- (id)initWithFilters:(NSArray *)filters {
    self = [self init];
    
    if (self) {
        for (SCFilter *filter in filters) {
            [self addFilter:filter];
        }
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    NSArray *filters = [aDecoder decodeObjectForKey:@"filters"];
    NSString *name = [aDecoder decodeObjectForKey:@"name"];
    
    self = [self initWithFilters:filters];
    
    if (self) {
        self.name = name;
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_filters forKey:@"filters"];
    [aCoder encodeObject:_name forKey:@"name"];
}

- (void)addFilter:(SCFilter *)filter {
    [_filters addObject:filter];
}

- (void)removeFilter:(SCFilter *)filter {
    [_filters removeObject:filter];
}

- (CIImage *)imageByProcessingImage:(CIImage *)image {
    CIImage *result = image;
    
    for (SCFilter *filter in _filters) {
        if (filter.enabled) {
            CIFilter *ciFilter = filter.coreImageFilter;
            [ciFilter setValue:result forKey:kCIInputImageKey];
            result = [ciFilter valueForKey:kCIOutputImageKey];
        }
    }
    
    return result;
}

- (void)writeToFile:(NSURL *)fileUrl error:(NSError *__autoreleasing *)error {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self];
    [data writeToURL:fileUrl options:NSDataWritingAtomic error:error];
}

- (NSArray *)coreImageFilters {
    NSMutableArray *array = [NSMutableArray new];
    
    for (SCFilter *filter in _filters) {
        if (filter.enabled) {
            [array addObject:filter.coreImageFilter];
        }
    }
    
    return array;
}

- (SCFilter *)filterForIndex:(NSUInteger)index {
    return [_filters objectAtIndex:index];
}

- (void)removeFilterAtIndex:(NSUInteger)index {
    [_filters removeObjectAtIndex:index];
}

+ (SCFilterGroup *)filterGroupWithFilter:(SCFilter *)filter {
    return [[SCFilterGroup alloc] initWithFilter:filter];
}

+ (SCFilterGroup *)filterGroupWithFilters:(NSArray *)filters {
    return [[SCFilterGroup alloc] initWithFilters:filters];
}

+ (SCFilterGroup *)filterGroupWithData:(NSData *)data error:(NSError *__autoreleasing *)error {
    id obj = nil;
    @try {
        obj = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    } @catch (NSException *exception) {
        if (error != nil) {
            *error = [NSError errorWithDomain:@"SCFilterGroup" code:200 userInfo:@{
                                                                                   NSLocalizedDescriptionKey : exception.reason
                                                                                   }];
            return nil;
        }
    }
    
    if (![obj isKindOfClass:[SCFilterGroup class]]) {
        // Let support for old impl
        if ([obj isKindOfClass:[NSArray class]]) {
            obj = [SCFilterGroup filterGroupWithFilters:obj];
        } else {
            obj = nil;
            if (error != nil) {
                *error = [NSError errorWithDomain:@"" code:200 userInfo:@{
                                                                          NSLocalizedDescriptionKey : @"Invalid serialized class type"
                                                                          }];
            }
        }
    }
    
    return obj;
}

+ (SCFilterGroup *)filterGroupWithData:(NSData *)data {
    return [SCFilterGroup filterGroupWithData:data error:nil];
}

+ (SCFilterGroup *)filterGroupWithContentsOfURL:(NSURL *)url {
    NSData *data = [NSData dataWithContentsOfURL:url];
    
    if (data != nil) {
        return [SCFilterGroup filterGroupWithData:data];
    }
    
    return nil;
}

@end
