//
//  canvas.h
//  cropImageWithoutCV_1
//
//  Created by Mohammad Dawi on 9/10/14.
//  Copyright (c) 2014 Mohammad Dawi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <opencv2/opencv.hpp>
#import "Constants.h"
#import "UIImage+ImageBlur.h"

using namespace cv;
typedef cv::vector<cv::vector<cv::Point>> TContours;
typedef vector<vector<cv::Point>> SPolygon;

@interface canvas : UIView<UIScrollViewDelegate,UIGestureRecognizerDelegate>{
    ShapeType shapeType;
    
    CGPoint location;
    CGPoint currentLocation;
    CGRect  currentRect;
    CGRect  frameRect;
    UIImage *image;
    vector<UIImage*> imageBkp;
    NSMutableArray* imagesArray;
    
    UIImage *croppedImage;
    CGImageRef imageRef;
    NSString *dpath;
    UIImageView *imageView;
    int flag;
    cv::Mat markerMask;
    CGContextRef context;
    BOOL haveSave;
    UIBezierPath *path;
    TContours contoursTouchDraw;
    TContours contoursTouchDrawFrame;
    vector<cv::Point> tmpContour;
    vector<cv::Point> tmpContourFrame;
    int contoursTouchCounter;
    vector<cv::Rect> contoursTouchRect;
    vector<cv::Rect> contoursTouchRectFrame;
    IBOutlet UIBarButtonItem* drawingSelection;
    UIScrollView *rootSV;
    cv::Point p,pf;
    double ratioW;
    double ratioH;
    int draggable;
    
    
}
@property CGPoint location;
@property CGPoint currentLocation;
@property CGRect currentRect;
@property CGRect frameRect;
@property (nonatomic, retain) UIImage *image;
@property  vector<UIImage*> imageBkp;
@property (nonatomic, retain) UIImage *croppedImage;
@property(nonatomic, assign) int flag;
@property(nonatomic, assign) int draggable;
@property (nonatomic, retain) UIImageView *imageView;
@property cv::Mat markerMask;
@property CGContextRef context;
@property CGImageRef imageRef;
@property (nonatomic, retain) NSString *dpath;
@property BOOL haveSave;
@property ShapeType shapeType;
@property (nonatomic, retain) UIBezierPath *path;
@property  TContours contoursTouchDraw;
@property  TContours contoursTouchDrawFrame;
@property  vector<cv::Point> tmpContour;
@property  vector<cv::Point> tmpContourFrame;
@property(nonatomic, assign) int contoursTouchCounter;
@property  vector<cv::Rect> contoursTouchRect;
@property  vector<cv::Rect> contoursTouchRectFrame;
@property UIScrollView *rootSV;
@property cv::Point p,pf;
@property (nonatomic, assign) double ratioW;
@property (nonatomic, assign) double ratioH;
@property (retain, nonatomic) NSMutableArray* imagesArray;

//- (IBAction)processDrawingSelection:(id)sender;
- (UIViewController *) firstAvailableUIViewController;
- (UIViewController *) app_viewController;
- (id) traverseResponderChainForUIViewController;
- (CGRect)drawText:(CGFloat)xPosition yPosition:(CGFloat)yPosition canvasWidth:(CGFloat)canvasWidth canvasHeight:(CGFloat)canvasHeight text:(NSString*)txt;
//- (UIImage *)croppIngimageByImageName:(UIImage *)imageToCrop toRect:(CGRect)rect;
-(CGRect) translateRect:(CGRect) rect toOrigin:(CGPoint)np fromOrigin:(CGPoint)op;

@end

