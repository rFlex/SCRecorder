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

@optional

- (void)assetExportSessionDidProgress:(SCAssetExportSession *__nonnull)assetExportSession;

- (BOOL)assetExportSession:(SCAssetExportSession *__nonnull)assetExportSession shouldReginReadWriteOnInput:(AVAssetWriterInput *__nonnull)writerInput fromOutput:(AVAssetReaderOutput *__nonnull)output;

- (BOOL)assetExportSessionNeedsInputPixelBufferAdaptor:(SCAssetExportSession *__nonnull)assetExportSession;

@end

@interface SCAssetExportSession : NSObject

/**
 The input asset to use
 */
@property (strong, nonatomic) AVAsset *__nullable inputAsset;

/**
 The outputUrl to which the asset will be exported
 */
@property (strong, nonatomic) NSURL *__nullable outputUrl;

/**
 The type of file to be written by the export session
 */
@property (strong, nonatomic) NSString *__nullable outputFileType;

/**
 If true, the export session will use the GPU for rendering the filters
 */
@property (assign, nonatomic) BOOL useGPUForRenderingFilters;

/**
 Access the configuration for the video.
 */
@property (readonly, nonatomic) SCVideoConfiguration *__nonnull videoConfiguration;

/**
 Access the configuration for the audio.
 */
@property (readonly, nonatomic) SCAudioConfiguration *__nonnull audioConfiguration;

/**
 If an error occured during the export, this will contain that error
 */
@property (readonly, nonatomic) NSError *__nullable error;

/**
 The timeRange to read from the inputAsset
 */
@property (assign, nonatomic) CMTimeRange timeRange;

/**
 The current progress
 */
@property (readonly, nonatomic) float progress;


@property (weak, nonatomic) __nullable id<SCAssetExportSessionDelegate> delegate;

- (nonnull instancetype)init;

// Init with the inputAsset
- (nonnull instancetype)initWithAsset:(AVAsset *__nonnull)inputAsset;

/**
 Starts the asynchronous execution of the export session
 */
- (void)exportAsynchronouslyWithCompletionHandler:(void(^__nullable)())completionHandler;

@end
