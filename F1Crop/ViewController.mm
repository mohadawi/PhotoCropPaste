                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            //
//  ViewController.m
//  opencv1
//
//  Created by Mohammad Dawi on 6/10/13.
//  Copyright (c) 2013 Mohammad Dawi. All rights reserved.
//

#import "ViewController.h"
#import "UIImageCVMatConverter.h"
#import <opencv2/opencv.hpp>
//#import "ComponentLabeling.h"
#import "canvas.h"
#import "UIImage+ImageBlur.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "UIImage-Orientation.h"
#define SUBVIEW_TAG 9999
#define pickBtn_TAG 9998
#define pick2Btn_TAG 9997
#define MYSCROLLVIEW_TAG 9996
#define MYSCROLLVIEWTOP_TAG 9995
#define SEGMENTSLIDER_TAG 9994
#ifndef MIN
#import <NSObjCRuntime.h>
#endif
// return true if the device has a retina display, false otherwise
#define IS_RETINA_DISPLAY() [[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f

// return the scale value based on device's display (2 retina, 1 other)
#define DISPLAY_SCALE IS_RETINA_DISPLAY() ? 2.0f : 1.0f

// if the device has a retina display return the real scaled pixel size, otherwise the same size will be returned
#define PIXEL_SIZE(size) IS_RETINA_DISPLAY() ? CGSizeMake(size.width/2.0f, size.height/2.0f) : size

using namespace cv;
@interface ViewController ()


@end

@implementation ViewController
static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};
static UIImage *popImage = nil;
static int memWarnig;
@synthesize location;
@synthesize myView,myViewTop;
@synthesize imgFilledContours;
@synthesize img,res;
@synthesize contours;
@synthesize boundRect;
@synthesize grabCutController;
@synthesize image;
@synthesize imageTop;
@synthesize rootFlag;
@synthesize imagePicker;
@synthesize maximumZoomScale;
@synthesize minimumZoomScale;
@synthesize zoomScaleOldW,zoomScaleOldH;
@synthesize myToolbar;
@synthesize pickBtnFlag;
@synthesize imageBackground;
@synthesize myScrollView,myScrollViewTop;
@synthesize imageRect;
@synthesize shapeType;
@synthesize activityIndicator;
//@synthesize imgView;

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIWindow *window=[[[UIApplication sharedApplication] windows] firstObject];

    UIRotationGestureRecognizer *rotationRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotate:)];
    [rotationRecognizer setDelegate:self];
    [self.view addGestureRecognizer:rotationRecognizer];
    
    _lastRotation=0;
    _lastScale=1;
    
    
    UITapGestureRecognizer *tapOnce = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapOnce:)];
    // set number of taps required
    tapOnce.numberOfTapsRequired = 2;
    // now add the gesture recogniser to a view
    // this will be the view that recognises the gesture
    [self.view addGestureRecognizer:tapOnce];
    
   
    
    
//    //swipe gesture
//    UISwipeGestureRecognizer *gestureRecognizerD = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRecognizer:)];
//    [gestureRecognizerD setDirection:(UISwipeGestureRecognizerDirectionDown)];
//    [self.view addGestureRecognizer:gestureRecognizerD];
//   
//    UISwipeGestureRecognizer *gestureRecognizerU = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeHandler:)];
//    [gestureRecognizerU setDirection:(UISwipeGestureRecognizerDirectionUp)];
//    [self.view addGestureRecognizer:gestureRecognizerU];
//    
    
    
    if(self.rootFlag!=-1){
        self.imageRect=window.bounds;
    }
    
    self.minimumZoomScale=1;
    self.maximumZoomScale=4;
    
    [self addScrollView1];
    [self addToolBar];
    
    
    
    self.myView.draggable=0;
    self.myViewTop.draggable=0;
    self.imagePicker = [[UIImagePickerController alloc] init];
    self.imagePicker.allowsEditing = NO;
    self.imagePicker.delegate=self;
    
    if ([UIImagePickerController isSourceTypeAvailable:
         UIImagePickerControllerSourceTypePhotoLibrary]) {
        self.imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;//UIImagePickerControllerSourceTypeSavedPhotosAlbum;//
    }

    if (self.rootFlag!=-1) {
        [self.myView setShapeType:KLineShape];
        //[self lockZoom];
    }
    
    //Create and add the Activity Indicator to splashView
    activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    activityIndicator.color=[UIColor colorWithRed:255 green:0 blue:128 alpha:1.0];
    activityIndicator.alpha = 1.0;
    activityIndicator.center = CGPointMake(window.frame.size.width/2, window.frame.size.height/2);
    //activityIndicator.hidesWhenStopped = NO;
    
    memWarnig=0;
}

-(void) viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    if(myView.image!=nil){
        [myView setNeedsDisplay];
    }
    else{
        if (self.presentedViewController!=nil) {
            [self dismissViewControllerAnimated:NO completion:nil];
        }
    }
    
}


- (void)swipeRecognizer:(UISwipeGestureRecognizer *)sender {
    if (sender.direction == UISwipeGestureRecognizerDirectionUp){
//        [UIView animateWithDuration:0.3 animations:^{
//            CGPoint Position = CGPointMake(self.view.frame.origin.x + 100.0, self.view.frame.origin.y);
//            self.view.frame = CGRectMake(Position.x , Position.y , self.view.frame.size.width, self.view.frame.size.height);
//            [self.navigationController popViewControllerAnimated:YES];
//        }];
        [self.myToolbar setHidden:NO];
    }
    else if(sender.direction == UISwipeGestureRecognizerDirectionDown){
        
        [self.myToolbar setHidden:YES];
    }
    
}

-(void)sliderAction:(id)sender
{
    UISlider *slider = (UISlider*)sender;
    float value = slider.value;
    NSString *s =@"value=";
    //-- Do further actions
    /*
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Test Message"
                                                    message:[s stringByAppendingString:[[NSNumber numberWithFloat:value] stringValue]]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
     [alert show];
     */
    //self.myView.alpha=value/50;
    int valueInt = [[NSNumber numberWithFloat:value] intValue];
    [self testDrawFillContours:valueInt];
    
    
}

-(void)swipeHandler:(UISwipeGestureRecognizer *)recognizer {
    //NSLog(@"Swipe received.");
    if (recognizer.direction == UISwipeGestureRecognizerDirectionUp){
        //        [UIView animateWithDuration:0.3 animations:^{
        //            CGPoint Position = CGPointMake(self.view.frame.origin.x + 100.0, self.view.frame.origin.y);
        //            self.view.frame = CGRectMake(Position.x , Position.y , self.view.frame.size.width, self.view.frame.size.height);
        //            [self.navigationController popViewControllerAnimated:YES];
        //        }];
        [self.myToolbar setHidden:NO];
        //NSLog(@"Swipe up received.");
    }
    else if(recognizer.direction == UISwipeGestureRecognizerDirectionDown){
        //NSLog(@"Swipe down received.");
        
        [self.myToolbar setHidden:YES];
    }
}


- (void)popModalsFrom1:(ViewController*)aVc popCount:(int)count dDownImage:(UIImage*)img2 rootVC:(ViewController**)rVc{
    
    if(aVc ==nil || count == 0) {
        return;
    }
    else {
        ViewController *p=(ViewController*)aVc.presentingViewController;
        //ViewController *child=(ViewController*)aVc.presentedViewController;
        if (p==nil) {
            *rVc=aVc;
            @autoreleasepool {
                [aVc.myView.imagesArray removeAllObjects];
                aVc.myView.imagesArray=nil;
            }
        }
        [aVc popModalsFrom1:(ViewController*)aVc.presentingViewController popCount:count-1 dDownImage:img2 rootVC:rVc];  // recursive call to this method
        //remove the previous image history
        if (aVc.myView.imagesArray.count>0) {
            //NSLog(@"i am in array>0");
            @autoreleasepool {
                [aVc.myView.imagesArray removeAllObjects];
                aVc.myView.imagesArray=nil;
            }
        }
        aVc.image=nil;
        aVc.myView.image=nil;
        [aVc.myView setNeedsDisplay];
        [aVc dismissViewControllerAnimated:NO completion:nil];
    }
}

-(void)rotate:(id)sender {

    if([(UIRotationGestureRecognizer*)sender state] == UIGestureRecognizerStateEnded) {
        //myScrollViewTop.minimumZoomScale=1;
        //myScrollViewTop.maximumZoomScale=1;
        //_lastRotation = 0.0;
        return;
    }
   _rotation += [(UIRotationGestureRecognizer*)sender rotation];
    CGAffineTransform currentTransform = myScrollViewTop.transform;// imgView.transform;
    CGAffineTransform newTransform = CGAffineTransformRotate(currentTransform,[(UIRotationGestureRecognizer*)sender rotation]);
    [myScrollViewTop setTransform:(newTransform)];
    _lastRotation = [(UIRotationGestureRecognizer*)sender rotation];
    [(UIRotationGestureRecognizer*)sender setRotation:0];
//    NSLog(@"BX=%f,BY=%f",myScrollViewTop.bounds.origin.x,myScrollViewTop.bounds.origin.y);
//    NSLog(@"FX=%f,FY=%f",myScrollViewTop.frame.origin.x,myScrollViewTop.frame.origin.y);
//    NSLog(@"CW=%f,CH=%f",myScrollViewTop.contentSize.width,myScrollViewTop.contentSize.height);
//    NSLog(@"rotation=%f",_rotation);
}


