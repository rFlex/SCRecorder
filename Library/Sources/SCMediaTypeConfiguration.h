//
//  SCConfiguration.h
//  SCRecorder
//
//  Created by Simon CORSIN on 21/11/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

extern NSString *__nonnull SCPresetHighestQuality;
extern NSString *__nonnull SCPresetMediumQuality;
extern NSString *__nonnull SCPresetLowQuality;

@interface SCMediaTypeConfiguration : NSObject

/**
 Whether this media type is enabled or not.
 */
@property (assign, nonatomic) BOOL enabled;

/**
 Whether this input type should be ignored. Unlike the "enabled" property,
 this does not remove the input or outputs. It just asks the recorder to not
 write the buffers even though it is enabled. This is only needed if you want
 to quickly enable/disable this media type without reconfiguring all the input/outputs
 which can be is a quite slow operation to do.
 */
@property (assign, nonatomic) BOOL shouldIgnore;

/**
 Set the bitrate of the audio
 If options is not nil,, this property will be ignored
 */
@property (assign, nonatomic) UInt64 bitrate;

/**
 If set, every other properties but "enabled" will be ignored
 and this options dictionary will be used instead.
 */
@property (copy, nonatomic) NSDictionary *__nullable options;

/**
 Defines a preset to use. If set, most properties will be
 ignored to use values that reflect this preset.
 */
@property (copy, nonatomic) NSString *__nullable preset;

- (NSDictionary *__nonnull)createAssetWriterOptionsUsingSampleBuffer:(CMSampleBufferRef __nullable)sampleBuffer;

@end
