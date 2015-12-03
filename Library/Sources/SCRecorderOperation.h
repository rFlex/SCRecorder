//
//  SCRecorderOperation.h
//  SCRecorder
//
//  Created by Simon Corsin on 12/3/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SCRecorderOperation;
@protocol SCRecorderOperationDelegate <NSObject>

- (void)recorderOperationDidComplete:(SCRecorderOperation *)recorderOperation;

@end

/**
 Facilitates asynchronous tasks. Doesn't use NSOperation for the sake
 of simplicity.
 */
@interface SCRecorderOperation : NSObject

@property (weak, nonatomic) id<SCRecorderOperationDelegate> delegate;
@property (readonly, nonatomic) BOOL completed;
@property (readonly, nonatomic) BOOL executing;
@property (readonly, nonatomic) void (^block)();
@property (readonly, nonatomic) NSInteger asyncCount;

- (instancetype)initWithBlock:(void(^)(SCRecorderOperation *operation))block;

- (void)start;

/**
 Notify that the operation has started a dependant asynchronous task.
 The operation won't be marked as completed until all asyncBegan have
 been paired with asyncEnded.
 */
- (void)asyncBegan;

/**
 Notify that a previously started dependant asynchronous task finished.
 This will mark the operation as completed asyncCount reaches zero.
 */
- (void)asyncEnded;

@end
