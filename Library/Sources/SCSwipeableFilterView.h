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

@class SCSwipeableFilterView;
@protocol SCSwipeableFilterViewDelegate <NSObject>

- (void)swipeableFilterView:(SCSwipeableFilterView *__nonnull)swipeableFilterView didScrollToFilter:(SCFilter *__nullable)filter;

@end

/**
 A filter selector view that works like the Snapchat presentation of the available filters.
 Filters are swipeable from horizontally.
 */
@interface SCSwipeableFilterView : SCFilterSelectorView<UIScrollViewDelegate>

/**
 The delegate that will receive messages
 */
@property (weak, nonatomic) id<SCSwipeableFilterViewDelegate> __nullable delegate;

/**
 The underlying scrollView used for scrolling between filterGroups.
 You can freely add your views inside.
 */
@property (readonly, nonatomic) UIScrollView *__nonnull selectFilterScrollView;

/**
 Whether the current image should be redraw with the new contentOffset
 when the UIScrollView is scrolled. If disabled, scrolling will never
 show up the other filters, until it receives a new CIImage.
 On some device it seems better to disable it when the SCSwipeableFilterView
 is set inside a SCPlayer.
 Default is YES
 */
@property (assign, nonatomic) BOOL refreshAutomaticallyWhenScrolling;

/**
 Scrolls to a specific filter
 */
- (void)scrollToFilter:(SCFilter *__nonnull)filter animated:(BOOL)animated;

@end
