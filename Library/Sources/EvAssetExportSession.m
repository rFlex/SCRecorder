//
//  EvAssetExporter.m
//  MindieObjC
//
//  Created by Simon CORSIN on 17/04/14.
//  Copyright (c) 2014 Mindie. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "EvAssetExportSession.h"

#define EnsureSuccess(error, x) if (error != nil) { _error = error; if (x != nil) x(); return; }
#define kVideoPixelFormatType kCVPixelFormatType_32BGRA

#define kAudioFormatType kAudioFormatLinearPCM
// kCVPixelFormatType_422YpCbCr8

@interface EvAssetExportSession() {
    int _fd;
    NSString *_tmpFilePath;
}

@end

@implementation EvAssetExportSession

- (void)beginReadWriteOnInput:(AVAssetWriterInput *)input fromOutput:(AVAssetReaderOutput *)output {
    if (_reverseVideo && input == self.videoInput) {
        [self beginReadWriteReversedOnInput:input fromOutput:output];
    } else {
        [super beginReadWriteOnInput:input fromOutput:output];
    }
}


+ (NSError*)createError:(NSString*)errorDescription {
    return [NSError errorWithDomain:@"EvAssetExportSession" code:200 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
}

- (void)closeAndDestroyTmpFile {
    if (_fd != -1) {
        close(_fd);
        _fd = -1;
    }
    [[NSFileManager defaultManager] removeItemAtPath:_tmpFilePath error:nil];
}

- (void)complete:(AVAssetWriterInput *)input withError:(NSError *)error {
    [self closeAndDestroyTmpFile];
    [self markInputComplete:input error:error];
    
    dispatch_group_leave(self.dispatchGroup);
}

- (void)complete:(AVAssetWriterInput *)input withCVError:(CVReturn)cvReturn {
    NSError *error = [EvAssetExportSession createError:[NSString stringWithFormat:@"Failed to apply reverse: Core Video Error (%d)", (int)cvReturn]];
    [self complete:input withError:error];
}

- (void)completeWithError:(AVAssetWriterInput *)input {
    int errNumber = errno;
    NSError *error = [EvAssetExportSession createError:[NSString stringWithFormat:@"Failed to apply reverse: IOError %d (%s)", errNumber, strerror(errNumber)]];
    [self complete:input withError:error];
}

- (BOOL)needsInputPixelBufferAdaptor {
    return YES;
}

static void EvReleaseBuffer(void *releaseRefCon, const void *baseAddress) {
    free((void *)baseAddress);
}

- (void)beginReadWriteReversedOnInput:(AVAssetWriterInput *)input fromOutput:(AVAssetReaderOutput *)output {
    if (input != nil) {
        dispatch_group_t _dispatchGroup = self.dispatchGroup;
        dispatch_group_enter(_dispatchGroup);
        
        dispatch_queue_t _dispatchQueue = self.dispatchQueue;
        dispatch_async(_dispatchQueue, ^{
            long timeInterval =  (long)[[NSDate date] timeIntervalSince1970];
            _tmpFilePath = [NSString stringWithFormat:@"%@ReversedData_%ld.%@", NSTemporaryDirectory(), timeInterval, @"bin"];
            const char *pathCString = [_tmpFilePath cStringUsingEncoding:NSUTF8StringEncoding];
            
            int fd = open(pathCString, O_RDWR | O_APPEND | O_CREAT | O_TRUNC, S_IRWXU);
            _fd = fd;
            
            if (fd == -1) {
                [self completeWithError:input];
                return;
            }
            
            NSMutableArray *bufferIndexes = [NSMutableArray new];
            CMSampleBufferRef buffer = nil;
            NSUInteger fdOffset = 0;
            
            while ((buffer = [output copyNextSampleBuffer]) != nil) {
                CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(buffer);
                CVPixelBufferLockBaseAddress(pixelBuffer, 0);
                
                CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(buffer);
                uint8_t *data = CVPixelBufferGetBaseAddress(pixelBuffer);
                size_t size = CVPixelBufferGetDataSize(pixelBuffer);
                size_t width = CVPixelBufferGetWidth(pixelBuffer);
                size_t height = CVPixelBufferGetHeight(pixelBuffer);
                OSType pixelFormatType = CVPixelBufferGetPixelFormatType(pixelBuffer);
                size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
                
                [bufferIndexes addObject:@[
                                           [NSNumber numberWithUnsignedInteger:fdOffset],
                                           [NSValue valueWithCMTime:presentationTime],
                                           [NSNumber numberWithUnsignedInteger:size],
                                           [NSNumber numberWithUnsignedInteger:width],
                                           [NSNumber numberWithUnsignedInteger:height],
                                           [NSNumber numberWithUnsignedInteger:pixelFormatType],
                                           [NSNumber numberWithUnsignedInteger:bytesPerRow]
                                           ]];

                while (size > 0) {
                    size_t wrote = write(_fd, data, size);
                    
                    if (wrote == -1) {
                        [self completeWithError:input];
                        CFRelease(buffer);
                        return;
                    }
                    
                    fdOffset += wrote;
                    data += wrote;
                    size -= wrote;
                }
                
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

                CFRelease(buffer);
            }
            
            CMTime timeOffset = ((NSValue *)[((NSArray *)bufferIndexes.lastObject) objectAtIndex:1]).CMTimeValue;
            
            [input requestMediaDataWhenReadyOnQueue:_dispatchQueue usingBlock:^{
                while (input.isReadyForMoreMediaData) {                    
                    if (bufferIndexes.count > 0) {
                        NSArray *values = bufferIndexes.lastObject;
                        [bufferIndexes removeLastObject];
                        
                        NSUInteger fdOffset = ((NSNumber *)[values objectAtIndex:0]).unsignedIntegerValue;
                        CMTime presentationTime = ((NSValue *)[values objectAtIndex:1]).CMTimeValue;
                        NSUInteger size = ((NSNumber *)[values objectAtIndex:2]).unsignedIntegerValue;
                        NSUInteger width = ((NSNumber *)[values objectAtIndex:3]).unsignedIntegerValue;
                        NSUInteger height = ((NSNumber *)[values objectAtIndex:4]).unsignedIntegerValue;
                        NSUInteger pixelFormatType = ((NSNumber *)[values objectAtIndex:5]).unsignedIntegerValue;
                        NSUInteger bytesPerRow = ((NSNumber *)[values objectAtIndex:6]).unsignedIntegerValue;
                        
                        off_t ret = lseek(_fd, fdOffset, SEEK_SET);
                        
                        if (ret == -1) {
                            [self completeWithError:input];
                            break;
                        }
                        
                        void *bufferData = malloc(size);
                        
                        if (bufferData == nil) {
                            [self completeWithError:input];
                            break;
                        }
                        
                        void *bufferPosition = bufferData;
                        size_t toRead = size;
                        
                        while (toRead > 0) {
                            size_t readSize = read(_fd, bufferPosition, toRead);
                            
                            if (readSize == -1) {
                                [self completeWithError:input];
                                break;
                            }
                            
                            bufferPosition += readSize;
                            toRead -= readSize;
                        }
                        
                        CVPixelBufferRef pixelBuffer = nil;
                        CVReturn success = CVPixelBufferCreateWithBytes(nil, width, height, (OSType)pixelFormatType, bufferData, bytesPerRow, &EvReleaseBuffer, nil, nil, &pixelBuffer);
                        
                        if (success != kCVReturnSuccess) {
                            [self complete:input withCVError:success];
                            break;
                        }
                        
                        [self processPixelBuffer:pixelBuffer presentationTime:CMTimeSubtract(timeOffset, presentationTime)];
                        
                        CFRelease(pixelBuffer);
                    } else {
                        [self complete:input withError:nil];
                        
                        break;
                    }
                }
            }];
        });
    }
}

- (void)exportAsynchronouslyWithCompletionHandler:(void (^)())completionHandler {
    if (self.reverseVideo) {
        self.audioConfiguration.shouldIgnore = YES;
    }
    
    [super exportAsynchronouslyWithCompletionHandler:completionHandler];
}

@end
