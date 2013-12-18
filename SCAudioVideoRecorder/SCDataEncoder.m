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

@synthesize writerInput;
@synthesize audioVideoRecorder;

- (id) initWithAudioVideoRecorder:(SCAudioVideoRecorder *)aVR {
    if (self) {
        self.audioVideoRecorder = aVR;
        self.enabled = YES;
        lastTakenFrame = kCMTimeInvalid;
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
            [self.delegate dataEncoder:self didEncodeFrame:kCMTimeZero];
        }
    }
    initialized = NO;
    lastTakenFrame = kCMTimeInvalid;
}

//
// The following function is from http://www.gdcl.co.uk/2013/02/20/iPhone-Pause.html
//
- (CMSampleBufferRef) adjustBuffer:(CMSampleBufferRef)sample withTimeOffset:(CMTime)offset andDuration:(CMTime)duration {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
        pInfo[i].duration = duration;
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
    CMTime realDuration = CMSampleBufferGetDuration(sampleBuffer);
    
	if ([audioVideoRecorder isPrepared]) {
		if (!initialized) {
            [self initialize:sampleBuffer atFrameTime:frameTime];
			[audioVideoRecorder prepareWriterAtSourceTime:frameTime fromEncoder:self];
			
			audioVideoRecorder.shouldComputeOffset = YES;
			lastTakenFrame = frameTime;
			// We always skip the first frame
			return;
        }
		
		if ([audioVideoRecorder isRecording]) {
			if ([self.writerInput isReadyForMoreMediaData]) {
				if (audioVideoRecorder.shouldComputeOffset) {
					[self computeOffset:frameTime];
                    lastTakenFrame = kCMTimeInvalid;
				}
                
                CMTime duration = kCMTimeZero;
                if (CMTIME_IS_VALID(lastTakenFrame)) {
                    duration = CMTimeSubtract(frameTime, lastTakenFrame);
                }
  
                CMTime computedFrameDuration = CMTimeMultiplyByFloat64(duration, self.audioVideoRecorder.recordingRate);
                CMTime timeOffset = CMTimeSubtract(duration, computedFrameDuration);
                self.audioVideoRecorder.currentTimeOffset = CMTimeAdd(audioVideoRecorder.currentTimeOffset, timeOffset);
				
				CMSampleBufferRef adjustedBuffer = [self adjustBuffer:sampleBuffer withTimeOffset:audioVideoRecorder.currentTimeOffset andDuration:realDuration];
				
				CMTime currentTime = CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(adjustedBuffer), audioVideoRecorder.startedTime);
				[self.writerInput appendSampleBuffer:adjustedBuffer];
				CFRelease(adjustedBuffer);
				
				if ([self.delegate respondsToSelector:@selector(dataEncoder:didEncodeFrame:)]) {
					[self.delegate dataEncoder:self didEncodeFrame:currentTime];
				}
			}
            lastTakenFrame = frameTime;
		}
	}
}

@end