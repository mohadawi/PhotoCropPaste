//
//  UIImage-Orientation.h
//  opencv1
//
//  Created by Mohammad Dawi on 1/18/15.
//  Copyright (c) 2015 Mohammad Dawi. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage(Orientation)

- (UIImage*)imageAdjustedForOrientation;
-(UIImage*)fixOrientation;

@end
