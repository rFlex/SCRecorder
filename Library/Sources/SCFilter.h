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

@class SCFilter;
@protocol SCFilterDelegate <NSObject>

/**
 Called when a parameter changed from the SCFilter instance.
 */
- (void)filter:(SCFilter *)filter didChangeParameter:(NSString *)parameterKey;

/**
 Called when the parameter values has been reset to defaults.
 */
- (void)filterDidResetToDefaults:(SCFilter *)filter;

@end

@interface SCFilter : NSObject<NSCoding>

/**
 The underlying CIFilter attached to this SCFilter instance.
 */
@property (readonly, nonatomic) CIFilter *CIFilter;

/**
 The name of this filter. By default it takes the name of the attached
 CIFilter.
 */
@property (strong, nonatomic) NSString *name;

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
@property (readonly, nonatomic) NSArray *subFilters;

/**
 Set a delegate that will receive messages when some parameters change
 */
@property (weak, nonatomic) id<SCFilterDelegate> delegate;

/**
 Initialize a SCFilter with an attached CIFilter.
 CIFilter can be nil.
 */
- (id)initWithCIFilter:(CIFilter *)filter;

/**
 Returns the attached CIFilter parameter value for the given key.
 */
- (id)parameterValueForKey:(NSString *)key;

/**
 Set the attached CIFilter parameter value for the given key.
 */
- (void)setParameterValue:(id)value forKey:(NSString *)key;

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
- (void)addSubFilter:(SCFilter *)subFilter;

/**
 Remove a sub filter.
 */
- (void)removeSubFilter:(SCFilter *)subFilter;

/**
 Remove a sub filter at a given index.
 */
- (void)removeSubFilterAtIndex:(NSInteger)index;

/**
 Insert a sub filter at a given index.
 */
- (void)insertSubFilter:(SCFilter *)subFilter atIndex:(NSInteger)index;

/**
 Write this filter to a specific file.
 This filter can then be restored from this file using [SCFilter filterWithContentsOfUrl:].
 */
- (void)writeToFile:(NSURL *)fileUrl error:(NSError **)error;

/**
 Returns the CIImage by processing the given CIImage.
 */
- (CIImage *)imageByProcessingImage:(CIImage *)image;

/**
 Creates and returns an empty SCFilter that has no CIFilter attached to it.
 It won't do anything when processing an image unless you add a non empty sub filter to it.
 */
+ (SCFilter *)emptyFilter;

/**
 Creates and returns an SCFilter that will have the given CIFilter attached.
 */
+ (SCFilter *)filterWithCIFilter:(CIFilter *)CIFilter;

/**
 Creates and returns an SCFilter attached to a newly created CIFilter from the given CIFilter name.
 */
+ (SCFilter *)filterWithCIFilterName:(NSString *)name;

/**
 Creates and returns an SCFilter that will process the images using the given affine transform.
 */
+ (SCFilter *)filterWithAffineTransform:(CGAffineTransform)affineTransform;

/**
 Creates and returns a filter with a serialized filter data.
 */
+ (SCFilter *)filterWithData:(NSData *)data;

/**
 Creates and returns a filter with a serialized filter data.
 */
+ (SCFilter *)filterWithData:(NSData *)data error:(NSError **)error;

/**
 Creates and returns a filter with an URL containing a serialized filter data.
 */
+ (SCFilter *)filterWithContentsOfURL:(NSURL *)url;

/**
 Creates and returns a filter containg the given sub SCFilters.
 */
+ (SCFilter *)filterWithFilters:(NSArray *)filters;

@end
