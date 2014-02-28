//
//  SCImageBlurTool.m
//  iyilunba
//
//  Created by 曾 宪华 on 13-12-4.
//  Copyright (c) 2013年 曾 宪华 开发团队(http://iyilunba.com ). All rights reserved.
//

#import "SCImageBlurTool.h"
#import "UIImage+Utility.h"
#import "UIView+Frame.h"
#import "SCBlurCircle.h"
#import "SCBlurBand.h"
#import "SCImageBlurHeader.h"

@interface SCImageBlurTool () <UIGestureRecognizerDelegate> {
    UIImage *_originalImage;
    UIImage *_thumnailImage;
    UIImage *_blurImage;
    
    UISlider *_blurSlider;
    UIScrollView *_menuScroll;
    
    UIView *_handlerView;
    
    SCBlurCircle *_circleView;
    SCBlurBand *_bandView;
    CGRect _bandImageRect;
    
    SCBlurType _blurType;
}
@property (nonatomic, weak) UIViewController *editor;
@property (nonatomic, weak) UIImageView *editorImageView;
@property (nonatomic, strong) UIView *selectedMenu;
@end

@implementation SCImageBlurTool

- (id)initWithImageEditor:(UIViewController *)editor {
    self = [super init];
    if (self) {
        self.editor = editor;
        self.editorImageView = [self.editor valueForKey:@"disPlayImageView"];
    }
    return self;
}

#pragma mark-

+ (NSString*)defaultTitle
{
    return @"Blur";
}

+ (BOOL)isAvailable
{
    return YES;
}

- (void)setup
{
    CGRect menuScrollViewFrame = self.editor.view.frame;
    menuScrollViewFrame.size.height = 50;
    menuScrollViewFrame.origin.y = CGRectGetHeight([[UIScreen mainScreen] bounds]) - 50;
    
    _blurType = kSCBlurTypeNormal;
    _originalImage = self.editorImageView.image;
    _thumnailImage = [_originalImage resize:self.editorImageView.frame.size];
    
    
    _handlerView = [[UIView alloc] initWithFrame:self.editorImageView.frame];
    [self.editorImageView.superview addSubview:_handlerView];
    [self setHandlerView];
    
    _blurSlider = [self sliderWithValue:0.5 minimumValue:0 maximumValue:1];
    _blurSlider.superview.center = CGPointMake(self.editor.view.frame.size.width/2, 400);
    
    _menuScroll = [[UIScrollView alloc] initWithFrame:menuScrollViewFrame];
    _menuScroll.showsHorizontalScrollIndicator = NO;
    [self.editor.view addSubview:_menuScroll];
    [self setBlurMenu];
    
    _menuScroll.transform = CGAffineTransformMakeTranslation(0, self.editor.view.height-_menuScroll.top);
    [UIView animateWithDuration:kSCImageToolAnimationDuration
                     animations:^{
                         _menuScroll.transform = CGAffineTransformIdentity;
                     }];
    
    [self setDefaultParams];
    [self sliderDidChange:nil];
}

- (void)cleanup
{
    [_blurSlider.superview removeFromSuperview];
    [_handlerView removeFromSuperview];
    
    [UIView animateWithDuration:kSCImageToolAnimationDuration
                     animations:^{
                     }
                     completion:^(BOOL finished) {
                         [_menuScroll removeFromSuperview];
                     }];
}

- (void)executeWithCompletionBlock:(void(^)(UIImage *image, NSError *error, NSDictionary *userInfo))completionBlock
{
    __block UIActivityIndicatorView *indicator = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
        indicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 80, 80)];
        indicator.backgroundColor = [UIColor colorWithWhite:0 alpha:0.6];
        indicator.layer.cornerRadius = 5;
        indicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
        indicator.center = CGPointMake(_handlerView.width/2, _handlerView.height/2);
        [_handlerView addSubview:indicator];
        [indicator startAnimating];
    });
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *blurImage = [_originalImage gaussBlur:_blurSlider.value];
        UIImage *image = [self buildResultImage:_originalImage withBlurImage:blurImage];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [indicator stopAnimating];
            [indicator removeFromSuperview];
            completionBlock(image, nil, nil);
        });
    });
}

