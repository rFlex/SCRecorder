//
//  SCSaveToCameraRollOperation.h
//  SCRecorder
//
//  Created by Simon Corsin on 10/12/15.
//  Copyright © 2015 rFlex. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCSaveToCameraRollOperation : NSObject

- (void)saveVideoURL:(NSURL *)url completion:(void(^)(NSString *, NSError *))completion;

- (void)saveImage:(UIImage *)image completion:(void(^)(NSError *))completion;

@end
