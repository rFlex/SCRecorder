//
//  SCAssetExportSession.h
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SCFilterGroup.h"

extern NSString *SCAssetExportSessionPresetHighestQuality;
extern NSString *SCAssetExportSessionPresetMediumQuality;
extern NSString *SCAssetExportSessionPresetLowQuality;

@interface SCAssetExportSession : NSObject

// The input asset to use
@property (strong, nonatomic) AVAsset *inputAsset;

// The outputUrl to which the asset will be exported
@property (strong, nonatomic) NSURL *outputUrl;

// The type of file to be written by the session
@property (strong, nonatomic) NSString *outputFileType;

// The settings applied to the video's AVAssetWriterInput
// If nil, this will be automatically set depending on the sessionPreset
@property (strong, nonatomic) NSDictionary *videoSettings;

/**
 If not invalid, this will limit the number of frame duration. Video frames
 may be skipped to ensure it doesn't exceed this value.
 */
@property (assign, nonatomic) CMTime maxVideoFrameDuration;

// The settings applied to the audio's AVAssetWriterInput
// If nil, this will be automatically set depending on the sessionPreset
@property (strong, nonatomic) NSDictionary *audioSettings;

// The filterGroup that hold a list of Core Image filters.
// Can be nil
@property (strong, nonatomic) SCFilterGroup *filterGroup;

// If videoSettings or/and audioSettings is nil, this will be a hint of the settings
// to set. Setting this value is not mandatory if both videoSettings and audioSettings are set.
// Value can be SCAssetExportSessionPresetHighest, SCAssetExportSessionPresetMedium or SCAssetExportSessionPresetLow;
@property (copy, nonatomic) NSString *sessionPreset;

// If videoSettings are not set, the video size will be preserved no matter which
// session preset was set.
@property (assign, nonatomic) BOOL keepVideoSize;

// If true, the videoTransform property will be ignored and the videoTransform
// will be the same as the input asset
@property (assign, nonatomic) BOOL keepVideoTransform;

// If true, the export session will use the GPU for rendering the filters.
@property (assign, nonatomic) BOOL useGPUForRenderingFilters;

// If keepVideoTransform is not true, this will override the transform to use for the video
@property (assign, nonatomic) CGAffineTransform videoTransform;

// If an error occured during the export, this will contain that error
@property (readonly, nonatomic) NSError *error;

/**
 Whether it should ignore the audio in the inputAsset.
 If true, the output asset will not contains a audio track.
 */
@property (assign, nonatomic) BOOL ignoreAudio;

/**
 Whether it should ignore the video in the inputAsset.
 If true, the output asset will not contains a video track.
 */
@property (assign, nonatomic) BOOL ignoreVideo;


- (id)init;

// Init with the inputAsset
- (id)initWithAsset:(AVAsset*)inputAsset;

// Starts the asynchronous execution of the export session
- (void)exportAsynchronouslyWithCompletionHandler:(void(^)())completionHandler;




//////////////////
// PRIVATE API
////

// These are only exposed for inheritance purpose
@property (readonly, nonatomic) dispatch_queue_t dispatchQueue;
@property (readonly, nonatomic) dispatch_group_t dispatchGroup;
@property (readonly, nonatomic) AVAssetWriterInput *audioInput;
@property (readonly, nonatomic) AVAssetWriterInput *videoInput;

- (void)markInputComplete:(AVAssetWriterInput *)input error:(NSError *)error;
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)processPixelBuffer:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)presentationTime;
- (void)beginReadWriteOnInput:(AVAssetWriterInput *)input fromOutput:(AVAssetReaderOutput *)output;
- (BOOL)needsInputPixelBufferAdaptor;

@end