#pragma mark-

- (void)setBlurMenu
{
    CGFloat W = 70;
    CGFloat x = 0;
    
    NSArray *_menu = @[
                       @{@"title":@"Normal", @"icon":[NSString stringWithFormat:@"icon_normal.png"]},
                       @{@"title":@"Circle", @"icon":[NSString stringWithFormat:@"icon_circle.png"]},
                       @{@"title":@"Band", @"icon":[NSString stringWithFormat:@"icon_band.png"]},
                       ];
    
    NSInteger tag = 0;
    for(NSDictionary *obj in _menu){
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(x, 0, W, _menuScroll.height)];
        view.tag = tag++;
        
        UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 5, 50, 50)];
        iconView.clipsToBounds = YES;
        iconView.layer.cornerRadius = 2;
        iconView.image = [UIImage imageNamed:obj[@"icon"]];
        [view addSubview:iconView];
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, W-10, W, 15)];
        label.backgroundColor = [UIColor clearColor];
        label.text = obj[@"title"];
        label.font = [UIFont systemFontOfSize:10];
        label.textAlignment = NSTextAlignmentCenter;
        [view addSubview:label];
        
        UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedBlurMenu:)];
        [view addGestureRecognizer:gesture];
        
        if(self.selectedMenu==nil){
            self.selectedMenu = view;
        }
        
        [_menuScroll addSubview:view];
        x += W;
    }
    _menuScroll.contentSize = CGSizeMake(MAX(x, _menuScroll.frame.size.width+1), 0);
}

- (void)setSelectedMenu:(UIView *)selectedMenu
{
    if(selectedMenu != _selectedMenu){
        _selectedMenu.backgroundColor = [UIColor clearColor];
        _selectedMenu = selectedMenu;
        _selectedMenu.backgroundColor = [[UIColor cyanColor] colorWithAlphaComponent:0.2];
    }
}

- (void)setHandlerView
{
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapHandlerView:)];
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panHandlerView:)];
    UIPinchGestureRecognizer *pinch    = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchHandlerView:)];
    UIRotationGestureRecognizer *rot   = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotateHandlerView:)];
    
    panGesture.maximumNumberOfTouches = 1;
    
    tapGesture.delegate = self;
    //panGesture.delegate = self;
    pinch.delegate = self;
    rot.delegate = self;
    
    [_handlerView addGestureRecognizer:tapGesture];
    [_handlerView addGestureRecognizer:panGesture];
    [_handlerView addGestureRecognizer:pinch];
    [_handlerView addGestureRecognizer:rot];
}

- (void)setDefaultParams
{
    CGFloat W = 1.5*MIN(_handlerView.width, _handlerView.height);
    
    _circleView = [[SCBlurCircle alloc] initWithFrame:CGRectMake(_handlerView.width/2-W/2, _handlerView.height/2-W/2, W, W)];
    _circleView.backgroundColor = [UIColor clearColor];
    _circleView.color = [UIColor whiteColor];
    
    CGFloat H = _handlerView.height;
    CGFloat R = sqrt((_handlerView.width*_handlerView.width) + (_handlerView.height*_handlerView.height));
    
    _bandView = [[SCBlurBand alloc] initWithFrame:CGRectMake(0, 0, R, H)];
    _bandView.center = CGPointMake(_handlerView.width/2, _handlerView.height/2);
    _bandView.backgroundColor = [UIColor clearColor];
    _bandView.color = [UIColor whiteColor];
    
    CGFloat ratio = _originalImage.size.width / self.editorImageView.width;
    _bandImageRect = _bandView.frame;
    _bandImageRect.size.width  *= ratio;
    _bandImageRect.size.height *= ratio;
    _bandImageRect.origin.x *= ratio;
    _bandImageRect.origin.y *= ratio;
    
}

- (UISlider*)sliderWithValue:(CGFloat)value minimumValue:(CGFloat)min maximumValue:(CGFloat)max
{
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(10, 0, 260, 30)];
    
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, slider.height)];
    container.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    container.layer.cornerRadius = slider.height/2;
    
    slider.continuous = NO;
    [slider addTarget:self action:@selector(sliderDidChange:) forControlEvents:UIControlEventValueChanged];
    
    slider.maximumValue = max;
    slider.minimumValue = min;
    slider.value = value;
    
    [container addSubview:slider];
    [self.editor.view addSubview:container];
    
    return slider;
}

