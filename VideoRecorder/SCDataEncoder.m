//
//  SCDataEncoder.m
//  SCVideoRecorder
//
//  Created by Simon CORSIN on 8/6/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "SCDataEncoder.h"
#import "SCAudioVideoRecorderInternal.h"

////////////////////////////////////////////////////////////
// PRIVATE DEFINITION
/////////////////////

@interface SCDataEncoder() {
    
}

@property (weak, nonatomic) SCAudioVideoRecorder * audioVideoRecorder;

@end

////////////////////////////////////////////////////////////
// IMPLEMENTATION
/////////////////////

@implementation SCDataEncoder {
    CMTime lastTakenFrame;
    BOOL initialized;
}

@synthesize useInputFormatTypeAsOutputType;
@synthesize writerInput;
@synthesize audioVideoRecorder;

- (id) initWithAudioVideoRecorder:(SCAudioVideoRecorder *)aVR {
    if (self) {
        self.audioVideoRecorder = aVR;
        self.enabled = YES;
        self.useInputFormatTypeAsOutputType = YES;
        lastTakenFrame = CMTimeMake(0, 1);
        initialized = NO;
    }
    return self;
}

- (void) dealloc {
    self.writerInput = nil;
}

- (AVAssetWriterInput*) createWriterInputForSampleBuffer:(CMSampleBufferRef)sampleBuffer error:(NSError **)error {
    *error = [SCAudioVideoRecorder createError:@"Inherited objects must override createWriterInput"];
    return nil;
}

- (void) reset {
    if (self.writerInput != nil) {
        self.writerInput = nil;
        if ([self.delegate respondsToSelector:@selector(dataEncoder:didEncodeFrame:)]) {
            [self.delegate dataEncoder:self didEncodeFrame:0];
        }
    }
    initialized = NO;
    lastTakenFrame = CMTimeMake(0, 1);
}

//
// The following function is from http://www.gdcl.co.uk/2013/02/20/iPhone-Pause.html
//
- (CMSampleBufferRef) adjustBuffer:(CMSampleBufferRef)sample withTimeOffset:(CMTime)offset {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}

- (void) initialize:(CMSampleBufferRef)sampleBuffer atFrameTime:(CMTime)frameTime {
    initialized = YES;
    lastTakenFrame = frameTime;
    NSError * error = nil;
    self.writerInput = [self createWriterInputForSampleBuffer:sampleBuffer error:&error];
    
    if (self.writerInput == nil && error == nil) {
        error = [SCAudioVideoRecorder createError:@"Encoder didn't create a WriterInput"];
    }
    
    if (self.writerInput != nil) {
        if ([self.audioVideoRecorder.assetWriter canAddInput:self.writerInput]) {
            [self.audioVideoRecorder.assetWriter addInput:self.writerInput];
        } else {
            error = [SCAudioVideoRecorder createError:@"Unable to add WriterInput to the AssetWriter"];
        }
    }
    
    if (error != nil) {
        if ([self.delegate respondsToSelector:@selector(dataEncoder:didFailToInitializeEncoder:)]) {
            [self.delegate dataEncoder:self didFailToInitializeEncoder:error];
        }
    }
}

- (void) computeOffset:(CMTime)frameTime {
    audioVideoRecorder.shouldComputeOffset = NO;
    
    if (CMTIME_IS_VALID(lastTakenFrame)) {
        CMTime offset = CMTimeSubtract(frameTime, lastTakenFrame);
        
        CMTime currentTimeOffset = audioVideoRecorder.currentTimeOffset;
        currentTimeOffset = CMTimeAdd(currentTimeOffset, offset);
        audioVideoRecorder.currentTimeOffset = CMTimeSubtract(currentTimeOffset, audioVideoRecorder.lastFrameTimeBeforePause);
    }
}

- (void) captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if (!self.enabled) {
        return;
    }
    CMTime frameTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    
    if ([audioVideoRecorder isPrepared] && [audioVideoRecorder isRecording]) {
        
        if (!initialized) {
            [self initialize:sampleBuffer atFrameTime:frameTime];
        }
        
        [audioVideoRecorder prepareWriterAtSourceTime:frameTime fromEncoder:self];
        
        if ([self.writerInput isReadyForMoreMediaData]) {
            if (audioVideoRecorder.shouldComputeOffset) {
                [self computeOffset:frameTime];
            }
            
            CMSampleBufferRef adjustedBuffer = [self adjustBuffer:sampleBuffer withTimeOffset:audioVideoRecorder.currentTimeOffset];
            
            CMTime currentTime = CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(adjustedBuffer), audioVideoRecorder.startedTime);
            [self.writerInput appendSampleBuffer:adjustedBuffer];
            CFRelease(adjustedBuffer);
            
            if ([self.delegate respondsToSelector:@selector(dataEncoder:didEncodeFrame:)]) {
                [self.delegate dataEncoder:self didEncodeFrame:CMTimeGetSeconds(currentTime)];
            }
        }
        lastTakenFrame = frameTime;
    }
}

@end