-(void) removeScrollView1{
    [self.view.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
}

-(void)delay{
    //NSLog(@"i am in");
}


-(void)addToolBar{
    //add toolbar
    UIWindow *window=[[[UIApplication sharedApplication] windows] firstObject];
    CGRect gameArea = CGRectMake(0, 0, window.bounds.size.width, window.bounds.size.height);
    self.myToolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, gameArea.size.height - 60, gameArea.size.width, 60)];
    //float topInset = -10.0f;
    
    //fexible space button
    UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    
    
    //paste custom button
    UIButton *paste2 = [UIButton buttonWithType:UIButtonTypeCustom];
    paste2.titleLabel.font=[UIFont systemFontOfSize: 16];
    [paste2 setTitle:@"Paste" forState:UIControlStateNormal];
    [paste2 setTitleColor:[UIColor colorWithRed:255 green:0 blue:128 alpha:1] forState:UIControlStateNormal];
    [paste2 setTitleColor:[UIColor colorWithRed:255 green:0 blue:128 alpha:0.5] forState:UIControlStateHighlighted];
    paste2.frame = CGRectMake(0, 0, 60, 55);
    [paste2 setTitleEdgeInsets:UIEdgeInsetsMake(0.0f, 2.0f, 0.0f, 0.0f)];
    [paste2 addTarget:self action:@selector(actionShowPhotoLibrary1) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem * paste3 = [[UIBarButtonItem alloc] initWithCustomView:paste2];
    
    
    //Back custom button
    UIButton *cancel2 = [UIButton buttonWithType:UIButtonTypeCustom];
    cancel2.titleLabel.font=[UIFont systemFontOfSize: 16];
    [cancel2 setTitle:@"Back" forState:UIControlStateNormal];
    [cancel2 setTitleColor:[UIColor colorWithRed:255 green:0 blue:128 alpha:1] forState:UIControlStateNormal];
    [cancel2 setTitleColor:[UIColor colorWithRed:255 green:0 blue:128 alpha:0.5] forState:UIControlStateHighlighted];
    cancel2.frame = CGRectMake(0, 0, 60, 55);
    [cancel2 addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem * cancel3 = [[UIBarButtonItem alloc] initWithCustomView:cancel2];
    
    
    //save custom button
    UIButton *save2 = [UIButton buttonWithType:UIButtonTypeCustom];
    save2.titleLabel.font=[UIFont systemFontOfSize: 16];
    [save2 setTitle:@"Save" forState:UIControlStateNormal];
    [save2 setTitleColor:[UIColor colorWithRed:255 green:0 blue:128 alpha:1] forState:UIControlStateNormal];
    [save2 setTitleColor:[UIColor colorWithRed:255 green:0 blue:128 alpha:0.5] forState:UIControlStateHighlighted];
    save2.frame = CGRectMake(0, 0, 60, 55);
    [save2 addTarget:self action:@selector(actionSave) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem * save3 = [[UIBarButtonItem alloc] initWithCustomView:save2];
    
    //picker image system button
    UIBarButtonItem *pickBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(actionShowPhotoLibrary)];
    pickBtn.tintColor=[UIColor colorWithRed:255 green:0 blue:128 alpha:1];
    
    //crop draw image button
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *bwImageD=[UIImage imageNamed:@"crop_draw4.png"];
    //UIImage *bwImageD=[UIImage imageNamed:@"drawCropB.png"];
    //remove alpha channel
    bwImageD=[self removeAlphaChannel:bwImageD];
    const CGFloat colorMaskingD[6]={222,255,222,255,222,255};
    UIImage *bwImageDP=[self processImage:bwImageD withMask:colorMaskingD];
    bwImageDP=[self convertToGrayscale:bwImageDP];
    bwImageDP=[self roundedRectImageFromImage:bwImageDP withRadious:6];
    //[btn setImage:[UIImage imageNamed:@"crop_draw1.png"]];
    btn.frame = CGRectMake(0, 0, 65, 55);
    //[btn setImage:bwImageDP forState:UIControlStateNormal];
    //[myButton setImage:[UIImage imageNamed:@"button_pressed.png"] forState:UIControlStateHighlighted];
    
    //btn.imageEdgeInsets=UIEdgeInsetsMake(5, 5.0f, 12, 7.0f);
    
    //set the label text
    [self formatLabelForButton:btn withHeight:10 andVerticalOffset:btn.frame.size.height-10 andText:@"Free crop" withFontSize:9 withFontColor:[UIColor colorWithRed:255 green:0 blue:128 alpha:1] andBoldFont:NO withTag:11];
    
    //    [btn setTitleEdgeInsets:UIEdgeInsetsMake(0, 0.0f, -35, 0.0f)];
    //    [btn setTitle:@"Draw" forState:UIControlStateNormal];
    //    [btn setTitleColor:[UIColor colorWithRed:255 green:0 blue:128 alpha:1] forState:UIControlStateNormal];
    //    btn.titleLabel.font = [UIFont systemFontOfSize:10];
    
    [btn addTarget:self action:@selector(handleExit) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem * aBarButton = [[UIBarButtonItem alloc] initWithCustomView:btn];
    [aBarButton setBackgroundVerticalPositionAdjustment:-20.0f forBarMetrics:UIBarMetricsDefault];
    
    //crop rect image button
    UIButton *btnR = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *bwImageR=[UIImage imageNamed:@"crop_rect3.png"];
    //UIImage *bwImageR=[UIImage imageNamed:@"rectCropB.png"];
    //remove alpha channel
    bwImageR=[self removeAlphaChannel:bwImageR];
    UIImage *bwImageRP=[self processImage:bwImageR withMask:colorMaskingD];
    bwImageRP=[self convertToGrayscale:bwImageRP];
    bwImageRP=[self roundedRectImageFromImage:bwImageRP withRadious:6];
    //[btnR setBackgroundImage:[[UIImage alloc] init] forState:UIControlStateNormal];
    btnR.frame = CGRectMake(0, 0, 65, 55);
    //[btnR setImage:bwImageRP forState:UIControlStateNormal];
    //btnR.imageEdgeInsets=UIEdgeInsetsMake(5, 5.0f, 12, 7.0f);
    
    //set the label text
    [self formatLabelForButton:btnR withHeight:10 andVerticalOffset:btnR.frame.size.height-10 andText:@"Rect crop" withFontSize:9 withFontColor:[UIColor colorWithRed:255 green:0 blue:128 alpha:1] andBoldFont:NO withTag:11];
    
    //btnR.alpha=0.2;
    [btnR addTarget:self action:@selector(toogleSelectDraw:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem * aBarButtonR = [[UIBarButtonItem alloc] initWithCustomView:btnR];
    
    
    //segment image button
    UIButton *btnS = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *bwImageS=[UIImage imageNamed:@"crop_rect3.png"];
    //remove alpha channel
    bwImageS=[self removeAlphaChannel:bwImageS];
    UIImage *bwImageSP=[self processImage:bwImageS withMask:colorMaskingD];
    bwImageSP=[self convertToGrayscale:bwImageSP];
    bwImageSP=[self roundedRectImageFromImage:bwImageSP withRadious:6];
    //[btnR setBackgroundImage:[[UIImage alloc] init] forState:UIControlStateNormal];
    btnS.frame = CGRectMake(0, 0, 65, 55);

    
    //set the label text
    [self formatLabelForButton:btnS withHeight:10 andVerticalOffset:btnS.frame.size.height-10 andText:@"Segment" withFontSize:9 withFontColor:[UIColor colorWithRed:255 green:0 blue:128 alpha:1] andBoldFont:NO withTag:11];
    
    //btnR.alpha=0.2;
    [btnS addTarget:self action:@selector(testSegmentation) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem * aBarButtonS = [[UIBarButtonItem alloc] initWithCustomView:btnS];
    
    
    //add the toolbar iterms
    //    myToolbar.items = [NSArray arrayWithObjects:pickBtn,spaceItem,pasteBtn,spaceItem, aBarButtonR, spaceItem,aBarButton,spaceItem,cancel1,spaceItem,save1,spaceItem, nil];
    [myToolbar setItems:[NSArray arrayWithObjects:pickBtn,spaceItem,cancel3,spaceItem, aBarButtonR, spaceItem,aBarButton,spaceItem,aBarButtonS,spaceItem,paste3,spaceItem,save3,spaceItem, nil] animated:YES];
    //[myToolbar setBackgroundImage:[[UIImage alloc] init] forToolbarPosition:UIToolbarPositionAny barMetrics:UIBarMetricsDefault];
    //myToolbar.alpha=0.7;
    //myToolbar.translucent=YES;
    //[myToolbar setBarTintColor:[UIColor darkGrayColor]];
    [myToolbar setBarStyle:UIBarStyleBlack];
    
    
    
    [self.view addSubview:self.myToolbar];
    if  (self.rootFlag==-1)
    {
//        //disable picker button
//        UIBarButtonItem *btnPickImage=[self.myToolbar.items objectAtIndex:0];
//        btnPickImage.style = UIBarButtonItemStylePlain;
//        btnPickImage.enabled = false;
//        btnPickImage.title = nil;
    }
    else{
        //disable crop buttons
        UIBarButtonItem *btnRectSelect=[self.myToolbar.items objectAtIndex:4];
        btnRectSelect.style = UIBarButtonItemStylePlain;
        btnRectSelect.enabled = false;
        btnRectSelect.customView.alpha=0.4;
        btnRectSelect.title = nil;
        
        UIBarButtonItem *btnDrawSelect=[self.myToolbar.items objectAtIndex:6];
        btnDrawSelect.style = UIBarButtonItemStylePlain;
        btnDrawSelect.enabled = false;
        btnDrawSelect.customView.alpha=0.4;
        btnDrawSelect.title = nil;
        
        UIBarButtonItem *btnSegment=[self.myToolbar.items objectAtIndex:8];
        btnSegment.style = UIBarButtonItemStylePlain;
        btnSegment.enabled = false;
        btnSegment.customView.alpha=0.4;
        btnSegment.title = nil;
        
        //disable pick2 button
        UIBarButtonItem *btnPick2=[self.myToolbar.items objectAtIndex:10];
        btnPick2.style = UIBarButtonItemStylePlain;
        btnPick2.enabled = false;
        btnPick2.customView.alpha=0.4;
        btnPick2.title = nil;
        
        
        
    }
}

-(void)addScrollView1 {
    // Area of the UIView and UIImageView
    UIWindow *window=[[[UIApplication sharedApplication] windows] firstObject];
    
    CGRect gameArea = CGRectMake(0, 0, window.bounds.size.width, window.bounds.size.height);
    
    // Create UIView and insert subview
    if (self.myView==nil) {
        self.myView = [[canvas alloc] initWithFrame:gameArea];
        //self.myView.contentMode=UIViewContentModeTopLeft;
    }
    myView.image=self.image;
    self.image=nil;

    
    myView.frameRect=self.imageRect;//r----->replaced now
    [myView setShapeType:self.shapeType];
    myView.backgroundColor =[UIColor colorWithRed:255 green:0 blue:128 alpha:0.2];//[UIColor redColor];
    
    if (myScrollView==nil) {
        myScrollView = [[UIScrollView alloc]initWithFrame:
                        gameArea];
        
        [myScrollView setTag:MYSCROLLVIEW_TAG];
        [myScrollView addSubview:myView];
    }

    myScrollView.minimumZoomScale = self.minimumZoomScale;
    myScrollView.maximumZoomScale = self.maximumZoomScale;
    myScrollView.delegate = self;
    
    myScrollView.contentSize =gameArea.size;// myView.image.size;
    
    [[self view] addSubview:myScrollView];
    
}



- (void) formatLabelForButton: (UIButton *) button withHeight: (double) height andVerticalOffset: (double) offset andText: (NSString *) labelText withFontSize: (double) fontSize withFontColor: (UIColor *) color andBoldFont:(BOOL) formatAsBold withTag: (NSInteger) tagNumber {
    
    @try {
        // Get width of button
        double buttonWidth= button.frame.size.width;
        
        // Initialize buttonLabel
        UILabel *buttonLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, offset, buttonWidth, height)];
        
        // Set font size and weight of label
        if (formatAsBold) {
            buttonLabel.font = [UIFont boldSystemFontOfSize:fontSize];
        }
        else {
            buttonLabel.font = [UIFont systemFontOfSize:fontSize];
        }
        
        // set font color of label
        buttonLabel.textColor = color;
        
        // Set background color, text, tag, and font
        buttonLabel.backgroundColor = [UIColor clearColor];
        buttonLabel.text = labelText;
        buttonLabel.tag = tagNumber;
        
        // Center label
        buttonLabel.textAlignment = NSTextAlignmentCenter;
        
        // Add label to button
        [button addSubview:buttonLabel];
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
    
} // End formatLabelForButton

-(void)addScrollView2 :(UIImage*)imageA{
    @try {
        // Area of the UIView and UIImageView
        CGRect gameArea = CGRectMake(0, 0, self.imageRect.size.width, self.imageRect.size.height);
        UIWindow *window=[[[UIApplication sharedApplication] windows] firstObject];
        // Create UIView and insert subview
        _rotation=0;
        
        if (myViewTop==nil) {
            myViewTop = [[canvas alloc] initWithFrame:gameArea];
        }
        
        myViewTop.draggable=1;
        myViewTop.frameRect=gameArea;
        myViewTop.shapeType=KImageShape;
        
        myViewTop.backgroundColor =[UIColor clearColor];// [[UIColor alloc] initWithHue:0 saturation:0 brightness:1.0 alpha:0.0];
        if (imageA) {
            myViewTop.image=imageA;//self.image;
            [myViewTop setNeedsDisplay];
        }
        
        if (myScrollViewTop==nil) {
            myScrollViewTop = [[UIScrollView alloc]initWithFrame:
                               gameArea];
            [myScrollViewTop setTag:MYSCROLLVIEWTOP_TAG];
            //myScrollViewTop.contentMode = UIViewContentModeScaleAspectFit;
            [myScrollViewTop addSubview:myViewTop];
        }
        else {
            myScrollViewTop.frame=CGRectMake(0, 0, myScrollViewTop.frame.size.width, myScrollViewTop.frame.size.height);
        }
        
        //set the frame for scrollview
        //myView.frame=r;
        myScrollView.frame=window.bounds;
        
        myScrollViewTop.minimumZoomScale =1;//MIN(self.image.size.width/2,self.image.size.height/2); //self.minimumZoomScale;
        self.zoomScaleOldW=1;
        self.zoomScaleOldH=1;
        myScrollViewTop.maximumZoomScale =4;//MIN(window.frame.size.width/self.image.size.width,window.frame.size.height/self.image.size.height);// self.maximumZoomScale;
        myScrollViewTop.delegate = self;
        
        if (imageA) {
            UIWindow *window=[[[UIApplication sharedApplication] windows] firstObject];
            myViewTop.ratioW=(myViewTop.image.size.width/myViewTop.frame.size.width)*(window.frame.size.width/self.imageRect.size.width);
            myViewTop.ratioH=(myViewTop.image.size.height/myViewTop.frame.size.height)*(window.frame.size.height/self.imageRect.size.height);
        }
        myScrollViewTop.contentSize =myViewTop.image.size;
        
        if(![myScrollViewTop isDescendantOfView:myScrollView]) {
            [myScrollView addSubview:myScrollViewTop];
        }

    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}


- (UIImage*) removeAlphaChannel :(UIImage*) imageA
{
    @try {
        if (imageA!=nil) {
            //remove alpha channel assuming RGBA
            cv::Mat imgtest=[UIImageCVMatConverter cvMatFromUIImage:imageA];
            //int x=imgtest.channels();
            cv::cvtColor(imgtest, imgtest, CV_RGBA2RGB);
            imageA=[UIImageCVMatConverter UIImageFromCVMat:imgtest];
            return imageA;
        }
        else{
            return nil;
        }
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}


- (UIImage*) processImage :(UIImage*) imageA withMask:(const CGFloat[])colorMasking
{
    @try {
        if (imageA!=nil) {
            //const CGFloat colorMasking1[6]={222,255,222,255,222,255};
            CGImageRef imageRef = CGImageCreateWithMaskingColors(imageA.CGImage, colorMasking);
            UIImage* imageB = [UIImage imageWithCGImage:imageRef];
            CGImageRelease(imageRef);
            return imageB;
        }
        else{
            return nil;
        }
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}


- (UIImage *)imageByApplyingAlpha:(UIImage*)imgA withAlpha:(CGFloat) alpha {
    UIGraphicsBeginImageContextWithOptions(imgA.size, NO, 0.0f);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect area = CGRectMake(0, 0, imgA.size.width, imgA.size.height);
    
    CGContextScaleCTM(ctx, 1, -1);
    CGContextTranslateCTM(ctx, 0, -area.size.height);
    
    CGContextSetBlendMode(ctx, kCGBlendModeMultiply);
    
    CGContextSetAlpha(ctx, alpha);
    
    CGContextDrawImage(ctx, area, imgA.CGImage);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return newImage;
}

- (UIImage*)convertToGrayscale:(UIImage*) inputImage
{
    @try {
        if (inputImage!=nil) {
            UIGraphicsBeginImageContextWithOptions(inputImage.size, NO, 0.0);
            CGRect imageRect1 = CGRectMake(0.0f, 0.0f, inputImage.size.width, inputImage.size.height);
            
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            
            // Draw a white background
            CGContextSetRGBFillColor(ctx, 1.0f, 1.0f, 1.0f, 1.0f);
            CGContextFillRect(ctx, imageRect1);
            
            // Draw the luminosity on top of the white background to get grayscale
            [inputImage drawInRect:imageRect1 blendMode:kCGBlendModeLuminosity alpha:1.0f];
            
            // Apply the source image's alpha
            [inputImage drawInRect:imageRect1 blendMode:kCGBlendModeDestinationIn alpha:1.0f];
            
            UIImage* grayscaleImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            return grayscaleImage;
        }
        else{
            return nil;
        }

    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
    
}

//MARK: Transform the image in grayscale.
- (UIImage*) grayishImage: (UIImage*) inputImage {
    
    // Create a graphic context.
    UIGraphicsBeginImageContextWithOptions(inputImage.size, YES, 0.0);
    CGRect imageRect1 = CGRectMake(0, 0, inputImage.size.width, inputImage.size.height);
    
    // Draw the image with the luminosity blend mode.
    // On top of a white background, this will give a black and white image.
    [inputImage drawInRect:imageRect1 blendMode:kCGBlendModeLuminosity alpha:1.0];
    
    // Get the resulting image.
    UIImage *filteredImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return filteredImage;
    
}
     

+ (CGRect) boundingRectAfterRotatingRect: (CGRect) rect toAngle: (float) radians
{
    CGAffineTransform xfrm = CGAffineTransformMakeRotation(radians);
    CGRect result = CGRectApplyAffineTransform (rect, xfrm);
    
    return result;
}

- (BOOL) hasAlphaChannel  : (UIImage*) image
{
    if ([self hasAlpha:image])
        return YES;
    return NO;
}


- (BOOL)hasAlpha : (UIImage*) img
{
    CGImageAlphaInfo alpha = CGImageGetAlphaInfo(img.CGImage);
    return (
            alpha == kCGImageAlphaFirst ||
            alpha == kCGImageAlphaLast ||
            alpha == kCGImageAlphaPremultipliedFirst ||
            alpha == kCGImageAlphaPremultipliedLast
            );
    
}

//MARK: Histogram and back-projection filter
-(void)testHistandBackproj{
    //test Hist_and_Backproj function
        cv::Mat im,grayMat;
        cv::Mat histImg;
        cv::MatND backproj;
    UIImage *uIm;
    int x,y;
    //self.img = [UIImageCVMatConverter toMat:[self.myView.imagesArray objectAtIndex:[self.myView.imagesArray count]-1]];
    //self.img
    uIm=[self.myView.imagesArray objectAtIndex:[self.myView.imagesArray count]-1];
    x=uIm.size.width;
    y=uIm.size.height;
    
    //check if image is gray
    
    if (CGColorSpaceGetModel(CGImageGetColorSpace(uIm.CGImage)) == kCGColorSpaceModelMonochrome) {
        // Image is grayscale
        //check if image has alpha channel
        bool alpha=[self hasAlphaChannel:uIm];
        im=[UIImageCVMatConverter cvMatFromUIImage:uIm];
    }
    else{
        im= [UIImageCVMatConverter cvMatFromUIImage:uIm];
    }
    //im= [UIImageCVMatConverter toMat:uIm];
    cv::string s=getImgType(im.type());
    [self Hist_and_Backproj:im backproj:backproj histImg:histImg];
    return;
    im.release();
    uIm=nil;
    uIm=[UIImageCVMatConverter UIImageFromCVMat:backproj];
    x=uIm.size.width;
    y=uIm.size.height;
    self.myView.image=uIm;
    [self.myView setNeedsDisplay];
    backproj.release();
    uIm=nil;

}

//MARK: Draw contours and fill them with random colors
- (void)testDrawFillContours:(int) clusterSize
{
    if(self.myView.image!=nil){
        //test the drawFillContours function
        cv::Mat drawing;
        self.img = [UIImageCVMatConverter cvMatFromUIImage:[self.myView.imagesArray objectAtIndex:[self.myView.imagesArray count]-1]];
        drawFillContours(img,drawing,1,clusterSize);
        self.myView.image=[UIImageCVMatConverter UIImageFromCVMat:drawing];
        [self.myView setNeedsDisplay];
    }
}


- (void)testSegmentation
{
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"Segmentation Methods" message:@"" preferredStyle:UIAlertControllerStyleActionSheet];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        // Cancel button tappped.
       // [self dismissViewControllerAnimated:YES completion:^{}];
        [self removeSegSlider];
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Draw&Fill Contours" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        @autoreleasepool {
            if (self.myView.imagesArray==nil) {
                self.myView.imagesArray=[[NSMutableArray alloc]initWithObjects:nil] ;
                [self.myView.imagesArray addObject:self.myView.image];
            }
            else{// if([self.myView.imagesArray count]==0){
                [self.myView.imagesArray addObject:self.myView.image];
            }
        }
        //Add slider
        CGRect frame = CGRectMake(50.0, 50.0, 200.0, 10.0);
        UISlider *slider = [[UISlider alloc] initWithFrame:frame];
        [slider addTarget:self action:@selector(sliderAction:) forControlEvents:UIControlEventValueChanged];
        [slider setBackgroundColor:[UIColor redColor]];
        slider.minimumValue = 50.0;
        slider.maximumValue = 500.0;
        slider.continuous = YES;
        slider.value = 50.0;
        slider.tag=SEGMENTSLIDER_TAG;
        [self.myView addSubview:slider];
        //do the segmentation with min value of cluster size
        [self testDrawFillContours:50];
        // Distructive button tapped.
       // [self dismissViewControllerAnimated:YES completion:^{}];
    }]];
    
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Hist & Backproj" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        
        @autoreleasepool {
            if (self.myView.imagesArray==nil) {
                self.myView.imagesArray=[[NSMutableArray alloc]initWithObjects:nil] ;
                [self.myView.imagesArray addObject:self.myView.image];
            }
            else{// if([self.myView.imagesArray count]==0){
                [self.myView.imagesArray addObject:self.myView.image];
            }
        }
        
        [self testHistandBackproj];
        
        //disable segment button
        /*
        UIBarButtonItem *btnSegment=[self.myToolbar.items objectAtIndex:8];
        btnSegment.style = UIBarButtonItemStylePlain;
        btnSegment.enabled = false;
        btnSegment.customView.alpha=0.4;
        btnSegment.title = nil;
         */
        
        //[self dismissViewControllerAnimated:YES completion:^{}];
    }]];
    
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Other" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        
        // OK button tapped.
        
        [self dismissViewControllerAnimated:YES completion:^{
        }];
    }]];
    // Present action sheet.
    [self presentViewController:actionSheet animated:YES completion:nil];

}