- (void)sliderDidChange:(UISlider*)slider
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        _blurImage = [_thumnailImage gaussBlur:_blurSlider.value];
        [self buildThumnailImage];
    });
}

- (void)buildThumnailImage
{
    static BOOL inProgress = NO;
    
    if(inProgress){ return; }
    
    inProgress = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [self buildResultImage:_thumnailImage withBlurImage:_blurImage];
        
        [self.editorImageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:NO];
        inProgress = NO;
    });
}

- (UIImage*)buildResultImage:(UIImage*)image withBlurImage:(UIImage*)blurImage
{
    UIImage *result = blurImage;
    
    switch (_blurType) {
        case kSCBlurTypeCircle:
            result = [self circleBlurImage:image withBlurImage:blurImage];
            break;
        case kSCBlurTypeBand:
            result = [self bandBlurImage:image withBlurImage:blurImage];
            break;
        default:
            break;
    }
    return result;
}

- (UIImage*)blurImage:(UIImage*)image withBlurImage:(UIImage*)blurImage andMask:(UIImage*)maskImage
{
    UIImage *tmp = [image maskedImage:maskImage];
    
    UIGraphicsBeginImageContext(image.size);
    {
        [blurImage drawAtPoint:CGPointZero];
        [tmp drawAtPoint:CGPointZero];
        tmp = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    
    return tmp;
}

- (UIImage*)circleBlurImage:(UIImage*)image withBlurImage:(UIImage*)blurImage
{
    CGFloat ratio = image.size.width / self.editorImageView.width;
    CGRect frame  = _circleView.frame;
    frame.size.width  *= ratio;
    frame.size.height *= ratio;
    frame.origin.x *= ratio;
    frame.origin.y *= ratio;
    
    UIImage *mask = [UIImage imageNamed:@"circle.png"];
    UIGraphicsBeginImageContext(image.size);
    {
        CGContextSetFillColorWithColor(UIGraphicsGetCurrentContext() , [[UIColor whiteColor] CGColor]);
        CGContextFillRect(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, image.size.width, image.size.height));
        [mask drawInRect:frame];
        mask = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    
    return [self blurImage:image withBlurImage:blurImage andMask:mask];
}

- (UIImage*)bandBlurImage:(UIImage*)image withBlurImage:(UIImage*)blurImage
{
    UIImage *mask = [UIImage imageNamed:@"band.png"];
    
    UIGraphicsBeginImageContext(image.size);
    {
        CGContextRef context =  UIGraphicsGetCurrentContext();
        
        CGContextSetFillColorWithColor(context, [[UIColor whiteColor] CGColor]);
        CGContextFillRect(context, CGRectMake(0, 0, image.size.width, image.size.height));
        
        CGContextSaveGState(context);
        CGFloat ratio = image.size.width / _originalImage.size.width;
        CGFloat Tx = (_bandImageRect.size.width/2  + _bandImageRect.origin.x)*ratio;
        CGFloat Ty = (_bandImageRect.size.height/2 + _bandImageRect.origin.y)*ratio;
        
        CGContextTranslateCTM(context, Tx, Ty);
        CGContextRotateCTM(context, _bandView.rotation);
        CGContextTranslateCTM(context, 0, _bandView.offset*image.size.width/_handlerView.width);
        CGContextScaleCTM(context, 1, _bandView.scale);
        CGContextTranslateCTM(context, -Tx, -Ty);
        
        CGRect rct = _bandImageRect;
        rct.size.width  *= ratio;
        rct.size.height *= ratio;
        rct.origin.x    *= ratio;
        rct.origin.y    *= ratio;
        
        [mask drawInRect:rct];
        
        CGContextRestoreGState(context);
        
        mask = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();
    
    return [self blurImage:image withBlurImage:blurImage andMask:mask];
}

#pragma mark- Gesture handler

- (BOOL) gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)tappedBlurMenu:(UITapGestureRecognizer*)sender
{
    UIView *view = sender.view;
    
    self.selectedMenu = view;
    
    view.alpha = 0.2;
    [UIView animateWithDuration:kSCImageToolAnimationDuration
                     animations:^{
                         view.alpha = 1;
                     }
     ];
    
    if(view.tag != _blurType){
        _blurType = view.tag;
        
        [_circleView removeFromSuperview];
        [_bandView removeFromSuperview];
        
        switch (_blurType) {
            case kSCBlurTypeNormal:
                break;
            case kSCBlurTypeCircle:
                [_handlerView addSubview:_circleView];
                [_circleView setNeedsDisplay];
                break;
            case kSCBlurTypeBand:
                [_handlerView addSubview:_bandView];
                [_bandView setNeedsDisplay];
                break;
            default:
                break;
        }
        [self buildThumnailImage];
    }
}

- (void)tapHandlerView:(UITapGestureRecognizer*)sender
{
    switch (_blurType) {
        case kSCBlurTypeCircle:
        {
            CGPoint point = [sender locationInView:_handlerView];
            _circleView.center = point;
            [self buildThumnailImage];
            break;
        }
        case kSCBlurTypeBand:
        {
            CGPoint point = [sender locationInView:_handlerView];
            point = CGPointMake(point.x-_handlerView.width/2, point.y-_handlerView.height/2);
            point = CGPointMake(point.x*cos(-_bandView.rotation)-point.y*sin(-_bandView.rotation), point.x*sin(-_bandView.rotation)+point.y*cos(-_bandView.rotation));
            _bandView.offset = point.y;
            [self buildThumnailImage];
            break;
        }
        default:
            break;
    }
}

- (void)panHandlerView:(UIPanGestureRecognizer*)sender
{
    switch (_blurType) {
        case kSCBlurTypeCircle:
        {
            CGPoint point = [sender locationInView:_handlerView];
            _circleView.center = point;
            [self buildThumnailImage];
            break;
        }
        case kSCBlurTypeBand:
        {
            CGPoint point = [sender locationInView:_handlerView];
            point = CGPointMake(point.x-_handlerView.width/2, point.y-_handlerView.height/2);
            point = CGPointMake(point.x*cos(-_bandView.rotation)-point.y*sin(-_bandView.rotation), point.x*sin(-_bandView.rotation)+point.y*cos(-_bandView.rotation));
            _bandView.offset = point.y;
            [self buildThumnailImage];
            break;
        }
        default:
            break;
    }
}

- (void)pinchHandlerView:(UIPinchGestureRecognizer*)sender
{
    switch (_blurType) {
        case kSCBlurTypeCircle:
        {
            static CGRect initialFrame;
            if (sender.state == UIGestureRecognizerStateBegan) {
                initialFrame = _circleView.frame;
            }
            
            CGFloat scale = sender.scale;
            CGRect rct;
            rct.size.width  = MAX(MIN(initialFrame.size.width*scale, 3*MAX(_handlerView.width, _handlerView.height)), 0.3*MIN(_handlerView.width, _handlerView.height));
            rct.size.height = rct.size.width;
            rct.origin.x = initialFrame.origin.x + (initialFrame.size.width-rct.size.width)/2;
            rct.origin.y = initialFrame.origin.y + (initialFrame.size.height-rct.size.height)/2;
            
            _circleView.frame = rct;
            [self buildThumnailImage];
            break;
        }
        case kSCBlurTypeBand:
        {
            static CGFloat initialScale;
            if (sender.state == UIGestureRecognizerStateBegan) {
                initialScale = _bandView.scale;
            }
            
            _bandView.scale = MIN(2, MAX(0.2, initialScale * sender.scale));
            [self buildThumnailImage];
            break;
        }
        default:
            break;
    }
}

- (void)rotateHandlerView:(UIRotationGestureRecognizer*)sender
{
    switch (_blurType) {
        case kSCBlurTypeBand:
        {
            static CGFloat initialRotation;
            if (sender.state == UIGestureRecognizerStateBegan) {
                initialRotation = _bandView.rotation;
            }
            
            _bandView.rotation = MIN(M_PI/2, MAX(-M_PI/2, initialRotation + sender.rotation));
            [self buildThumnailImage];
            break;
        }
        default:
            break;
    }
    
}

@end
