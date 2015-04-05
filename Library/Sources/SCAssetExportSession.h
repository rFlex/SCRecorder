//
//  SCAssetExportSession.h
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SCFilter.h"
#import "SCVideoConfiguration.h"
#import "SCAudioConfiguration.h"

@class SCAssetExportSession;
@protocol SCAssetExportSessionDelegate <NSObject>

- (BOOL)assetExportSession:(SCAssetExportSession *)assetExportSession shouldReginReadWriteOnInput:(AVAssetWriterInput *)writerInput fromOutput:(AVAssetReaderOutput *)output;

- (BOOL)assetExportSessionNeedsInputPixelBufferAdaptor:(SCAssetExportSession *)assetExportSession;

@end

@interface SCAssetExportSession : NSObject

/**
 The input asset to use
 */
@property (strong, nonatomic) AVAsset *inputAsset;

/**
 The outputUrl to which the asset will be exported
 */
@property (strong, nonatomic) NSURL *outputUrl;

/**
 The type of file to be written by the export session
 */
@property (strong, nonatomic) NSString *outputFileType;

/**
 If true, the export session will use the GPU for rendering the filters
 */
@property (assign, nonatomic) BOOL useGPUForRenderingFilters;

/**
 Access the configuration for the video.
 */
@property (readonly, nonatomic) SCVideoConfiguration *videoConfiguration;

/**
 Access the configuration for the audio.
 */
@property (readonly, nonatomic) SCAudioConfiguration *audioConfiguration;

/**
 If an error occured during the export, this will contain that error
 */
@property (readonly, nonatomic) NSError *error;

/**
 The timeRange to read from the inputAsset
 */
@property (assign, nonatomic) CMTimeRange timeRange;


@property (weak, nonatomic) id<SCAssetExportSessionDelegate> delegate;

- (id)init;

// Init with the inputAsset
- (id)initWithAsset:(AVAsset*)inputAsset;

/**
 Starts the asynchronous execution of the export session
 */
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
- (BOOL)processSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (BOOL)processPixelBuffer:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)presentationTime;
- (void)beginReadWriteOnInput:(AVAssetWriterInput *)input fromOutput:(AVAssetReaderOutput *)output;
- (BOOL)needsInputPixelBufferAdaptor;

@end
