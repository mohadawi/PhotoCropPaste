//
//  ViewController.h
//  opencv1
//
//  Created by Mohammad Dawi on 6/10/13.
//  Copyright (c) 2013 Mohammad Dawi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "canvas.h"
#import "CvGrabCutController.h"


using namespace cv;
typedef cv::vector<cv::vector<cv::Point> > TContours;
@interface ViewController : UIViewController<UIImagePickerControllerDelegate,UIScrollViewDelegate,UIGestureRecognizerDelegate,UINavigationControllerDelegate>
{
    
    int maximumZoomScale;
    int minimumZoomScale;
    float zoomScaleOldW;
    float zoomScaleOldH;
    int pickBtnFlag;
    CGFloat _lastRotation;
    CGFloat _rotation;
    CGFloat _lastScale;
    CGFloat _firstX;
    CGFloat _firstY;
    
    BOOL image_changed;
    BOOL edit_fg;
    BOOL toogle;
    
    float scale_x;
    float scale_y;
    int rootFlag;
       
    
    UIScrollView *myScrollView;
    UIScrollView *myScrollViewTop;
    
    //UIImageView *imgView;
    ShapeType shapeType;
    
    

    CGPoint location;
    CGRect  imageRect;
    canvas *myView;
    canvas *myViewTop;
    cv::Mat imgFilledContours;//hold the contour image 8U mat
    cv::Mat img,res;//hold the original image mat
    TContours contours;
    CGRect boundRect;
    CvGrabCutController* grabCutController;
    UIImage *image;
    UIImage *imageTop;
    UIImage *imageBackground;
    
    
    IBOutlet UIBarButtonItem* buttonGrabCut;
    IBOutlet UIBarButtonItem* selectDraw;
    UIImagePickerController *imagePicker;
    UIToolbar *myToolbar;
    UIActivityIndicatorView *activityIndicator;
}
@property CGPoint location;
@property CGRect  imageRect;
@property ShapeType shapeType;
@property (nonatomic, retain) canvas *myView;
@property (nonatomic, retain) canvas *myViewTop;
//@property (nonatomic, retain) IBOutlet UIImageView *imgView;

@property (nonatomic, retain) UIImage *image;
@property (nonatomic, retain) UIImage *imageTop;
@property (nonatomic, retain) UIImage *imageBackground;
@property (nonatomic, retain) UIScrollView *myScrollView;
@property (nonatomic, retain) UIScrollView *myScrollViewTop;

@property cv::Mat imgFilledContours;
@property cv::Mat img,res;
@property TContours contours;
@property CGRect boundRect;
@property (nonatomic, retain) CvGrabCutController *grabCutController;
@property int rootFlag;
@property int minimumZoomScale;
@property int maximumZoomScale;
@property float zoomScaleOldW;
@property float zoomScaleOldH;

@property int pickBtnFlag;
@property (nonatomic) UIImagePickerController *imagePicker;
@property (nonatomic,retain) UIToolbar *myToolbar;
@property (nonatomic,retain) UIActivityIndicatorView *activityIndicator;



- (IBAction)actionGrabCut:(id)sender;
- (IBAction)toogleSelectDraw:(id)sender;
-(void)actionShowPhotoLibrary;

@end
