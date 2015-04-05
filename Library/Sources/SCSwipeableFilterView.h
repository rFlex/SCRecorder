//
//  SCFilterSwitcherView.h
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 29/05/14.
//
//

#import <UIKit/UIKit.h>
#import "SCPlayer.h"
#import "CIImageRendererUtils.h"
#import "SCFilterSelectorView.h"

/**
 A filter selector view that works like the Snapchat presentation of the available filters.
 Filters are swipeable from horizontally.
 */
@interface SCSwipeableFilterView : SCFilterSelectorView<UIScrollViewDelegate>

/**
 The underlying scrollView used for scrolling between filterGroups.
 You can freely add your views inside.
 */
@property (readonly, nonatomic) UIScrollView *selectFilterScrollView;

/**
 Whether the current image should be redraw with the new contentOffset
 when the UIScrollView is scrolled. If disabled, scrolling will never
 show up the other filters, until it receives a new CIImage.
 On some device it seems better to disable it when the SCSwipeableFilterView
 is set inside a SCPlayer.
 Default is YES
 */
@property (assign, nonatomic) BOOL refreshAutomaticallyWhenScrolling;

@end
