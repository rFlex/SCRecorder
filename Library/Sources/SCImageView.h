//
//  SCCIImageView.h
//  SCRecorder
//
//  Created by Simon CORSIN on 14/05/14.
//  Copyright (c) 2014 rFlex. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

@interface SCImageView : GLKView

@property (strong, nonatomic) CIImage *image;
@property (assign, nonatomic) CGRect imageSize;
@property (readonly, nonatomic) CIContext* ciContext;

@end
