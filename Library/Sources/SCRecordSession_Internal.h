//
//  SCRecordSession_Internal.h
//  SCRecorder
//
//  Created by Simon CORSIN on 24/11/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import "SCRecorder.h"
#import "SCRecordSession.h"

@interface SCRecordSession() {
    AVAssetWriter *_assetWriter;
    AVAssetWriterInput *_videoInput;
    AVAssetWriterInput *_audioInput;
    NSMutableArray *_recordSegments;
    BOOL _audioInitializationFailed;
    BOOL _videoInitializationFailed;
    BOOL _recordSegmentReady;
    BOOL _currentSegmentHasVideo;
    BOOL _currentSegmentHasAudio;
    int _currentSegmentCount;
    CMTime _timeOffset;
    CMTime _lastTimeAudio;
    
    SCVideoConfiguration *_videoConfiguration;
    SCAudioConfiguration *_audioConfiguration;
    
    // Used when SCFilterGroup is non-nil
    CIContext *_CIContext;
    AVAssetWriterInputPixelBufferAdaptor *_videoPixelBufferAdaptor;
    CMTime _lastTimeVideo;
    
    // Used when the fastRecordMethod is enabled
    AVCaptureMovieFileOutput *_movieFileOutput;
}

@property (weak, nonatomic) SCRecorder *recorder;

@property (readonly, nonatomic) BOOL videoInitialized;
@property (readonly, nonatomic) BOOL audioInitialized;
@property (readonly, nonatomic) BOOL videoInitializationFailed;
@property (readonly, nonatomic) BOOL audioInitializationFailed;
@property (readonly, nonatomic) BOOL recordSegmentReady;
@property (readonly, nonatomic) BOOL currentSegmentHasAudio;
@property (readonly, nonatomic) BOOL currentSegmentHasVideo;
@property (readonly, nonatomic) BOOL isUsingMovieFileOutput;

- (void)initializeVideo:(NSDictionary *)videoOptions formatDescription:(CMFormatDescriptionRef)formatDescription error:(NSError **)error;
- (void)initializeAudio:(NSDictionary *)audioOptions formatDescription:(CMFormatDescriptionRef)formatDescription error:(NSError **)error;

- (BOOL)appendVideoSampleBuffer:(CMSampleBufferRef)videoSampleBuffer duration:(CMTime)duration;
- (BOOL)appendAudioSampleBuffer:(CMSampleBufferRef)audioSampleBuffer;
- (void)beginRecordSegmentUsingMovieFileOutput:(AVCaptureMovieFileOutput *)movieFileOutput error:(NSError **)error delegate:(id<AVCaptureFileOutputRecordingDelegate>)delegate;

- (void)appendRecordSegment:(void(^)(NSInteger segmentNumber, NSError* error))completionHandler error:(NSError *)error url:(NSURL *)url duration:(CMTime)duration;

@end
