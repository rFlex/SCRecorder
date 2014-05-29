//
//  SCFilterImageView.h
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 28/05/14.
//
//

#import "SCImageView.h"
#import "SCFilterGroup.h"

@interface SCFilterImageView : SCImageView

@property (strong, nonatomic) NSArray *filterGroups;
@property (assign, nonatomic) CGFloat filterGroupIndexRatio;

@end
