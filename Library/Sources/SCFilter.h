//
//  SCFilter.h
//  CoreImageShop
//
//  Created by Simon CORSIN on 16/05/14.
//
//

#import <Foundation/Foundation.h>

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
#import <CoreImage/CoreImage.h>
#else
#import <QuartzCore/QuartzCore.h>
#endif

#import "SCFilterAnimation.h"

@class SCFilter;
@protocol SCFilterDelegate <NSObject, NSCopying>

/**
 Called when a parameter changed from the SCFilter instance.
 */
- (void)filter:(SCFilter *__nonnull)filter didChangeParameter:(NSString *__nonnull)parameterKey;

/**
 Called before the filter start processing an image.
 */
- (void)filter:(SCFilter *__nonnull)filter willProcessImage:(CIImage *__nullable)image atTime:(CFTimeInterval)time;

/**
 Called when the parameter values has been reset to defaults.
 */
- (void)filterDidResetToDefaults:(SCFilter *__nonnull)filter;

@end

@interface SCFilter : NSObject<NSCoding>

/**
 The underlying CIFilter attached to this SCFilter instance.
 */
@property (readonly, nonatomic) CIFilter *__nullable CIFilter;

/**
 The name of this filter. By default it takes the name of the attached
 CIFilter.
 */
@property (strong, nonatomic) NSString *__nullable name;

/**
 Whether this filter should process the images from imageByProcessingImage:.
 */
@property (assign, nonatomic) BOOL enabled;

/**
 Whether this SCFilter and all its subfilters have no CIFilter attached.
 If YES, it means that calling imageByProcessingImage: will always return the input
 image without any modification.
 */
@property (readonly, nonatomic) BOOL isEmpty;

/**
 Contains every added sub filters.
 */
@property (readonly, nonatomic) NSArray *__nonnull subFilters;

/**
 Contains every added SCFilterAnimations
 */
@property (readonly, nonatomic) NSArray *__nonnull animations;

/**
 Set a delegate that will receive messages when some parameters change
 */
@property (weak, nonatomic) __nullable id<SCFilterDelegate> delegate;

/**
 Initialize a SCFilter with an attached CIFilter.
 CIFilter can be nil.
 */
- (nullable instancetype)initWithCIFilter:(CIFilter *__nullable)filter;

/**
 Returns the attached CIFilter parameter value for the given key.
 */
- (__nullable id)parameterValueForKey:(NSString *__nonnull)key;

/**
 Set the attached CIFilter parameter value for the given key.
 */
- (void)setParameterValue:(__nullable id)value forKey:(NSString *__nonnull)key;

/**
 Add a SCFilterAnimation that can animate parameter values.
 */
- (void)addAnimation:(SCFilterAnimation *__nonnull)animation;

/**
 Convenience method to create and add an SCFilterAnimation that can animate parameter values.
 */
- (SCFilterAnimation *__nonnull)addAnimationForParameterKey:(NSString *__nonnull)key startValue:(__nullable id)startValue endValue:(__nullable id)endValue startTime:(CFTimeInterval)startTime duration:(CFTimeInterval)duration;

/**
 Remove an already added SCFilterAnimation.
 */
- (void)removeAnimation:(SCFilterAnimation *__nonnull)animation;

/**
 Remove all added SCFilterAnimation animations
 */
- (void)removeAllAnimations;

/**
 Reset the attached CIFilter parameter values to default for this instance
 and all the sub filters.
 */
- (void)resetToDefaults;

/**
 Add a sub filter. When processing an image, this SCFilter instance will first process the
 image using its attached CIFilter, then it will ask every sub filters added to process the
 given image.
 */
- (void)addSubFilter:(SCFilter *__nonnull)subFilter;

/**
 Remove a sub filter.
 */
- (void)removeSubFilter:(SCFilter *__nonnull)subFilter;

/**
 Remove a sub filter at a given index.
 */
- (void)removeSubFilterAtIndex:(NSInteger)index;

/**
 Insert a sub filter at a given index.
 */
- (void)insertSubFilter:(SCFilter *__nonnull)subFilter atIndex:(NSInteger)index;

/**
 Write this filter to a specific file.
 This filter can then be restored from this file using [SCFilter filterWithContentsOfUrl:].
 */
- (void)writeToFile:(NSURL *__nonnull)fileUrl error:(NSError *__nullable*__nullable)error;

/**
 Returns the CIImage by processing the given CIImage.
 */
- (CIImage *__nullable)imageByProcessingImage:(CIImage *__nullable)image;

/**
 Returns the CIImage by processing the given CIImage with the given time.
 */
- (CIImage *__nullable)imageByProcessingImage:(CIImage *__nullable)image atTime:(CFTimeInterval)time;

/**
 Creates and returns an empty SCFilter that has no CIFilter attached to it.
 It won't do anything when processing an image unless you add a non empty sub filter to it.
 */
+ (SCFilter *__nonnull)emptyFilter;

/**
 Creates and returns an SCFilter that will have the given CIFilter attached.
 */
+ (SCFilter *__nonnull)filterWithCIFilter:(CIFilter *__nullable)CIFilter;

/**
 Creates and returns an SCFilter attached to a newly created CIFilter from the given CIFilter name.
 */
+ (SCFilter *__nonnull)filterWithCIFilterName:(NSString *__nonnull)name;

/**
 Creates and returns an SCFilter that will process the images using the given affine transform.
 */
+ (SCFilter *__nonnull)filterWithAffineTransform:(CGAffineTransform)affineTransform;

/**
 Creates and returns a filter with a serialized filter data.
 */
+ (SCFilter *__nonnull)filterWithData:(NSData *__nonnull)data;

/**
 Creates and returns a filter with a serialized filter data.
 */
+ (SCFilter *__nonnull)filterWithData:(NSData *__nonnull)data error:(NSError *__nullable*__nullable)error;

/**
 Creates and returns a filter with an URL containing a serialized filter data.
 */
+ (SCFilter *__nonnull)filterWithContentsOfURL:(NSURL *__nullable)url;

/**
 Creates and returns a filter containg the given sub SCFilters.
 */
+ (SCFilter *__nonnull)filterWithFilters:(NSArray *__nonnull)filters;

/**
 Creates and returns a filter that will apply a CIImage on top
 */
+ (SCFilter *__nonnull)filterWithCIImage:(CIImage *__nonnull)image;

@end
