//
//  NSURL+SCSaveToCameraRoll.m
//  SCRecorder
//
//  Created by Simon Corsin on 10/10/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NSURL+SCSaveToCameraRoll.h"

@interface SCSaveToCameraRollOperation : NSObject

@property (strong, nonatomic) void (^completion)(NSString *, NSError *);



@end

@implementation SCSaveToCameraRollOperation

static NSMutableArray *pendingOperations = nil;

- (void)saveFromURL:(NSURL *)url completion:(void(^)(NSString *, NSError *))completion {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pendingOperations = [NSMutableArray new];
    });

    @synchronized(pendingOperations) {
        [pendingOperations addObject:self];
    }
    self.completion = completion;

    UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    @synchronized(pendingOperations) {
        [pendingOperations removeObject:self];
    }
    void (^completion)(NSString *, NSError *) = self.completion;
    self.completion = nil;

    if (completion != nil) {
        completion(videoPath, error);
    }
}

@end

@implementation NSURL (SCSaveToCameraRoll)

- (void)saveToCameraRollWithCompletion:(void (^)(NSString * _Nullable path, NSError * _Nullable error))completion {
    SCSaveToCameraRollOperation *saveToCameraRoll = [SCSaveToCameraRollOperation new];
    [saveToCameraRoll saveFromURL:self completion:completion];
}

@end
