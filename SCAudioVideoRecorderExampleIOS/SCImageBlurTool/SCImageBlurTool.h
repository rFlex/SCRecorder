//
//  SCImageBlurTool.h
//  iyilunba
//
//  Created by 曾 宪华 on 13-12-4.
//  Copyright (c) 2013年 曾 宪华 开发团队(http://iyilunba.com ). All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCImageBlurTool : NSObject

- (id)initWithImageEditor:(UIViewController *)editor;

- (void)setup;
- (void)cleanup;
- (void)executeWithCompletionBlock:(void(^)(UIImage *image, NSError *error, NSDictionary *userInfo))completionBlock;

@end
