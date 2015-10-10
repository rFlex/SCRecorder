//
//  NSURL+SCSaveToCameraRoll.h
//  SCRecorder
//
//  Created by Simon Corsin on 10/10/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (SCSaveToCameraRoll)

- (void)saveToCameraRollWithCompletion:(void (^)(NSString * _Nullable, NSError * _Nullable))completion;

@end
