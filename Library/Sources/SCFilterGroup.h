//
//  SCFilterGroup.h
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <CoreImage/CoreImage.h>
#else
#import <QuartzCore/QuartzCore.h>
#endif

#import "SCFilter.h"

@interface SCFilterGroup : NSObject<NSCoding>

/**
 The list of SCFilter that this group contains
 */
@property (readonly, nonatomic) NSArray *filters;

/**
 Returns an array of the underlying Core Image Filters
 */
@property (readonly, nonatomic) NSArray *coreImageFilters;

/**
 The name of this filterGroup. Used for visual representations
 */
@property (strong, nonatomic) NSString *name;

/**
 Init with a single filter
 */
- (id)initWithFilter:(SCFilter *)filter;

/**
 Init with an array of filters
 */
- (id)initWithFilters:(NSArray *)filters;

/**
 Add a filter to the filterGroup
 */
- (void)addFilter:(SCFilter *)filter;

/**
 Remove a filter from the filterGroup
 */
- (void)removeFilter:(SCFilter *)filter;

/**
 Remove a filter at a specific index
 */
- (void)removeFilterAtIndex:(NSUInteger)index;

/**
 Returns a filter for a specific index
 */
- (SCFilter *)filterForIndex:(NSUInteger)index;

/**
 Write this filterGroup to a specific file.
 This filterGroup can then be restored from this file
 */
- (void)writeToFile:(NSURL *)fileUrl error:(NSError **)error;

/**
 Process the image using the underlying Core Image filters
 */
- (CIImage *)imageByProcessingImage:(CIImage *)image;

/**
 Create and return an empty filterGroup containing no filter.
 */
+ (SCFilterGroup *)emptyFilterGroup;

/**
 Create a filterGroup with one filter created using the filterName
 */
+ (SCFilterGroup *)filterGroupWithFilterName:(NSString *)filterName;

/**
 Create a filterGroup with one filter
 */
+ (SCFilterGroup *)filterGroupWithFilter:(SCFilter *)filter;

/**
 Create a filterGroup using an array of filters
 */
+ (SCFilterGroup *)filterGroupWithFilters:(NSArray *)filters;

/**
 Create a filterGroup with a serialized filterGroup data
 */
+ (SCFilterGroup *)filterGroupWithData:(NSData *)data;

/**
 Create a filterGroup with a serialized filterGroup data
 */
+ (SCFilterGroup *)filterGroupWithData:(NSData *)data error:(NSError **)error;

/**
 Create a filterGroup with an URL containing a serialized filterGroup data.
 */
+ (SCFilterGroup *)filterGroupWithContentsOfURL:(NSURL *)url;

@end
