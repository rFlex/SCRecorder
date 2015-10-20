//
//  SCSaveToCameraRollOperation.m
//  SCRecorder
//
//  Created by Simon Corsin on 10/12/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SCSaveToCameraRollOperation.h"

@interface SCSaveToCameraRollOperation ()

@property (strong, nonatomic) void (^videoCompletion)(NSString *, NSError *);
@property (strong, nonatomic) void (^imageCompletion)(NSError *);

@end

@implementation SCSaveToCameraRollOperation

#pragma mark - Public API

- (void)saveVideoURL:(NSURL *)url completion:(void (^)(NSString *, NSError *))completion {
    self.videoCompletion = completion;
    [self _didStart];

    UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
}

- (void)saveImage:(UIImage *)image completion:(void (^)(NSError *))completion {
    self.imageCompletion = completion;
    [self _didStart];

    UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
}

#pragma mark - Save completions

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    [self _didEnd];

    void (^completion)(NSString *, NSError *) = self.videoCompletion;
    self.videoCompletion = nil;

    if (completion != nil) {
        completion(videoPath, error);
    }
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    [self _didEnd];

    void (^completion)(NSError *) = self.imageCompletion;
    self.imageCompletion = nil;

    if (completion != nil) {
        completion(error);
    }
}

#pragma mark - Private API

static NSMutableArray *pendingOperations = nil;

- (void)_didStart {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pendingOperations = [NSMutableArray new];
    });

    @synchronized(pendingOperations) {
        [pendingOperations addObject:self];
    }
}

- (void)_didEnd {
    @synchronized(pendingOperations) {
        [pendingOperations removeObject:self];
    }
}

@end
