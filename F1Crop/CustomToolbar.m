//
//  CustomToolbar.m
//  F1Crop
//
//  Created by Mohammad Dawi on 06/02/2026.
//  Copyright © 2026 Mohammad Dawi. All rights reserved.
//


#import "CustomToolbar.h"

@implementation CustomToolbar

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize newSize = [super sizeThatFits:size];
    newSize.height = 100.0; // Set your desired height here
    return newSize;
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(UIViewNoIntrinsicMetric, 100.0);
}

- (void)layoutSubviews {
    [super layoutSubviews]; // Do NOT manually move subviews
}


@end
