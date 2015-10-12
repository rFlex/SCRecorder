//
//  UIImage+SCSaveToCameraRoll.m
//  SCRecorder
//
//  Created by Simon Corsin on 10/12/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import "UIImage+SCSaveToCameraRoll.h"
#import "SCSaveToCameraRollOperation.h"

@implementation UIImage (SCSaveToCameraRoll)

- (void)saveToCameraRollWithCompletion:(void (^)(NSError * _Nullable))completion {
    SCSaveToCameraRollOperation *saveToCameraRoll = [SCSaveToCameraRollOperation new];
    [saveToCameraRoll saveImage:self completion:completion];
}

@end
