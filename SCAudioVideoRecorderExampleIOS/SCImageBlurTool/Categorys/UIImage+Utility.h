//
//  UIImage+Utility.h
//  iyilunba
//
//  Created by 曾 宪华 on 13-12-4.
//  Copyright (c) 2013年 曾 宪华 开发团队(http://iyilunba.com ). All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Utility)
+ (UIImage*)fastImageWithData:(NSData*)data;
+ (UIImage*)fastImageWithContentsOfFile:(NSString*)path;

- (UIImage*)deepCopy;

- (UIImage*)resize:(CGSize)size;
- (UIImage*)aspectFit:(CGSize)size;
- (UIImage*)aspectFill:(CGSize)size;
- (UIImage*)aspectFill:(CGSize)size offset:(CGFloat)offset;

- (UIImage*)crop:(CGRect)rect;

- (UIImage*)maskedImage:(UIImage*)maskImage;

- (UIImage*)gaussBlur:(CGFloat)blurLevel;       //  {blurLevel | 0 ≤ t ≤ 1}

@end
