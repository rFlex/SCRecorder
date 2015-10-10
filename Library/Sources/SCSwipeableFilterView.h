//
//  SCFilterSwitcherView.h
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 29/05/14.
//
//

#import <UIKit/UIKit.h>
#import "SCPlayer.h"
#import "SCFilterImageView.h"

@class SCSwipeableFilterView;
@protocol SCSwipeableFilterViewDelegate <NSObject>

- (void)swipeableFilterView:(SCSwipeableFilterView *__nonnull)swipeableFilterView didScrollToFilter:(SCFilter *__nullable)filter;

@end

/**
 A filter selector view that works like the Snapchat presentation of the available filters.
 Filters are swipeable from horizontally.
 */
@interface SCSwipeableFilterView : SCImageView<UIScrollViewDelegate>

/**
 The available filterGroups that this SCFilterSwitcherView shows
 If you want to show an empty filter (no processing), just add a [NSNull null]
 entry instead of an instance of SCFilterGroup
 */
@property (strong, nonatomic) NSArray *__nullable filters;

/**
 The currently selected filter group.
 This changes when scrolling in the underlying UIScrollView.
 This value is Key-Value observable.
 */
@property (strong, nonatomic) SCFilter *__nullable selectedFilter;

/**
 A filter that is applied before applying the selected filter
 */
@property (strong, nonatomic) SCFilter *__nullable preprocessingFilter;

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