- (void) actionSave
{
    @try {
        //show activity indicator
        if(![activityIndicator isDescendantOfView:self.view]) {
            [self.view addSubview:activityIndicator];
        }
        [activityIndicator startAnimating];
        UIBarButtonItem *btnSave=[self.myToolbar.items objectAtIndex:12];
        btnSave.enabled=false;
        UIButton *btnBack1=(UIButton*)btnSave.customView;
        //[btnBack1 setBackgroundColor:[UIColor blueColor]];
        [btnBack1 setAlpha:0.4];
        
        if(self.pickBtnFlag==pick2Btn_TAG){
            UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
            //myScrollViewTop position is relative to the contentview 'myView' of myScrollView
            myView.ratioW=(myView.image.size.width/myView.frame.size.width)*(window.frame.size.width/myView.frameRect.size.width);
            
            myView.ratioH=(myView.image.size.height/myView.frame.size.height)*(window.frame.size.height/myView.frameRect.size.height);
            
            //        NSLog(@"PFW=%f,PFH=%f",myScrollView.frame.size.width,myScrollView.frame.size.height);
            //        NSLog(@"PVW=%f,PVH=%f",myView.frame.size.width,myView.frame.size.height);
            //        NSLog(@"PCVW=%f,PCVH=%f",myScrollView.contentSize.width,myScrollView.contentSize.height);
            //        NSLog(@"FX=%f,FY=%f",myScrollViewTop.frame.origin.x,myScrollViewTop.frame.origin.y);
            //
            //cropped frame without floor
            
            //scale the frameRect first to update the origin
            CGRect myViewFrameRect=[self scaleRect:myView.frameRect scale:myScrollView.zoomScale];
            //translate the rect first
            CGRect t=[myView translateRect:myScrollViewTop.frame toOrigin:myViewFrameRect.origin fromOrigin:myScrollView.frame.origin];
            
            CGRect r=CGRectMake(t.origin.x*myView.ratioW, t.origin.y*myView.ratioH, t.size.width*myView.ratioW, t.size.height*myView.ratioH);
            
            //        CGRect r=CGRectMake(myScrollViewTop.frame.origin.x*myView.ratioW, myScrollViewTop.frame.origin.y*myView.ratioH, myScrollViewTop.frame.size.width*myView.ratioW, myScrollViewTop.frame.size.height*myView.ratioH);
            
            UIView *backgroundView=[[UIView alloc] initWithFrame:myScrollViewTop.frame];
            backgroundView.tag=911;
            backgroundView.backgroundColor=[UIColor colorWithRed:255 green:0 blue:128 alpha:0.2];
            [myScrollView addSubview:backgroundView];
            // NSLog(@"BackViewX=%f,BackViewY=%f",backgroundView.frame.origin.x,backgroundView.frame.origin.y);
            
            myViewTop.image=[self imageRotatedByDegrees:myViewTop.image degrees:_rotation];
            myView.image=[self addImageToImage1:myView.image withImage2:myViewTop.image andRect:r];
            
        }
        
        if (myView.image!=nil) {
            @autoreleasepool {
                NSData *imageData = UIImagePNGRepresentation(myView.image);
                myView.image=[UIImage imageWithData:imageData];
                imageData=nil;
            }
            
            
            UIImageWriteToSavedPhotosAlbum(myView.image,
                                           self, // send the message to 'self' when calling the callback
                                           @selector(thisImage:hasBeenSavedInPhotoAlbumWithError:usingContextInfo:), // the selector to tell the method to call on completion
                                           nil);
            self.image=nil;
            
        }
        else{
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"info"
                                                            message:@"Please choose a photo"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            alert=nil;
            [activityIndicator stopAnimating];
        }
        
        //NSLog(@"i am in save");
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}

-(CGRect) scaleRect:(CGRect) rect scale:(double) sc{
    return CGRectMake(rect.origin.x*sc, rect.origin.y*sc, rect.size.width*sc, rect.size.height*sc);
}

- (void)thisImage:(UIImage *)image hasBeenSavedInPhotoAlbumWithError:(NSError *)error usingContextInfo:(void*)ctxInfo {
    @try {
        if (error) {
            // Do anything needed to handle the error or display it to the user
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"info"
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
        } else {
            // .... do anything you want here to handle
            // .... when the image has been saved in the photo album
            [activityIndicator removeFromSuperview];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"info"
                                                            message:@"Image saved successfully"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            
            for(UIView* v in myScrollView.subviews){
                if (v.tag==911) {
                    [v removeFromSuperview];
                }
            }
            
            //myView.image=nil;
            myViewTop.frame=myView.frame;
            if (self.pickBtnFlag==pick2Btn_TAG) {
                [self removeScrollViewTop2];
                [self presentVC1:self.myView.image frame:myView.frameRect];
            }
            
        }
        [activityIndicator stopAnimating];
        

    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
    
}


- (void) handleExit//Draw crop button handler
{
    //CHECK IF rect crop button was pressed
    UIBarButtonItem *btnRect=[self.myToolbar.items objectAtIndex:4];
    btnRect.style = UIBarButtonItemStylePlain;
    
    UIBarButtonItem *btnDraw=[self.myToolbar.items objectAtIndex:6];
    btnDraw.style = UIBarButtonItemStylePlain;
    
    
    //NSLog(@"rect alpha=%f",btnRect.customView.alpha);
    //flip the selection
    if (btnRect.customView.alpha<1) {
        btnDraw.customView.alpha=0.4;
        btnRect.customView.alpha=1;
    }
    else{
        myScrollView.scrollEnabled=!(myScrollView.scrollEnabled);
        
        
        if (myScrollView.scrollEnabled) {
            btnDraw.customView.alpha=1;
        }
        else{
            btnDraw.customView.alpha=0.4;
        }
    }
    [self.myView setShapeType:KCurveShape];
    //[self.myToolbar setHidden:YES];
}

-(void)removeSegSlider{
    //remove slider
    for(UIView* v in self.myView.subviews){
        if (v.tag==SEGMENTSLIDER_TAG) {
            [v removeFromSuperview];
        }
    }
}

-(void) cancel
{
    //remove slider
    [self removeSegSlider];
    
    //double check to remove myScrollViewTop
    if(self.myScrollViewTop!=nil) {
        [self removeScrollViewTop1];
        //NSLog(@"I am in return!!!!!!!!!!!!!!");
        return;
    }
    
    //enable all buttons
    ViewController *p=(ViewController*)self.presentingViewController;
    if(p!=nil){
        [p enableButtons];
    }
    else{
        [self enableButtons];
    }
    [p.myToolbar setHidden:NO];
    //restore previous image
    if (myView.imagesArray.count>0) {
        @autoreleasepool {
            UIImage *tmp=[myView.imagesArray objectAtIndex:myView.imagesArray.count-1];
            myView.image=tmp;
            tmp=nil;
            [self.myView setShapeType:KImageShape];
            [self.myView setNeedsDisplay];
            //self.image=myView.image;
            [myView.imagesArray removeObjectAtIndex:myView.imagesArray.count-1];
        }
    }
    else{
        self.image=nil;
        myView.image=nil;
        if (self.rootFlag ==-1) {
            [self dismissViewControllerAnimated:NO completion:nil];
        }
        else{
            [self.myView setShapeType:KLineShape];
            //disable all buttons
            [self disableButons];
            self->myScrollView.zoomScale=1;
            //[self lockZoom];
            [self.myView setNeedsDisplay];
        }
        
    }
    
}

-(void)disableButons{
    @try {
        //disable crop buttons
        UIBarButtonItem *btnRectSelect=[self.myToolbar.items objectAtIndex:4];
        btnRectSelect.style = UIBarButtonItemStylePlain;
        btnRectSelect.enabled = false;
        btnRectSelect.customView.alpha=0.4;
        btnRectSelect.title = nil;
        
        UIBarButtonItem *btnDrawSelect=[self.myToolbar.items objectAtIndex:6];
        btnDrawSelect.style = UIBarButtonItemStylePlain;
        btnDrawSelect.enabled = false;
        btnDrawSelect.customView.alpha=0.4;
        btnDrawSelect.title = nil;
        
        UIBarButtonItem *btnSegment=[self.myToolbar.items objectAtIndex:8];
        btnSegment.style = UIBarButtonItemStylePlain;
        btnSegment.enabled = false;
        btnSegment.customView.alpha=0.4;
        btnSegment.title = nil;
        
        //disable pick2 button
        UIBarButtonItem *btnPick2=[self.myToolbar.items objectAtIndex:10];
        btnPick2.style = UIBarButtonItemStylePlain;
        btnPick2.enabled = false;
        btnPick2.customView.alpha=0.4;
        btnPick2.title = nil;
        
        //disable save button
        UIBarButtonItem *btnSave=[self.myToolbar.items objectAtIndex:12];
        btnSave.style = UIBarButtonItemStylePlain;
        btnSave.enabled = false;
        btnSave.customView.alpha=0.4;
        btnSave.title = nil;
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}

-(void)presentVC2{
    @try {
        ViewController *root;
        [self popModalsFrom1:self popCount:-1 dDownImage:nil rootVC:&root];
        if (popImage.imageOrientation == UIImageOrientationUp) {
            //NSLog(@"portrait");
        } else if (popImage.imageOrientation == UIImageOrientationLeft || popImage.imageOrientation == UIImageOrientationRight) {
            //NSLog(@"landscape");
            popImage=[popImage imageAdjustedForOrientation];
        }
        UIImage *imge =[[UIImage alloc] initWithCGImage:popImage.CGImage scale:DISPLAY_SCALE orientation:UIImageOrientationUp];
        popImage=nil;
        //if(self.rootFlag!=-1 || self.pickBtnFlag==pick2Btn_TAG){
        CGRect r= [self calculateSizeofFrame:imge];
        root.myView.frameRect=r;
        root.myView.image=imge;
        root.imageRect=r;
        imge=nil;
        //root=nil;
        [root enableButtons];
        [root.myToolbar setHidden:NO];
        
        [root.myView setShapeType:KImageShape];
        [self updateUI];
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}

-(void)presentVC1:(UIImage*)pImage frame:(CGRect)fRect{
    @try {
        ViewController *root;
        [self popModalsFrom1:self popCount:-1 dDownImage:nil rootVC:&root];
        root.myView.frameRect=fRect;
        root.myView.image=pImage;
        root.imageRect=fRect;
        pImage=nil;
        [root.myView setShapeType:KImageShape];
        [root enableButtons2];
        [root.myToolbar setHidden:NO];
        [self updateUI];
    }
    @catch (NSException *exception) {

    }
    @finally {

    }
}



-(void)lockZoom
{
    myScrollView.maximumZoomScale = 1.0;
    myScrollView.minimumZoomScale = 1.0;
}

-(void)unlockZoom
{
    
    myScrollView.maximumZoomScale = self.maximumZoomScale;
    myScrollView.minimumZoomScale = self.minimumZoomScale;
    
}


-(void)removeScrollViewTop1
{
    @try {
        self.myView.image=myViewTop.image;// self.imageTop;
        //self.imageRect=myViewTop.frame;
        
        myView.frameRect=self.imageRect;
        [self.myScrollViewTop removeFromSuperview];
        self.myViewTop.image=nil;
        self.myViewTop=nil;
        self.myScrollViewTop=nil;
        [self.myView setShapeType:KImageShape];
        [self.myView setNeedsDisplay];
        [self enableButtons];
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}

-(void)removeScrollViewTop2
{
    @try {
        //myView.frameRect=self.imageRect;
        [self.myScrollViewTop removeFromSuperview];
        self.myViewTop.image=nil;
        self.myViewTop=nil;
        self.myScrollViewTop=nil;
        [self enableButtons2];
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}


-(void)enableButtons
{
    @try {
        //enable crop buttons
        UIBarButtonItem *btnRectSelect=[self.myToolbar.items objectAtIndex:4];
        btnRectSelect.style = UIBarButtonItemStylePlain;
        btnRectSelect.enabled = true;
        btnRectSelect.customView.alpha=1.0;
        btnRectSelect.title = nil;
        
        UIBarButtonItem *btnDrawSelect=[self.myToolbar.items objectAtIndex:6];
        btnDrawSelect.style = UIBarButtonItemStylePlain;
        btnDrawSelect.enabled = true;
        btnDrawSelect.customView.alpha=1.0;
        btnDrawSelect.title = nil;
        
        UIBarButtonItem *btnSegment=[self.myToolbar.items objectAtIndex:8];
        btnSegment.style = UIBarButtonItemStylePlain;
        btnSegment.enabled = true;
        btnSegment.customView.alpha=1.0;
        btnSegment.title = nil;
        
        //enable pick2 button
        UIBarButtonItem *btnPick2=[self.myToolbar.items objectAtIndex:10];
        btnPick2.style = UIBarButtonItemStylePlain;
        btnPick2.enabled = true;
        btnPick2.customView.alpha=1.0;
        btnPick2.title = nil;
        
        //enable save button
        UIBarButtonItem *btnSave=[self.myToolbar.items objectAtIndex:12];
        btnSave.style = UIBarButtonItemStylePlain;
        btnSave.enabled = true;
        btnSave.customView.alpha=1.0;
        btnSave.title = nil;
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}

-(void)enableButtons2
{
    @try {
        //enable crop buttons
        UIBarButtonItem *btnRectSelect=[self.myToolbar.items objectAtIndex:4];
        btnRectSelect.style = UIBarButtonItemStylePlain;
        btnRectSelect.enabled = true;
        //NSLog(@"%f rect alpha b=",btnRectSelect.customView.alpha);
        btnRectSelect.customView.alpha=1.0;
        //NSLog(@"%f draw alpha a=",btnRectSelect.customView.alpha);
        btnRectSelect.title = nil;
        
        UIBarButtonItem *btnDrawSelect=[self.myToolbar.items objectAtIndex:6];
        btnDrawSelect.style = UIBarButtonItemStylePlain;
        btnDrawSelect.enabled = true;
        //NSLog(@"%f draw alpha b=",btnDrawSelect.customView.alpha);
        btnDrawSelect.customView.alpha=1.0;
        //NSLog(@"%f draw alpha a=",btnDrawSelect.customView.alpha);
        btnDrawSelect.title = nil;
        
        UIBarButtonItem *btnSegment=[self.myToolbar.items objectAtIndex:8];
        btnSegment.style = UIBarButtonItemStylePlain;
        btnSegment.enabled = true;
        //NSLog(@"%f draw alpha b=",btnDrawSelect.customView.alpha);
        btnSegment.customView.alpha=1.0;
        //NSLog(@"%f draw alpha a=",btnDrawSelect.customView.alpha);
        btnSegment.title = nil;
        
        //disable pick2 button
        UIBarButtonItem *btnPick2=[self.myToolbar.items objectAtIndex:10];
        btnPick2.style = UIBarButtonItemStylePlain;
        btnPick2.enabled = false;
        btnPick2.customView.alpha=0.4;
        btnPick2.title = nil;
        
        //disable save button
        UIBarButtonItem *btnSave=[self.myToolbar.items objectAtIndex:12];
        btnSave.style = UIBarButtonItemStylePlain;
        btnSave.enabled = false;
        btnSave.customView.alpha=0.4;
        btnSave.title = nil;
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
    
}


- (CGRect)zoomRectForScrollView:(UIScrollView *)scrollView withScale:(float)scale withCenter:(CGPoint)center {
    
    CGRect zoomRect;
    
    // The zoom rect is in the content view's coordinates.
    // At a zoom scale of 1.0, it would be the size of the
    // imageScrollView's bounds.
    // As the zoom scale decreases, so more content is visible,
    // the size of the rect grows.
    zoomRect.size.height = scrollView.frame.size.height / scale;
    zoomRect.size.width  = scrollView.frame.size.width  / scale;
    
    // choose an origin so as to get the right center.
    zoomRect.origin.x = center.x - (zoomRect.size.width  / 2.0);
    zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0);
    
    return zoomRect;
}

- (void)tapOnce:(UIGestureRecognizer *)gesture
{
    @try {
        if (myScrollViewTop.zoomScale > self.minimumZoomScale)
        {
            [self.myScrollViewTop setZoomScale:self.minimumZoomScale animated:YES];
        }
        else
        {
            CGPoint touch = [gesture locationInView:gesture.view];
            
            CGSize scrollViewSize = self.myScrollViewTop.bounds.size;
            
            CGFloat w = scrollViewSize.width / self.maximumZoomScale;
            CGFloat h = scrollViewSize.height / self.maximumZoomScale;
            CGFloat x = touch.x-(w/2.0);
            CGFloat y = touch.y-(h/2.0);
            
            CGRect rectTozoom=CGRectMake(x, y, w, h);
            [self.myScrollViewTop zoomToRect:rectTozoom animated:YES];
        }

    }
    @catch (NSException *exception) {
        
    }
    @finally {
    
    }
}


- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    //NSLog(@"Did zoom");
    if (scrollView.tag==MYSCROLLVIEW_TAG) {
        return myView;
    }
    else //if(scrollView.tag==MYSCROLLVIEWTOP_TAG){
        
        return myViewTop;
    //}
    
}


- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    @try {
        if(scrollView.tag==MYSCROLLVIEWTOP_TAG){
            //change the size
            //keeping the center unchanged:
            CGRect scrollFrame=CGRectMake(0, 0, 0, 0);
            double w=scrollView.contentSize.width;
            double h=scrollView.contentSize.height;
            double deltaW=(scrollView.frame.size.width - w) / 2.0;
            double deltaH=(scrollView.frame.size.height - h) / 2.0;
            if (_lastRotation!=0) {
                CGFloat newX =((scrollView.frame.size.width - w)/2) * ((1-cos(_lastRotation))/cos(_lastRotation));
                CGFloat newY =scrollView.frame.size.height/2+cos(_lastRotation)*(sqrt(pow(deltaW, 2)*pow(tan(_lastRotation),2))-deltaH)-h/2;
                //NSLog(@"NewX=%f,NewY=%f",powf(3, 2),newY);
                scrollFrame.origin = CGPointMake(newX, newY);
                scrollFrame.size = CGSizeMake(w, h);
                scrollView.bounds = scrollFrame;
            }
            else{
                scrollFrame.size = CGSizeMake(w, h);
                scrollView.bounds = scrollFrame;
            }
        }

    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}

- (void)actionGrabCutIteration;
{
    //dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [grabCutController nextIteration];
        //[self performSelectorOnMainThread:@selector(grabCutDone) withObject:nil waitUntilDone:NO];
    [self grabCutDone];
    //});
}

- (void)grabCutDone;
{
    //label.text = [NSString stringWithFormat:@"Iteration %d", grabCutController.iterCount];
    image_changed = YES;
    self.myView.image = [grabCutController getImage];
    //[self updateView];
    //[self.myView setNeedsDisplay];
    //[self indicateActivity:NO];
}



- (void)calculateScale;
{
    scale_x = self.myView.image.size.width / self.myView.bounds.size.width;
    scale_y = self.myView.image.size.height / self.myView.bounds.size.height;
}

//MARK: Get bounding rectangle of contour using open-cv
-(vector<cv::Rect>) calculateBoundingRectForContours:(TContours)contoursArr{

    /// Approximate contours to polygons + get bounding rects
    vector<vector<cv::Point> > contours_poly(contoursArr.size());
    vector<cv::Rect> rectArr(contoursArr.size());
    for( int i = 0; i < contoursArr.size(); i++ )
    {
        cv::approxPolyDP(contoursArr[i], contours_poly[i], 3, true );
        rectArr[i] = cv::boundingRect(cv::Mat(contours_poly[i]) );
    }
    return rectArr;
}

- (UIImage *)imageByDrawingCircleOnImage:(UIImage *)image1 Rect:(CGRect)rect
{
	// begin a graphics context of sufficient size
	UIGraphicsBeginImageContext(image1.size);
    
	// draw original image into the context
	[image1 drawAtPoint:CGPointZero];
    
	// get the context for CoreGraphics
	CGContextRef ctx = UIGraphicsGetCurrentContext();
    
	// set stroking color and draw circle
	[[UIColor redColor] setStroke];
    
    //set the fill color
    CGContextSetRGBFillColor(ctx, 1.0, 1.0, 1.0, 1.0);
    
	// make circle rect 5 px from border
	CGRect circleRect = CGRectMake(0, 0,
                                   image1.size.width,
                                   image1.size.height);
	circleRect = CGRectInset(circleRect, 5, 5);
    circleRect=rect;
    
	// draw circle
    //CGContextStrokeEllipseInRect(ctx, circleRect);
    
    //draw the rectangle
    CGContextFillRect(ctx, rect);
    //CGContextStrokeRect(ctx, rect);    //this will draw the border
    
	// make image out of bitmap context
	UIImage *retImage = UIGraphicsGetImageFromCurrentImageContext();
    
	// free the context
	UIGraphicsEndImageContext();
    
	return retImage;
}

//MARK: Crop a window rectangle from the image using open-cv
- (UIImage *)selectObjectsFromImageByRect:(cv::Mat)imageToCrop Rect:(CGRect)rect{
    
    //draw and fill the contours
    cv::Mat gray;
    
    drawFillContours(imageToCrop,gray, 1,50);
    //change the filled contour image to binary
    
    //create a blank Mat
    cv::Mat blank=cv::Mat::zeros(imageToCrop.rows,imageToCrop.cols, CV_8U);
    //convert to image
    UIImage *imgWithCurrentRect=[UIImageCVMatConverter UIImageFromCVMat:blank];
    //draw the rectangle
    imgWithCurrentRect=[self imageByDrawingCircleOnImage:imgWithCurrentRect Rect:self.myView.currentRect];
    //Bitwise and the 2 images for intersection
    blank=[UIImageCVMatConverter cvMatFromUIImage:imgWithCurrentRect];
    cv::cvtColor(blank, blank, CV_RGBA2GRAY);
    cv::cvtColor(gray, gray, CV_RGBA2GRAY);
    
    cv::string s=getImgType(blank.type());
    s=getImgType(gray.type());
    cv::bitwise_and(gray, blank, blank);
    return [UIImageCVMatConverter UIImageFromCVMat:gray];
    
}

//MARK: This function uses fillPloy and fillConvexPoly to draw the segmentations using open-cv
void drawFillContours(cv::Mat& img, cv::Mat& drawing,int flag,int cSize)
{
    cv::Mat overlayImg;// = [UIImageCVMatConverter cvMatFromUIImage:[UIImage imageNamed:@"my_image.jpg"]];
    cv::Mat gray,mask;
    
    /// Transform it to GRAY if not already
    
    if(img.channels()>2){
        cv::cvtColor(img, gray, CV_RGBA2GRAY);
    }
    else{
        gray=img;
    }
    
    if(overlayImg.channels()>2){
        cv::cvtColor(img, overlayImg, CV_RGBA2GRAY);
    }
    else{
        overlayImg=img;
    }
    
    cv::Canny(gray, mask, 0, 50);

    cv::copyMakeBorder(mask, mask, 1, 1, 1, 1, cv::BORDER_REPLICATE);
    cv::Point seed(100,200);
    //cv::vector<cv::vector<Point>> contours;
    cv::vector<cv::Vec4i> hierarchy;
    typedef cv::vector<cv::vector<cv::Point> > TContours;
    TContours contours;
    cv::findContours(mask, contours, hierarchy, CV_RETR_CCOMP, CV_CHAIN_APPROX_NONE);
    //cv::findContours(mask, contours, hierarchy, CV_RETR_CCOMP, CV_CHAIN_APPROX_SIMPLE);
    /// Draw contours
    
    cv::Mat drawing1 = cv::Mat::zeros( img.size(), CV_8UC3 );
    cv::Scalar color;
    const cv::Point *pttt;
    const cv::Point *ptt[1];
    int n=(int)contours.size();
    int npt[]={0};
    int lineType=8;
    if (flag >= 0) {
        for( int i = 0; i< n; i++ )
        {
            //eliminate small contours
            if (contours[i].size()>cSize){
                pttt=&contours[i][0];
                ptt[0]={contours[i].data()};
                npt[0]=(int)contours[i].size();
                //color=cvScalar(0,255,0);
                color= cvScalar( arc4random_uniform(255), arc4random_uniform(255), arc4random_uniform(255) );
                //cv::drawContours( drawing, contours, i, color, 2, 8, hierarchy, 0, cv::Point() );
                //cv::drawContours( drawing, contours, i, cv::Scalar(255), CV_FILLED);
                cv::fillConvexPoly(drawing1, pttt, (int)contours[i].size(), color);
                cv::fillPoly( drawing1,
                             ptt,
                             npt,
                             1,
                             color,
                             lineType );
            }
        }
        
        drawing=drawing1;
    }
    else
        //return a markers image suitable for watershed function.
        if (flag ==-1) {
            //CV_32S for waterShed
            cv::Mat markers(img.size(), CV_32S);
            //CV_8UC1 for meanshift
            //cv::Mat markers(img.size(), CV_8UC1);
            markers = cv::Scalar::all(0);
            for( int i = 0; i< n; i++ )
            {
                //pttt=&contours[i][0];
                ptt[0]={contours[i].data()};
                npt[0]=(int)contours[i].size();
                //color=cvScalar(0,255,0);
                color= cvScalar( arc4random_uniform(255), arc4random_uniform(255), arc4random_uniform(255) );
                cv::drawContours( markers, contours, i, color, 1, 8, hierarchy, INT_MAX, cv::Point() );
                //cv::drawContours( drawing, contours, i, cv::Scalar(255), CV_FILLED);
            }
            drawing=markers;
        }
}

//MARK:Image Segmentation with Watershed Algorithm
void waterShedSegmentation(cv::Mat &img, cv::Mat &output)
{
    cv::Mat gray,ret,thresh;
    /// Transform it to GRAY
    //try mean-shift filtering first
    //meanShiftSegmentation(img,img);

    cv::cvtColor(img, gray, CV_BGR2GRAY);
    //int x=cv::THRESH_BINARY_INV+cv::THRESH_OTSU;
    cv::threshold(gray, thresh,0,255, cv::THRESH_BINARY_INV+cv::THRESH_OTSU);
    
    //noise removal
    cv::Mat kernel=cv::Mat::ones(3,3,CV_32F);
    cv::Mat opening;
    cv::morphologyEx(thresh, opening, cv::MORPH_OPEN, kernel);
    
    //sure background area
    cv::Mat sure_bg;
    cv::dilate(opening,sure_bg,kernel);

    //Finding sure foreground area
    cv::Mat dist_transform;
    cv::distanceTransform(opening, dist_transform,  CV_DIST_L2, 5);
    
    
    cv::Mat sure_fg;
    double minVal,maxVal;
    cv::minMaxLoc(dist_transform, &minVal, &maxVal);
    cv::threshold(dist_transform,sure_fg,0.7*maxVal,255,cv::THRESH_BINARY);
    
    //Finding unknown region
    sure_fg.convertTo(sure_fg, CV_8UC1);
    

    cv::Mat unknown;
    cv::subtract(sure_bg, sure_fg, unknown);
    
    //label the sure_fg
    cv::Mat drawing;
    drawFillContours(sure_fg, drawing,-1,50);
    
    cv::Mat cvMatImage2 = sure_fg;
    cv::String s=getImgType(drawing.type());
    cv::watershed(img, drawing);
    output=drawing;

}

//MARK:Image Segmentation with Watershed Algorithm2
-(void) waterShedSegmentation2:(cv::Mat &)inputImg output:(cv::Mat&)outputImg
{
    cv::Mat hsv;
    cvtColor( inputImg, hsv, CV_BGR2HSV );
    cvtColor(hsv,inputImg,CV_HSV2BGR);
    cv::Mat binary;
    cv::cvtColor(inputImg, binary, CV_BGR2GRAY);
    cv::threshold(binary, binary, 100, 255, cv::THRESH_BINARY);
    
    
    // Eliminate noise and smaller objects
    cv::Mat fg;
    cv::erode(binary,fg,cv::Mat(),cv::Point(-1,-1),2);
    
    // Identify image pixels without objects
    cv::Mat bg;
    //use morphology to identify bg
    cv::dilate(binary,bg,cv::Mat(),cv::Point(-1,-1),3);
    cv::threshold(bg,bg,1, 128,cv::THRESH_BINARY_INV);
    
    // Create markers image
    cv::Mat markers(binary.size(),CV_8U,cv::Scalar(0));
    markers= fg+bg;
    //drawFillContours(fg, markers,-1);
    markers.convertTo(markers, CV_32S);
    
    cv::watershed(inputImg, markers);
    //markers.convertTo(markers,CV_8U);
    outputImg=markers;
    
}

//MARK: Image Segmentation with Watershed Algorithm3
-(void) waterShedSegmentation3:(cv::Mat &)inputImg output:(cv::Mat&)outputImg
{
    int i, j, compCount = 0;
    cv::Mat markerMask,imgGray,canny;
    cvtColor(inputImg, markerMask, COLOR_BGR2GRAY);
    cvtColor(markerMask, imgGray, COLOR_GRAY2BGR);
    
    //markerMask = Scalar::all(0);
    cv::Canny(markerMask, canny,100,200);
    
    cv::vector<cv::vector<cv::Point> > thisContours;
    cv::vector<cv::Vec4i> hierarchy;
    findContours(canny, thisContours, hierarchy, RETR_CCOMP, CHAIN_APPROX_SIMPLE);
    
    
    if( thisContours.empty() )
        return;
    cv::Mat markers(markerMask.size(), CV_32S);
    markers = Scalar::all(0);
    int idx = 0;
    for( ; idx >= 0; idx = hierarchy[idx][0], compCount++ )
        drawContours(markers, thisContours, idx, Scalar::all(compCount+1), -1, 8, hierarchy, INT_MAX);
    
    if( compCount == 0 )
        return;
    
    vector<Vec3b> colorTab;
    for( i = 0; i < compCount; i++ )
    {
        int b = theRNG().uniform(0, 255);//arc4random_uniform(255);//
        int g = theRNG().uniform(0, 255);//arc4random_uniform(255);//
        int r = theRNG().uniform(0, 255);//arc4random_uniform(255);//
        
        colorTab.push_back(Vec3b((uchar)b, (uchar)g, (uchar)r));
    }
    
    //check performance
    //double t = (double)getTickCount();
    watershed( inputImg, markers);
    //t = (double)getTickCount() - t;
    //NSLog( @"execution time = %gms\n", t*1000./getTickFrequency() );
    
    Mat wshed(markers.size(), CV_8UC3);
    
    // paint the watershed image
    for( i = 0; i < markers.rows; i++ )
        for( j = 0; j < markers.cols; j++ )
        {
            int index = markers.at<int>(i,j);
            if( index == -1 )
                wshed.at<Vec3b>(i,j) = Vec3b(255,255,255);
            else if( index <= 0 || index > compCount )
                wshed.at<Vec3b>(i,j) = Vec3b(0,0,0);
            else
                wshed.at<Vec3b>(i,j) = colorTab[index - 1];
        }
    
    wshed = wshed*0.5 + imgGray*0.5;
    outputImg=wshed;
}

//MARK: Color the segments
//This colors the segmentations
//img:the original image
//mask:Operation mask for floodFill that should be a single-channel 8-bit image, 2 pixels wider and 2 pixels taller  e.g:contours or canny
//colorDiff:color difference between the currently observed pixel and one of its neighbors belonging to the connected component or the seed.
void floodFillPostprocess( cv::Mat& fillImg,cv::Mat& mask, const cv::Scalar& colorDiff=cv::Scalar::all(1) )
{
    CV_Assert( !fillImg.empty() );
    //this is the passed mask
    cv::copyMakeBorder(mask, mask, 1, 1, 1, 1, cv::BORDER_REPLICATE);
    cv::Scalar color;
    for( int y = 0; y < fillImg.rows; y++ )
    {
        for( int x = 0; x < fillImg.cols; x++ )
        {
            if( mask.at<uchar>(y+1, x+1) == 0 )
            {
                color= cvScalar( arc4random_uniform(255), arc4random_uniform(255), arc4random_uniform(255) );
                //cv::Scalar newVal(img.at<cv::Vec3b>(y,x)[0], img.at<cv::Vec3b>(y,x)[1], img.at<cv::Vec3b>(y,x)[2] );
                floodFill( fillImg, mask, cv::Point(x,y), color, 0, colorDiff, colorDiff);
            }
        }
    }
}

//MARK: Meanshift segmentation
-(void) meanShiftSegmentation:(cv::Mat&)inputImg output:(cv::Mat&)outputImg{
    int spatialRad = 10;
    int colorRad = 20;
    int maxPyrLevel = 2;
    /// Transform it to HSV
    cv::Mat hsv;
    cvtColor( inputImg, hsv, CV_BGR2HSV );
    cvtColor(hsv,inputImg,CV_HSV2BGR);
    cv::pyrMeanShiftFiltering( inputImg, outputImg, spatialRad, colorRad, maxPyrLevel );
    //draw the contours on seperate image
    cv::Mat maskContours;
    
    //send the canny as mask for floodfill
    cv::Mat gray,maskCanny;
    
    //get the edge image
    cv::cvtColor(outputImg, gray, CV_RGBA2GRAY);
    cv::Canny(gray, maskCanny, 0, 50);
    
    cv::String s=getImgType(maskContours.type());
    floodFillPostprocess(inputImg,maskCanny, cv::Scalar::all(30) );
    outputImg=inputImg;
    //cv::imshow( "window", outputImg );
}

//MARK: Histogram and Back propagation
/**
 * @function Hist_and_Backproj
 * @brief Callback to Trackbar
 */
-(void) Hist_and_Backproj:(cv::Mat&)src backproj:(cv::MatND&)backproj histImg:(cv::Mat&)histImg
{
    cv::Mat/*MatND*/ hist;
    cv::Mat hsv,hsv0,hue;
    int bins = 25;
    UIImage *uIm;
    
    /// Transform it to HSV
    if ( src.elemSize() == 1 ) {
        cvtColor( src, hsv0, CV_GRAY2BGR);
        cvtColor( hsv0, hsv, CV_BGR2HSV );
    }
    else{
       cvtColor( src, hsv, CV_BGR2HSV );
    }
    
    uIm=[UIImageCVMatConverter UIImageFromCVMat:hsv];
    self.myView.image=uIm;
    [self.myView setNeedsDisplay];
    return;
    
    
    
    /// Use only the Hue value
    hue.create( hsv.size(), hsv.depth() );
    int ch[] = { 0, 0 };
    mixChannels( &hsv, 1, &hue, 1, ch, 1 );
    
    int histSize = MAX( bins, 2 );
    float hue_range[] = { 0, 180 };
    const float* ranges = { hue_range };
    
    /// Get the Histogram and normalize it
    cv::calcHist( &hue, 1, 0, cv::Mat(), hist, 1, &histSize, &ranges, true, false );
    normalize( hist, hist, 0, 255, cv::NORM_MINMAX, -1, cv::Mat() );
    
    /// Get Backprojection
    cv::calcBackProject( &hue, 1, 0, hist, backproj, &ranges, 1, true );
    
    /// Draw the backproj
    //cv::imshow( "BackProj", backproj );
    
    /// Draw the histogram
    //UIWindow *window=[[[UIApplication sharedApplication] windows] firstObject];
    //CGRect gameArea = CGRectMake(0, 0, window.bounds.size.width, window.bounds.size.height);
    int w = hist.cols;// 400;
    int h = hist.rows;//400;
    int bin_w = cvRound( (double) w / histSize );
    histImg= cv::Mat::zeros( w, h, CV_8UC3);
    
    
    for( int i = 0; i < bins; i ++ )
    { rectangle( histImg, cv::Point( i*bin_w, h ), cv::Point( (i+1)*bin_w, h - cvRound( hist.at<float>(i)*h/255.0 ) ), cvScalar( 0, 0, 255 ), -1 ); }
    
    //imshow( "Histogram", histImg );
}


//MARK: Advanced Histogram and Back-Projection
void Hist_and_Backproj_advance(cv::Mat &hsv)
{
    cv::MatND hist;
    cv::Mat mask;
    int h_bins = 30; int s_bins = 32;
    int histSize[] = { h_bins, s_bins };
    
    float h_range[] = { 0, 179 };
    float s_range[] = { 0, 255 };
    const float* ranges[] = { h_range, s_range };
    
    int channels[] = { 0, 1 };
    
    /// Get the Histogram and normalize it
    cv::calcHist( &hsv, 1, channels, mask, hist, 2, histSize, ranges, true, false );
    
    normalize( hist, hist, 0, 255, cv::NORM_MINMAX, -1, cv::Mat() );
    
    /// Get Backprojection
    cv::MatND backproj;
    calcBackProject( &hsv, 1, channels, hist, backproj, ranges, 1, true );
    
    /// Draw the backproj
    imshow( "BackProj", backproj );
    
}

// take number image type number (from cv::Mat.type()), get OpenCV's enum string.
cv::string getImgType(int imgTypeInt)
{
    int numImgTypes = 35; // 7 base types, with five channel options each (none or C1, ..., C4)
    
    int enum_ints[] =       {CV_8U,  CV_8UC1,  CV_8UC2,  CV_8UC3,  CV_8UC4,
        CV_8S,  CV_8SC1,  CV_8SC2,  CV_8SC3,  CV_8SC4,
        CV_16U, CV_16UC1, CV_16UC2, CV_16UC3, CV_16UC4,
        CV_16S, CV_16SC1, CV_16SC2, CV_16SC3, CV_16SC4,
        CV_32S, CV_32SC1, CV_32SC2, CV_32SC3, CV_32SC4,
        CV_32F, CV_32FC1, CV_32FC2, CV_32FC3, CV_32FC4,
        CV_64F, CV_64FC1, CV_64FC2, CV_64FC3, CV_64FC4};
    
    cv::string enum_strings[] = {"CV_8U",  "CV_8UC1",  "CV_8UC2",  "CV_8UC3",  "CV_8UC4",
        "CV_8S",  "CV_8SC1",  "CV_8SC2",  "CV_8SC3",  "CV_8SC4",
        "CV_16U", "CV_16UC1", "CV_16UC2", "CV_16UC3", "CV_16UC4",
        "CV_16S", "CV_16SC1", "CV_16SC2", "CV_16SC3", "CV_16SC4",
        "CV_32S", "CV_32SC1", "CV_32SC2", "CV_32SC3", "CV_32SC4",
        "CV_32F", "CV_32FC1", "CV_32FC2", "CV_32FC3", "CV_32FC4",
        "CV_64F", "CV_64FC1", "CV_64FC2", "CV_64FC3", "CV_64FC4"};
    
    for(int i=0; i<numImgTypes; i++)
    {
        if(imgTypeInt == enum_ints[i])
            return enum_strings[i];
    }
    return "unknown image type";
}

static int floodFillImage (cv::Mat &image, int premultiplied, int x, int y, int color)
{
    cv::Mat out;
    
    // convert to no alpha
    cv::cvtColor(image, out, CV_BGRA2BGR);
    
    // create our mask
    cv::Mat mask = cv::Mat::zeros(image.rows + 2, image.cols + 2, CV_8U);
    
    // floodfill the mask
    cv::floodFill(
                  out,
                  mask,
                  cv::Point(x,y),
                  255,
                  0,
                  cv::Scalar(),
                  cv::Scalar(),
                  + (255 << 8) + cv::FLOODFILL_MASK_ONLY);
    
    // set new image color
    cv::Mat newImage(image.size(), image.type());
    cv::Mat maskedImage(image.size(), image.type());
    
    // set the solid color we will mask out of
    //-----newImage = cv::Scalar(ARGB_BLUE(color), ARGB_GREEN(color), ARGB_RED(color), ARGB_ALPHA(color));
    
    // crop the 2 extra pixels w and h that were given before
    cv::Mat maskROI = mask(cv::Rect(1,1,image.cols,image.rows));
    
    // mask the solid color we want into new image
    newImage.copyTo(maskedImage, maskROI);
    
    // pre multiply the colors
    //-----premultiplyBGRA2RGBA(maskedImage, image);
    
    return 0;
}

#pragma mark - Cropping the Image

- (UIImage *)croppIngimageByImageName:(UIImage *)imageToCrop toRect:(CGRect)rect{
    
    CGImageRef imageRef = CGImageCreateWithImageInRect([imageToCrop CGImage], rect);
    UIImage *cropped = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    
    return cropped;
    
    
}

#pragma mark - Marge two Images

- (UIImage *) addImageToImage:(UIImage *)img1 withImage2:(UIImage *)img2 andRect:(CGRect)cropRect{
    
    CGSize size = CGSizeMake(self.myView.image.size.width, self.myView.image.size.height);
    UIGraphicsBeginImageContext(size);
    
    CGPoint pointImg1 = CGPointMake(0,0);
    [img1 drawAtPoint:pointImg1];
    
    CGPoint pointImg2 = cropRect.origin;
    //CIImage *tmp1=[[CIImage alloc] initWithColor:(CIColor *)[UIColor blueColor]];
    //UIImage *tmp=(UIImage*)tmp1;
    //UIImage *tmp=[UIImage imageNamed:@"photo.jpg"];
    //[tmp drawInRect:cropRect];
    
    [img2 drawAtPoint: pointImg2];
    
    UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

- (UIImage *)imageResize:(UIImage *)imageC scaledToSize:(CGSize)newSize
{
    UIGraphicsBeginImageContext(newSize);
    [imageC drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}



- (UIImage *) addImageToImage1:(UIImage *)img1 withImage2:(UIImage *)img2 andRect:(CGRect)cropRect
{
    @try {

        //NSLog(@"last rotation=%lf",_rotation);
        
        CGSize size = CGSizeMake(img1.size.width, img1.size.height);

        UIGraphicsBeginImageContextWithOptions(size, NO, img1.scale);
        
        CGPoint pointImg1 = CGPointMake(0,0);
        [img1 drawAtPoint:pointImg1];
        
        [img2 drawInRect:cropRect];
        
        UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return result;

    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}

-(UIImage*) addToImage:(UIImage *)baseImage newImage:(UIImage*)newImage atPoint:(CGPoint)point transform:(CGAffineTransform)transform {
    
    //UIGraphicsBeginImageContext(baseImage.size);
    UIGraphicsBeginImageContextWithOptions(baseImage.size, NO, baseImage.scale);
    
    
    CGPoint pointImg1 = CGPointMake(0,0);
    [baseImage drawAtPoint:pointImg1];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextConcatCTM(context, transform);
    [newImage drawAtPoint:point];
    
    UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

-(UIImage*)transformImage:(UIImage *)baseImage transform:(CGAffineTransform)transform {
    //CGAffineTransform transform = ...;
    CIImage* coreImage = baseImage.CIImage;
    
    if (!coreImage) {
        coreImage = [CIImage imageWithCGImage:baseImage.CGImage];
    }
    coreImage = [coreImage imageByApplyingTransform:transform];
    return [UIImage imageWithCIImage:coreImage];
}


- (UIImage *)imageRotatedByDegrees1:(UIImage *)imageToCrop degrees:(CGFloat)deg rect:(CGRect)cropRect
{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,cropRect.size.width, cropRect.size.height)];
    //CGAffineTransform t = CGAffineTransformMakeRotation(DegreesToRadians(deg));
    CGAffineTransform t = CGAffineTransformMakeRotation(deg);
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    
    // Create the bitmap context
    UIGraphicsBeginImageContext(rotatedSize);
    
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    //CGContextTranslateCTM(bitmap, 0, 0);
    
    //   // Rotate the image context
    //CGContextRotateCTM(bitmap, DegreesToRadians(deg));
    CGContextRotateCTM(bitmap, deg);
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-imageToCrop.size.width / 2, -imageToCrop.size.height / 2, imageToCrop.size.width, imageToCrop.size.height), [imageToCrop CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
    
}

- (UIImage *)imageRotatedByDegrees:(UIImage *)imageToCrop degrees:(CGFloat)deg
{
    @try {
        if (imageToCrop !=nil) {
           // NSLog(@"IW=%f,IH=%f",imageToCrop.size.width,imageToCrop.size.height);
            //NSLog(@"FW=%f,FH=%f",myScrollViewTop.frame.size.width*myViewTop.ratioW,myScrollViewTop.frame.size.height*myViewTop.ratioH);
            
            // calculate the size of the rotated view's containing box for our drawing space
            //double aspectFitSize=MIN(imageToCrop.size.width,imageToCrop.size.height);
            double aspectWidth,aspectHeight;
            double frameAspectRatio=myScrollViewTop.frame.size.width/myScrollViewTop.frame.size.height;
            UIView *rotatedViewBox;
            if (imageToCrop.size.width>imageToCrop.size.height) {
                aspectWidth=imageToCrop.size.height*frameAspectRatio;
                aspectHeight=imageToCrop.size.height;
                
            }
            else {
                aspectWidth=imageToCrop.size.width;
                aspectHeight=imageToCrop.size.height;
                
            }
            rotatedViewBox= [[UIView alloc] initWithFrame:CGRectMake(0,0,aspectWidth, aspectHeight)];
            
            //CGAffineTransform t = CGAffineTransformMakeRotation(DegreesToRadians(deg));
            CGAffineTransform t = CGAffineTransformMakeRotation(deg);
            rotatedViewBox.transform = t;
            CGSize rotatedSize = rotatedViewBox.frame.size;
            
            // Create the bitmap context
            //UIGraphicsBeginImageContext(rotatedSize);
            UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, imageToCrop.scale);
            CGContextRef bitmap = UIGraphicsGetCurrentContext();
            
            // Move the origin to the middle of the image so we will rotate and scale around the center.
            CGContextTranslateCTM(bitmap, floor(rotatedSize.width/2), floor(rotatedSize.height/2));
            //CGContextTranslateCTM(bitmap, 0, 0);
            
            //   // Rotate the image context
            //CGContextRotateCTM(bitmap, DegreesToRadians(deg));
            CGContextRotateCTM(bitmap, deg);
            
            // Now, draw the rotated/scaled image into the context
            CGContextScaleCTM(bitmap, 1.0, -1.0);
            CGContextDrawImage(bitmap, CGRectMake(-floor(aspectWidth / 2), -floor(aspectHeight / 2), aspectWidth,   aspectHeight), [imageToCrop CGImage]);//removed now
            //CGContextDrawImage(bitmap, CGRectMake(-floor(imageToCrop.size.width / 2), -floor(imageToCrop.size.height / 2), floor(myScrollViewTop.frame.size.width*myView.ratioW), floor(myScrollViewTop.frame.size.height*myView.ratioH)), [imageToCrop CGImage]);//added now
            
            
            UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            return newImage;
        }
        else{
            return nil;
        }

    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
    
}


#pragma mark - RoundRect the Image

- (UIImage *)roundedRectImageFromImage:(UIImage *)image1 withRadious:(CGFloat)radious {
    @try {
        if(radious == 0.0f)
            return image1;
        
        if( image1 != nil) {
            
            CGFloat imageWidth = image1.size.width;
            CGFloat imageHeight = image1.size.height;
            
            CGRect rect = CGRectMake(0.0f, 0.0f, imageWidth, imageHeight);
            UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
            const CGFloat scale = window.screen.scale;
            UIGraphicsBeginImageContextWithOptions(rect.size, NO, scale);
            
            CGContextRef context = UIGraphicsGetCurrentContext();
            
            CGContextBeginPath(context);
            CGContextSaveGState(context);
            CGContextTranslateCTM (context, CGRectGetMinX(rect), CGRectGetMinY(rect));
            CGContextScaleCTM (context, radious, radious);
            
            CGFloat rectWidth = CGRectGetWidth (rect)/radious;
            CGFloat rectHeight = CGRectGetHeight (rect)/radious;
            
            CGContextMoveToPoint(context, rectWidth, rectHeight/2.0f);
            CGContextAddArcToPoint(context, rectWidth, rectHeight, rectWidth/2.0f, rectHeight, radious);
            CGContextAddArcToPoint(context, 0.0f, rectHeight, 0.0f, rectHeight/2.0f, radious);
            CGContextAddArcToPoint(context, 0.0f, 0.0f, rectWidth/2.0f, 0.0f, radious);
            CGContextAddArcToPoint(context, rectWidth, 0.0f, rectWidth, rectHeight/2.0f, radious);
            CGContextRestoreGState(context);
            CGContextClosePath(context);
            CGContextClip(context);
            
            [image1 drawInRect:CGRectMake(0.0f, 0.0f, imageWidth, imageHeight)];
            
            UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            return newImage;
        }
        return nil;

    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}


#pragma mark - Touch Methods

- (IBAction)actionGrabCut:(id)sender;
{
    self.myView.image = [self selectObjectsFromImageByRect:res Rect:self.myView.currentRect];
    [self.myView setNeedsDisplay];
    
}

- (IBAction)toogleSelectDraw:(id)sender;
{
    //CHECK IF rect crop button was pressed
    UIBarButtonItem *btnRect=[self.myToolbar.items objectAtIndex:4];
    btnRect.style = UIBarButtonItemStylePlain;
    
    UIBarButtonItem *btnDraw=[self.myToolbar.items objectAtIndex:6];
    btnDraw.style = UIBarButtonItemStylePlain;
    
    
    //NSLog(@"rect alpha=%f",btnRect.customView.alpha);
    //flip the selection
    if (btnDraw.customView.alpha<1) {
        btnDraw.customView.alpha=1;
        btnRect.customView.alpha=0.4;
    }
    else{
        myScrollView.scrollEnabled=!(myScrollView.scrollEnabled);
        
        
        if (myScrollView.scrollEnabled) {
            btnRect.customView.alpha=1;
        }
        else{
            btnRect.customView.alpha=0.4;
        }
    }
    [self.myView setShapeType:KRectShape];
    //[self.myToolbar setHidden:YES];
}

- (void)test1{
     //NSLog(@"myScrollView.subviews.count before picker=%lu",(unsigned long)self.myScrollView.subviews.count);
}

- (void)actionShowPhotoLibrary
{
    [self removeSegSlider];
    self.pickBtnFlag=pickBtn_TAG;
//    if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad){
//        
//        UIPopoverController* popOverController = [[UIPopoverController alloc] initWithContentViewController:self.imagePicker];
//        [popOverController presentPopoverFromRect:CGRectMake(0, 0, 100, 100) inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
//        
//    }else {
        [self presentViewController:self.imagePicker animated:YES completion:nil];
    //}
}

- (void)actionShowPhotoLibrary1
{
    self.pickBtnFlag=pick2Btn_TAG;
    [self presentViewController:self.imagePicker animated:YES completion:nil];
}


- (void)updateUI;
{
    [self.myView setNeedsDisplay];
}

- (NSUInteger)supportedInterfaceOrientations
{
    NSUInteger orientations = UIInterfaceOrientationMaskPortrait;
    return orientations;
}


- (void)didReceiveMemoryWarning
{
    if (!memWarnig){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@" Memory Warning"
                                                        message:@"You are working with large size image"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        alert=nil;
    }

    memWarnig=1;
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    
    if ([self.presentedViewController isBeingDismissed]) {
        //NSLog(@"i am being dismissed");
    }
    if ([self.presentedViewController isBeingPresented]) {
        //NSLog(@"i am being presented");
        return;
    }
    
    /* release your custom data which will be rebuilt in loadView or viewDidLoad */
    image=nil;
    myView.image=nil;
    //[myView setNeedsDisplay];
    [myView.imagesArray removeAllObjects];
    myView.imagesArray=nil;
    [self enableButtons];
}


#pragma mark - Protocol UIImagePickerControllerDelegate

//- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)imge editingInfo:(NSDictionary *)editInfo
//{
//    
//}

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    @try {
        self.image=nil;
        //    self.myView.image=nil;
        //    [self.myView setNeedsDisplay];
        if (self.pickBtnFlag==pickBtn_TAG) {
            popImage=[info objectForKey:UIImagePickerControllerOriginalImage];
            //remove the previous image history
            @autoreleasepool {
                if (myView.imagesArray.count>0) {
                    [myView.imagesArray removeAllObjects];
                    myView.imagesArray=nil;
                    //NSLog(@"i am in array>0");
                }
            }
            [self enableButtons];
            //imge=nil;
            self.imageRect=[self calculateSizeofFrame:myView.image];
            myView.frameRect=self.imageRect;
            [picker dismissViewControllerAnimated:NO completion:^{
                [self performSelector:@selector(presentVC2)
                           withObject:nil];
            }];
            picker = nil;
        }
        else if (self.pickBtnFlag==pick2Btn_TAG){
            UIImage* beginImage = [info objectForKey:UIImagePickerControllerOriginalImage];
            if (beginImage.imageOrientation == UIImageOrientationUp) {
                //NSLog(@"portrait");
            } else if (beginImage.imageOrientation == UIImageOrientationLeft || beginImage.imageOrientation == UIImageOrientationRight) {
                //NSLog(@"landscape");
                beginImage=[beginImage imageAdjustedForOrientation];
            }
            UIImage *imge =[[UIImage alloc] initWithCGImage:beginImage.CGImage scale:DISPLAY_SCALE orientation:UIImageOrientationUp];
            beginImage=nil;
            //if(self.rootFlag!=-1 || self.pickBtnFlag==pick2Btn_TAG){
            CGRect r= [self calculateSizeofFrame:imge];
            myView.frameRect=r;
            
            //disable crop buttons
            UIBarButtonItem *btnRectSelect=[self.myToolbar.items objectAtIndex:4];
            btnRectSelect.style = UIBarButtonItemStylePlain;
            btnRectSelect.enabled = false;
            btnRectSelect.customView.alpha=0.4;
            btnRectSelect.title = nil;
            
            UIBarButtonItem *btnDrawSelect=[self.myToolbar.items objectAtIndex:6];
            btnDrawSelect.style = UIBarButtonItemStylePlain;
            btnDrawSelect.enabled = false;
            btnDrawSelect.customView.alpha=0.4;
            btnDrawSelect.title = nil;
            
            //enable save button
            //enable save button
            UIBarButtonItem *btnSave=[self.myToolbar.items objectAtIndex:12];
            btnSave.style = UIBarButtonItemStylePlain;
            btnSave.enabled = true;
            btnSave.customView.alpha=1.0;
            btnSave.title = nil;
            
            
            if (myViewTop==nil) {
                //move the current image to top
                self.imageTop=myView.image;
                
                //set the background image from selection
                self.myView.image=imge;
                
                //update the frame of background image
                CGRect rb=CGRectMake(0, 0, 0, 0);
                rb=[self calculateSizeofFrame:myView.image];
                myView.frameRect=r;
                //self.imageRect=r;
                
                //draw the background image in all view
                self.myView.shapeType=KImageShape;
                [self.myView setNeedsDisplay];
                
                //add a scrollview for top image
                [self addScrollView2:self.imageTop];
                self.imageTop=nil;
                self.myScrollViewTop.scrollEnabled=NO;
            }
            //if we change where to paste before saving"i.e click multiple paste"
            else{
                //set the background image from selection
                self.myView.image=imge;
                
                //update the frame of background image
                CGRect rb=CGRectMake(0, 0, 0, 0);
                rb=[self calculateSizeofFrame:myView.image];
                myView.frameRect=r;
                //self.imageRect=r;
                
                //draw the background image in all view
                self.myView.shapeType=KImageShape;
                [self.myView setNeedsDisplay];
            }
            
            [picker dismissViewControllerAnimated:NO completion:nil];
            picker = nil;
        }

    }
    @catch (NSException *exception) {
        
    }
    @finally {

    }
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker;
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    picker = nil;
}

- (UIViewController *) firstAvailableUIViewController {
    @try {
        // convenience function for casting and to "mask" the recursive function
        return (UIViewController *)[self app_viewController];
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}

- (UIViewController *)app_viewController {
    
    @try {
        /// Finds the view's view controller.
        // Take the view controller class object here and avoid sending the same message iteratively unnecessarily.
        Class vcc = [UIViewController class];
        ViewController *rootVC;
        
        // Traverse responder chain. Return first found view controller, which will be the view's view controller.
        UIResponder *responder = self;
        while ((responder = [responder nextResponder]))
            if ([responder isKindOfClass: vcc])
            {
                rootVC=(ViewController*)responder;
                if (rootVC.rootFlag!=-1) {
                    return (UIViewController *)responder;
                }
            }
        
        // If the view controller isn't found, return nil.
        return nil;
    }
    @catch (NSException *exception) {
        
    }
    @finally {
    
    }
    
}



-(CGRect) calculateSizeofFrame:(UIImage *)imgF{
    @try {
        UIWindow *window=[[[UIApplication sharedApplication] windows] firstObject];
        CGRect r;
        if (imgF) {
            
            r= CGRectMake(0,0,
                          (window.bounds.size.width > imgF.size.width*imgF.scale)?imgF.size.width*imgF.scale : window.bounds.size.width,
                          (window.bounds.size.height > imgF.size.height*imgF.scale)?imgF.size.height*imgF.scale : window.bounds.size.height);
        }
        else
            r=CGRectMake(0, 0, window.bounds.size.width, window.bounds.size.height);
        return r;
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}


#pragma mark UIGestureRegognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    //return ![gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] && ![gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]];
    return YES;
}

@end
