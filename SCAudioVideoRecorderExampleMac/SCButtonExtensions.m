//
//  SCTest.m
//  SCAudioVideoRecorder
//
//  Created by Simon CORSIN on 8/13/13.
//  Copyright (c) 2013 rFlex. All rights reserved.
//

#import "NSButton+SCAdditions.h"

@implementation NSButton(SCorsin)

- (void) addAction:(SEL)action forTarget:(id)target {
    self.action = action;
    self.target = target;
}

@end
