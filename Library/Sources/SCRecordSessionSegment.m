//
//  SCRecordSessionSegment.m
//  SCRecorder
//
//  Created by Simon CORSIN on 10/03/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import "SCRecordSessionSegment.h"

@interface SCRecordSessionSegment() {
    AVAsset *_asset;
    UIImage *_thumbnail;
    UIImage *_lastImage;
}

@end

@implementation SCRecordSessionSegment

- (instancetype)initWithURL:(NSURL *)url info:(NSDictionary *)info {
    self = [self init];
    
    if (self) {
        _url = url;
        _info = info;
    }
    
    return self;
}

- (void)deleteFile {
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:_url error:&error];
    _url = nil;
    _asset = nil;
}

- (AVAsset *)asset {
    if (_asset == nil) {
        _asset = [AVAsset assetWithURL:_url];
    }
    
    return _asset;
}

- (CMTime)duration {
    return [self asset].duration;
}

- (UIImage *)thumbnail {
    if (_thumbnail == nil) {
        AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:self.asset];
        imageGenerator.appliesPreferredTrackTransform = YES;
        
        NSError *error = nil;
        CGImageRef thumbnailImage = [imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:nil error:&error];
        
        if (error == nil) {
            _thumbnail = [UIImage imageWithCGImage:thumbnailImage];
        } else {
            NSLog(@"Unable to generate thumbnail for %@: %@", self.url, error.localizedDescription);
        }
    }
    
    return _thumbnail;
}

- (UIImage *)lastImage {
    if (_lastImage == nil) {
        AVAssetImageGenerator *imageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:self.asset];
        imageGenerator.appliesPreferredTrackTransform = YES;
        
        NSError *error = nil;
        CGImageRef lastImage = [imageGenerator copyCGImageAtTime:self.duration actualTime:nil error:&error];
        
        if (error == nil) {
            _lastImage = [UIImage imageWithCGImage:lastImage];
        } else {
            NSLog(@"Unable to generate lastImage for %@: %@", self.url, error.localizedDescription);
        }
    }
    
    return _lastImage;
}

- (float)frameRate {
    NSArray *tracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
    
    if (tracks.count == 0) {
        return 0;
    }
    
    AVAssetTrack *videoTrack = [tracks firstObject];
    
    return videoTrack.nominalFrameRate;
}

+ (SCRecordSessionSegment *)segmentWithURL:(NSURL *)url info:(NSDictionary *)info {
    return [[SCRecordSessionSegment alloc] initWithURL:url info:info];
}

@end
