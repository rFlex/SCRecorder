//
//  SCFilterSwitcherView.h
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 29/05/14.
//
//

#import <UIKit/UIKit.h>
#import "SCPlayer.h"
#import "SCFilterGroup.h"

// Display a Snapchat like presentation of the available
// filters and let the user choose one
@interface SCFilterSwitcherView : UIView<SCPlayerDelegate, GLKViewDelegate, UIScrollViewDelegate>

// The available filterGroups that this SCFilterSwitcherView shows
// If you want to show an empty filter (no processing), just add a [NSNull null]
// entry instead of an instance of SCFilterGroup
@property (strong, nonatomic) NSArray *filterGroups;

// The player to which this view should take the video frames from
@property (strong, nonatomic) SCPlayer *player;

// The image to which the filters must be applied. If a player is set, this will be automatically
// updated according to the current displayed player image
@property (strong, nonatomic) CIImage *image;

// The currently selected filter group
@property (readonly, nonatomic) SCFilterGroup *selectedFilterGroup;

// The underlying scrollView used for scrolling between filterGroups
@property (readonly, nonatomic) UIScrollView *selectFilterScrollView;

@property (assign, nonatomic) BOOL disabled;

@end
