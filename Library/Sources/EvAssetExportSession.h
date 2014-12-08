//
//  EvAssetExporter.h
//  MindieObjC
//
//  Created by Simon CORSIN on 17/04/14.
//  Copyright (c) 2014 Mindie. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import "SCAssetExportSession.h"

@interface EvAssetExportSession : SCAssetExportSession

@property (assign, nonatomic) BOOL reverseVideo;

@end
