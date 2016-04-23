//
//  UIImage+SCSaveToCameraRoll.h
//  SCRecorder
//
//  Created by Simon Corsin on 10/12/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (SCSaveToCameraRoll)

- (void)saveToCameraRollWithCompletion:(void (^__nullable)(NSError * _Nullable error))completion;

@end
