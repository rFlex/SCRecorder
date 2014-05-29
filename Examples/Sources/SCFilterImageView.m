//
//  SCFilterImageView.m
//  SCRecorderExamples
//
//  Created by Simon CORSIN on 28/05/14.
//
//

#import "SCFilterImageView.h"

@implementation SCFilterImageView

static CGRect CGRectMultiply(CGRect rect, CGFloat scale) {
    rect.origin.x *= scale;
    rect.origin.y *= scale;
    rect.size.width *= scale;
    rect.size.height *= scale;
    
    return rect;
}

static CGRect CGRectTranslate(CGRect rect, CGFloat width, CGFloat maxWidth) {
    rect.origin.x += width;
    
    if (rect.origin.x < 0) {
        rect.size.width += rect.origin.x;
        rect.origin.x = 0;
    }

    if (rect.size.width > maxWidth) {
        rect.size.width = maxWidth;
    }
    
    return rect;
}

- (void)drawRect:(CGRect)rect {
    CIImage *outputImage = self.image;
    if (outputImage != nil) {
        CGFloat contentScale = self.contentScaleFactor;
        CGRect extent = self.imageSize;
        CIContext *context = self.ciContext;
        rect = CGRectMultiply(rect, contentScale);
        
        CGFloat ratio = _filterGroupIndexRatio;
        
        NSInteger index = (NSInteger)ratio;
        NSInteger upIndex = (NSInteger)ceilf(ratio);
        CGFloat remainingRatio = ratio - ((CGFloat)index);
        NSArray *filterGroups = _filterGroups;
        
        if (upIndex >= filterGroups.count) {
            upIndex = filterGroups.count - 1;
        } else if (upIndex < 0) {
            upIndex = 0;
        }
        
        if (index >= filterGroups.count) {
            index = filterGroups.count;
        } else if (index < 0) {
            index = 0;
        }
        
        if (index == upIndex) {
            remainingRatio = 0;
        }

        CGFloat xOutputRect = rect.size.width * -remainingRatio;
        CGFloat xImage = extent.size.width * -remainingRatio;
        
        for (NSInteger i = index, count = filterGroups.count; i <= upIndex && i < count; i++) {
            id obj = [filterGroups objectAtIndex:i];
            CIImage *imageToUse = outputImage;
            
            if ([obj isKindOfClass:[SCFilterGroup class]]) {
                imageToUse = [((SCFilterGroup *)obj) imageByProcessingImage:imageToUse];
            }
            
            CGRect outputRect = CGRectTranslate(rect, xOutputRect, rect.size.width);
            CGRect fromRect = CGRectTranslate(extent, xImage, extent.size.width);
            
            [context drawImage:imageToUse inRect:outputRect fromRect:fromRect];
            
            xOutputRect += rect.size.width;
            xImage += extent.size.width;
        }
    }
}

- (void)setFilterGroupIndexRatio:(CGFloat)filterGroupIndexRatio {
    _filterGroupIndexRatio = filterGroupIndexRatio;
    [self setNeedsDisplay];
}

- (void)setFilterGroups:(NSArray *)filterGroups {
    _filterGroups = filterGroups;
    [self setNeedsDisplay];
}

@end
