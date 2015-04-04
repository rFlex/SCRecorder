//
//  SCWeakSelectorTarget.m
//  SCRecorder
//
//  Created by Simon CORSIN on 04/04/15.
//  Copyright (c) 2015 rFlex. All rights reserved.
//

#import "SCWeakSelectorTarget.h"

@implementation SCWeakSelectorTarget

- (instancetype)initWithTarget:(id)target targetSelector:(SEL)sel {
    self = [super init];
    
    if (self) {
        _target = target;
        _targetSelector = sel;
    }
    
    return self;
}

- (BOOL)sendMessageToTarget:(id)param {
    id strongTarget = _target;
    
    if (strongTarget != nil) {
        [strongTarget performSelector:_targetSelector withObject:param];
        
        return YES;
    }
    
    return NO;
}

- (SEL)handleSelector {
    return @selector(sendMessageToTarget:);
}

@end
