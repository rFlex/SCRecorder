//
//  SCRecorderOperation.m
//  SCRecorder
//
//  Created by Simon Corsin on 12/3/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import "SCRecorderOperation.h"

@implementation SCRecorderOperation

- (instancetype)initWithBlock:(void (^)(SCRecorderOperation *))block {
    self = [super init];

    if (self) {
        _block = block;
    }

    return self;
}

- (void)markCompleted {
    _block = nil;
    _executing = NO;

    if (!_completed) {
        _completed = YES;
        [_delegate recorderOperationDidComplete:self];
    }
}

- (void)asyncBegan {
    _asyncCount++;

    assert(_asyncCount >= 0);
}

- (void)asyncEnded {
    _asyncCount--;

    assert(_asyncCount >= 0);

    if (_asyncCount == 0) {
        [self markCompleted];
    }
}

- (void)start {
    if (_block != nil) {
        [self asyncBegan];
        _executing = YES;
        _block(self);
        _block = nil;

        [self asyncEnded];
    }
}

@end
