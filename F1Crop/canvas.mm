//
//  canvas.m
//  cropImageWithoutCV_1
//
//  Created by Mohammad Dawi on 9/10/14.
//  Copyright (c) 2014 Mohammad Dawi. All rights reserved.
//

#import "canvas.h"
#import <opencv2/opencv.hpp>
#import "ViewController.h"
#import <CoreText/CoreText.h>
#define SUBVIEW_TAG 9999

// return true if the device has a retina display, false otherwise
#define IS_RETINA_DISPLAY() [[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0f

// return the scale value based on device's display (2 retina, 1 other)
#define DISPLAY_SCALE IS_RETINA_DISPLAY() ? 2.0f : 1.0f

// if the device has a retina display return the real scaled pixel size, otherwise the same size will be returned
#define PIXEL_SIZE(size) IS_RETINA_DISPLAY() ? CGSizeMake(size.width/2.0f, size.height/2.0f) : size


using namespace cv;

@implementation canvas

static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

@synthesize location;
@synthesize currentRect,frameRect;
@synthesize flag;
@synthesize currentLocation;
@synthesize image;
@synthesize imageView;
@synthesize markerMask;
@synthesize context;
@synthesize imageRef;
@synthesize dpath;
@synthesize haveSave;
@synthesize shapeType;
@synthesize path;
@synthesize contoursTouchDraw,contoursTouchDrawFrame;
@synthesize contoursTouchCounter;
@synthesize contoursTouchRect,contoursTouchRectFrame;
@synthesize tmpContour,tmpContourFrame;
@synthesize croppedImage;
@synthesize rootSV;
@synthesize p,pf;
@synthesize ratioH;
@synthesize ratioW;
@synthesize imageBkp;
@synthesize draggable;
@synthesize imagesArray;



- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        path = [UIBezierPath bezierPath];
        [path setLineWidth:1.0];
        self.ratioW=1.0;
        self.ratioH=1.0;
    }
    return self;
}


- (id)initWithCoder:(NSCoder *)aDecoder {
    if ( (self = [super initWithCoder:aDecoder]) ) {
        [self setMultipleTouchEnabled:YES];
        path = [UIBezierPath bezierPath];
        [path setLineWidth:1.0];
    }
    return self;
}

- (UIViewController *) firstAvailableUIViewController {
    // convenience function for casting and to "mask" the recursive function
    return (UIViewController *)[self app_viewController];
}

- (id) traverseResponderChainForUIViewController {
    id nextResponder = [self nextResponder];
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        return nextResponder;
    } else if ([nextResponder isKindOfClass:[UIView class]]) {
        return [nextResponder traverseResponderChainForUIViewController];
    } else {
        return nil;
    }
}

- (UIViewController *)app_viewController {
    /// Finds the view's view controller.
    
    // Take the view controller class object here and avoid sending the same message iteratively unnecessarily.
    Class vcc = [UIViewController class];
    
    // Traverse responder chain. Return first found view controller, which will be the view's view controller.
    UIResponder *responder = self;
    while ((responder = [responder nextResponder]))
        if ([responder isKindOfClass: vcc])
            return (UIViewController *)responder;
    
    // If the view controller isn't found, return nil.
    return nil;
}




- (UIImage *)imageRotatedByDegrees:(UIImage *)imageToCrop degrees:(CGFloat)deg
{
    // calculate the size of the rotated view's containing box for our drawing space
    UIView *rotatedViewBox = [[UIView alloc] initWithFrame:CGRectMake(0,0,imageToCrop.size.width, imageToCrop.size.height)];
    CGAffineTransform t = CGAffineTransformMakeRotation(DegreesToRadians(deg));
    rotatedViewBox.transform = t;
    CGSize rotatedSize = rotatedViewBox.frame.size;
    
    // Create the bitmap context
    //UIGraphicsBeginImageContext(rotatedSize);
    UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, 0.0f);
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    
    // Move the origin to the middle of the image so we will rotate and scale around the center.
    //CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    CGContextTranslateCTM(bitmap, 0, 0);
    
    //   // Rotate the image context
    CGContextRotateCTM(bitmap, DegreesToRadians(deg));
    
    // Now, draw the rotated/scaled image into the context
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    CGContextDrawImage(bitmap, CGRectMake(-imageToCrop.size.width / 2, -imageToCrop.size.height / 2, imageToCrop.size.width, imageToCrop.size.height), [imageToCrop CGImage]);
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
    
}


-(CGRect) translateRect:(CGRect) rect toOrigin:(CGPoint)np fromOrigin:(CGPoint)op{

    //get the center of frame rect
    CGPoint rectOrigin;
    rectOrigin.x=rect.origin.x;
    rectOrigin.y=rect.origin.y;
    
    //translation factors
    float tx=np.x-op.x;
    float ty=np.y-op.y;
    
    float originFrameNewx=rectOrigin.x-tx;
    float originFrameNewy=rectOrigin.y-ty;
    
     CGRect r=CGRectMake(originFrameNewx, originFrameNewy, rect.size.width, rect.size.height);
    return r;
    
}

-(CGPoint) translatePoint:(CGPoint) pt toOrigin:(CGPoint)np fromOrigin:(CGPoint)op{
    
    //translation factors
    int tx=np.x-op.x;
    int ty=np.y-op.y;
    
    CGFloat originFrameNewx=pt.x-tx;
    CGFloat originFrameNewy=pt.y-ty;
    
    CGPoint newp=CGPointMake(originFrameNewx, originFrameNewy);
    return newp;
    
}


#pragma mark - Cropping the Image

- (UIImage *)croppIngimageByImageName:(UIImage *)imageToCrop toRect:(CGRect)rect{
    
    if (imageToCrop!=nil) {
        @try {
            //To crop retina images while keeping the same scale and orientation
            CGRect rectImg;
            if (imageToCrop.scale > 1.0f) {
                //NSLog(@"i am in rect image scale>1");
                rectImg=CGRectMake(floor(rect.origin.x * imageToCrop.scale),
                                   floor(rect.origin.y * imageToCrop.scale),
                                   floor(rect.size.width * imageToCrop.scale),
                                   floor(rect.size.height * imageToCrop.scale));
            }
            else
                rectImg=rect;
            
            @autoreleasepool {
                if (imagesArray==nil) {
                    imagesArray=[[NSMutableArray alloc]initWithObjects:nil] ;
                }
                [imagesArray addObject:imageToCrop];
            }
            
            CGImageRef imageReff = CGImageCreateWithImageInRect([imageToCrop CGImage], rectImg);
            UIImage *cropped = [UIImage imageWithCGImage:imageReff];
            CGImageRelease(imageReff);
            
            //remove the cropped part from original image
            UIBezierPath *rPath = [UIBezierPath bezierPath];
            
            //UIGraphicsBeginImageContext(imageToCrop.size);
            UIGraphicsBeginImageContextWithOptions(imageToCrop.size, NO,imageToCrop.scale);
            [imageToCrop drawAtPoint:CGPointZero];
            
            CGContextRef contxt = UIGraphicsGetCurrentContext();
            // Clip to the bezier path and clear that portion of the image.
            CGContextMoveToPoint (contxt, CGRectGetMinX(rect), CGRectGetMinY(rect));
            
            // add bottom edge
            CGContextAddLineToPoint (contxt, CGRectGetMaxX(rect), CGRectGetMinY(rect));
            
            // add right edge
            CGContextAddLineToPoint (contxt, CGRectGetMaxX(rect), CGRectGetMaxY(rect));
            
            // add top edge
            CGContextAddLineToPoint (contxt, CGRectGetMinX(rect), CGRectGetMaxY(rect));
            
            // add left edge and close
            CGContextClosePath (contxt);
            CGContextAddPath(contxt,rPath.CGPath);
            CGContextClip(contxt);
            //CGContextSetRGBFillColor(contxt,0,0,0,0);
            //CGContextFillRect (contxt,CGRectMake(0,0,imageToCrop.size.width,imageToCrop.size.height));
            CGContextClearRect(contxt,CGRectMake(0,0,imageToCrop.size.width,imageToCrop.size.height));
            
            // Build a new UIImage from the image context.
            imageToCrop = UIGraphicsGetImageFromCurrentImageContext();
            //self.image=UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            self.image=imageToCrop;
            
            return cropped;

        }
        @catch (NSException *exception) {

            return nil;
        }
        @finally {
        }
            }
    else
    {
        return nil;
    }
}

- (UIImage *)croppIngimageByImageName2:(UIImage *)imageToCrop toPoly:(SPolygon)poly inRect:(CGRect)rect{
    
    if (imageToCrop!=nil) {
        @try {
            @autoreleasepool {
                if (imagesArray==nil) {
                    imagesArray=[[NSMutableArray alloc]initWithObjects:nil] ;
                }
                [imagesArray addObject:imageToCrop];
            }
            
            
            //create a path using the poly array of points
            UIBezierPath *aPath = [UIBezierPath bezierPath];
            //[aPath setLineWidth:1.0];
            cv::Point pt;
            
            //CGContextBeginPath(contxt);
            for( int i = 0; i < poly.size(); i++ ){
                // Set the starting point of the shape.
                if (poly[i].size()>0) {
                    pt=poly[i][0];
                    [aPath moveToPoint:CGPointMake(pt.x, pt.y)];
                    for(int j=1; j<poly[i].size(); j++){
                        pt=poly[i][j];
                        [aPath addLineToPoint:CGPointMake(pt.x, pt.y)];
                    }
                }
            }
            [aPath closePath];
            // Create an image context containing the croppped UIImage.
            //UIGraphicsBeginImageContext(imageToCrop.size);
            UIGraphicsBeginImageContextWithOptions(imageToCrop.size, NO, imageToCrop.scale);
            [imageToCrop drawAtPoint:CGPointZero];
            
            CGContextRef contxt = UIGraphicsGetCurrentContext();
            //CGContextSaveGState(contxt);
            CGContextAddPath(contxt,aPath.CGPath);
            //CGContextRestoreGState(contxt);
            //subtract selction from original image
            CGContextClip(contxt);
            //CGContextSetRGBFillColor(contxt,234,0,0,0);
            //CGContextFillRect (contxt,CGRectMake(0,0,imageToCrop.size.width,imageToCrop.size.height));
            CGContextClearRect(contxt,CGRectMake(0,0,imageToCrop.size.width,imageToCrop.size.height));
            
            //self.imageBkp.push_back(self.image);
            self.image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            
            //get the cropped part
            //set the path once again
            [aPath removeAllPoints];
            //CGContextBeginPath(contxt);
            for( int i = 0; i < poly.size(); i++ ){
                // Set the starting point of the shape.
                if (poly[i].size()>0) {
                    pt=poly[i][0];
                    [aPath moveToPoint:CGPointMake(pt.x, pt.y)];
                    for(int j=1; j<poly[i].size(); j++){
                        pt=poly[i][j];
                        [aPath addLineToPoint:CGPointMake(pt.x, pt.y)];
                    }
                }
            }
            [aPath closePath];
            
            //UIGraphicsBeginImageContext(imageToCrop.size);
            UIGraphicsBeginImageContextWithOptions(imageToCrop.size, NO, imageToCrop.scale);
            
            contxt = UIGraphicsGetCurrentContext();
            CGContextAddPath(contxt,aPath.CGPath);
            CGContextClip(contxt);
            [imageToCrop drawAtPoint:CGPointZero];
            // Clip to the bezier path and clear that portion of the image.
            
            // Build a new UIImage from the image context.
            UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
            //To crop retina images while keeping the same scale and orientation
            if (imageToCrop.scale > 1.0f) {
                //NSLog(@"i am in draw image scale>1");
                rect=CGRectMake(floor(rect.origin.x * imageToCrop.scale),
                                floor(rect.origin.y * imageToCrop.scale),
                                floor(rect.size.width * imageToCrop.scale),
                                floor(rect.size.height * imageToCrop.scale));
            }
            //first create the cropped image by the enclosing rectangle
            CGImageRef imageReff = CGImageCreateWithImageInRect([newImage CGImage], rect);
            UIImage *cropped = [UIImage imageWithCGImage:imageReff];
            CGImageRelease(imageReff);
            
            return cropped;
        }
        @catch (NSException *exception) {
            return nil;
        }
        @finally {
            
        }
    }
    else
        return nil;
}

-(CGRect)croppedRect:(UIImage *)imageB scaledToSize:(CGSize)newSize {
    double ratio;
    double delta;
    CGPoint offset;
    
    //make a new square size, that is the resized imaged width
    //CGSize sz = CGSizeMake(newSize.width, newSize.width);
    
    //figure out if the picture is landscape or portrait, then
    //calculate scale factor and offset
    if (imageB.size.width > imageB.size.height) {
        ratio = newSize.width / imageB.size.width;
        delta = (ratio*image.size.width - ratio*imageB.size.height);
        offset = CGPointMake(delta/2, 0);
    } else {
        ratio = newSize.width / imageB.size.height;
        delta = (ratio*imageB.size.height - ratio*imageB.size.width);
        offset = CGPointMake(0, delta/2);
    }
    
    //make the final clipping rect based on the calculated values
    CGRect clipRect = CGRectMake(-offset.x, -offset.y,
                                 (ratio * imageB.size.width) + delta,
                                 (ratio * imageB.size.height) + delta);
    return clipRect;
    
}



#pragma mark - Marge two Images

- (UIImage *) addImageToImage:(UIImage *)img1 withImage2:(UIImage *)img2 andRect:(CGRect)cropRect{
    
    CGSize size = CGSizeMake(self.image.size.width, self.image.size.height);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    
    CGPoint pointImg1 = CGPointMake(0,0);
    [img1 drawAtPoint:pointImg1];
    
    CGPoint pointImg2 = cropRect.origin;
    
    [img2 drawAtPoint: pointImg2];
    
    UIImage* result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}



#pragma mark - RoundRect the Image

- (UIImage *)roundedRectImageFromImage:(UIImage *)image1 withRadious:(CGFloat)radious {
    
    if(radious == 0.0f)
        return image1;
    
    if( image1 != nil) {
        
        CGFloat imageWidth = image1.size.width;
        CGFloat imageHeight = image1.size.height;
        
        CGRect rect = CGRectMake(0.0f, 0.0f, imageWidth, imageHeight);
        UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
        
        CGContextRef context1 = UIGraphicsGetCurrentContext();
        
        CGContextBeginPath(context1);
        CGContextSaveGState(context1);
        CGContextTranslateCTM (context1, CGRectGetMinX(rect), CGRectGetMinY(rect));
        CGContextScaleCTM (context1, radious, radious);
        
        CGFloat rectWidth = CGRectGetWidth (rect)/radious;
        CGFloat rectHeight = CGRectGetHeight (rect)/radious;
        
        CGContextMoveToPoint(context1, rectWidth, rectHeight/2.0f);
        CGContextAddArcToPoint(context1, rectWidth, rectHeight, rectWidth/2.0f, rectHeight, radious);
        CGContextAddArcToPoint(context1, 0.0f, rectHeight, 0.0f, rectHeight/2.0f, radious);
        CGContextAddArcToPoint(context1, 0.0f, 0.0f, rectWidth/2.0f, 0.0f, radious);
        CGContextAddArcToPoint(context1, rectWidth, 0.0f, rectWidth, rectHeight/2.0f, radious);
        CGContextRestoreGState(context1);
        CGContextClosePath(context1);
        CGContextClip(context1);
        
        [image1 drawInRect:CGRectMake(0.0f, 0.0f, imageWidth, imageHeight)];
        
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        return newImage;
    }
    return nil;
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint pTemp;
    UITouch *touch = [touches anyObject];
    self.location=[touch locationInView:self];
    self.currentLocation=[touch locationInView:self];
    //get the parent view controller and add a modal view controller
    ViewController *vc = (ViewController *)[self firstAvailableUIViewController];
    if (self.draggable) {
        UIScrollView *motherSV=(UIScrollView *)rootSV.superview;
        motherSV.scrollEnabled=NO;
        //NSLog(@"i am in draggable");
        [vc.myToolbar setHidden:YES];
    }
    else{
        if (vc.myView.shapeType==KLineShape) {
            [vc actionShowPhotoLibrary];
        }
        else {
            rootSV=(UIScrollView *)self.superview;
            //[path moveToPoint:p];
            if (contoursTouchCounter > 0) {
                contoursTouchCounter++;
            }
            if(!rootSV.scrollEnabled){
                [vc.myToolbar setHidden:YES];
                //set the scale factors
                
                //ratioW=self.image.size.width/self.frameRect.size.width ;
                //ratioH=self.image.size.height/self.frameRect.size.height;
                
                ratioW=(self.image.size.width/self.frame.size.width)*(self.window.frame.size.width/self.frameRect.size.width);
                ratioH=(self.image.size.height/self.frame.size.height)*(self.window.frame.size.height/self.frameRect.size.height);
                
                //cv::Point p;
                p.x=self.currentLocation.x;
                p.y=self.currentLocation.y;
                //translate the point first to the frame rectangle
                pTemp.x=p.x;pTemp.y=p.y;
                pTemp=[self translatePoint:pTemp toOrigin:self.frameRect.origin fromOrigin:self.window.frame.origin];
                p.x=pTemp.x;
                p.y=pTemp.y;
                
                //map the touch point to image pixel
                //with floor
                p.x=floor(p.x * ratioW* rootSV.zoomScale);
                p.y=floor(p.y * ratioH* rootSV.zoomScale);
                
//                //without floor
//                p.x=p.x * ratioW* rootSV.zoomScale;
//                p.y=p.y * ratioH* rootSV.zoomScale;
                tmpContour.push_back(p);
                //frame point
                pf.x=self.currentLocation.x;//pTemp.x;//
                pf.y=self.currentLocation.y;//pTemp.y;//
                tmpContourFrame.push_back(pf);
                
                //debug area
                flag=self.image.size.width;
                
            }
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
     //UIScrollView *s=self.superview;
    UITouch *touch = [touches anyObject];
    self.currentLocation=[touch locationInView:self];
    CGPoint pTemp;
    rootSV=(UIScrollView *)self.superview;
    if (!rootSV.scrollEnabled && !self.draggable)
    {
        contoursTouchCounter++;
        //self.currentLocation=[touch locationInView:self];
        if (shapeType!=KRectShape) {
            self.location= [touch previousLocationInView:self];
            //cv::Point p;
            p.x=self.currentLocation.x;
            p.y=self.currentLocation.y;
            //translate the point first to the frame rectangle
            pTemp.x=p.x;pTemp.y=p.y;
            pTemp=[self translatePoint:pTemp toOrigin:self.frameRect.origin fromOrigin:self.window.frame.origin];
            p.x=pTemp.x;
            p.y=pTemp.y;
            //map the touch point to image pixel
            //with floor
            p.x=floor(p.x * ratioW* rootSV.zoomScale);
            p.y=floor(p.y * ratioH* rootSV.zoomScale);
           //without floor
           //p.x=p.x * ratioW* rootSV.zoomScale;
           //p.y=p.y * ratioH* rootSV.zoomScale;
            tmpContour.push_back(p);
            //frame point
            pf.x=self.currentLocation.x;//pTemp.x;//
            pf.y=self.currentLocation.y;//pTemp.y;//
            tmpContourFrame.push_back(pf);

        }
        [self setNeedsDisplay];
    }
    else if (self.draggable){
        CGPoint po=[touch previousLocationInView:self];
        //UIView *rootView=rootSV.superview;
        float deltax=(self.currentLocation.x-po.x)*rootSV.zoomScale;
        float deltay=(self.currentLocation.y-po.y)*rootSV.zoomScale;
        CGAffineTransform currentTransform = rootSV.transform;
        CGAffineTransform newTransform = CGAffineTransformTranslate(currentTransform, deltax, deltay);
        [rootSV setTransform:newTransform];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event // (2)
{
    @try {
        //NSLog(@"%d", contoursTouchCounter);
        UITouch *touch = [touches anyObject];
        self.currentLocation = [touch locationInView:self];
        UIScrollView *s=(UIScrollView *)self.superview;
        //UIScrollView *motherSV=(UIScrollView *)rootSV.superview;
        //get parent view controller
        ViewController *pc = (ViewController *)[self firstAvailableUIViewController];
        CGPoint pTemp;
        CGRect rTemp;
        if(!s.scrollEnabled && !self.draggable)
        {
            if (shapeType==KCurveShape) {
                //set the scale factors
                ratioW=(self.image.size.width/self.frame.size.width)*(self.window.frame.size.width/self.frameRect.size.width);
                ratioH=(self.image.size.height/self.frame.size.height)*(self.window.frame.size.height/self.frameRect.size.height);
                
                //cv::Point p;
                p.x=self.currentLocation.x;
                p.y=self.currentLocation.y;
                //translate the point first to the frame rectangle
                pTemp.x=p.x;pTemp.y=p.y;
                pTemp=[self translatePoint:pTemp toOrigin:self.frameRect.origin fromOrigin:self.window.frame.origin];
                p.x=pTemp.x;
                p.y=pTemp.y;
                
                //map the touch point to image pixel
                //with floor
                p.x=floor(p.x * ratioW* s.zoomScale);
                p.y=floor(p.y * ratioH* s.zoomScale);
                //without floor
                //p.x=p.x * ratioW* s.zoomScale;
                //p.y=p.y * ratioH* s.zoomScale;
                tmpContour.push_back(p);
                //frame point
                pf.x=self.currentLocation.x;//pTemp.x;//
                pf.y=self.currentLocation.y;//pTemp.y;//
                tmpContourFrame.push_back(pf);
                
                contoursTouchDraw.push_back(tmpContour);
                contoursTouchDrawFrame.push_back(tmpContourFrame);
                tmpContour.clear();
                tmpContourFrame.clear();
                //increment the contour count here after first contour only, other increments are in touches began
                if (contoursTouchCounter == 0) {
                    contoursTouchCounter++;
                }
                
                [path removeAllPoints]; //(4)
                [self processDrawingSelection];
                [self addViewController:KCurveShape];
                
            }
            else if(shapeType==KRectShape){
                
                self.currentRect = CGRectMake(
                                              (self.location.x > self.currentLocation.x)?self.currentLocation.x : self.location.x,
                                              (self.location.y > self.currentLocation.y)?self.currentLocation.y : self.location.y,
                                              abs(self.location.x - self.currentLocation.x),
                                              abs(self.location.y - self.currentLocation.y));
                
                
                //self.frameRect=self.currentRect;
                
                UIImage *croppedImg = nil;
                
                CGPoint currentPoint = [touch locationInView:self];
                
                ratioW=(self.image.size.width/self.frame.size.width)*(self.window.frame.size.width/self.frameRect.size.width);
                rTemp=self.frame;
                
                ratioH=(self.image.size.height/self.frame.size.height)*(self.window.frame.size.height/self.frameRect.size.height);
                
                //translate the rect first
                self.currentRect=[self translateRect:self.currentRect toOrigin:self.frameRect.origin fromOrigin:self.window.frame.origin];
                
                //set the current point to top left corner of selection canvas rectangle
                currentPoint.x=self.currentRect.origin.x;//self.myView.currentRect.size.width/2;
                currentPoint.y=self.currentRect.origin.y;//self.myView.currentRect.size.height/2;
                
                //with floor
                
                currentPoint.x=floor(currentPoint.x * ratioW * s.zoomScale);
                currentPoint.y=floor(currentPoint.y * ratioH * s.zoomScale);
                
                //set the crop rectangle
                CGRect cropRect=CGRectMake(0, 0, 0, 0);
                if (self.image.imageOrientation == UIImageOrientationUp) {
                    //NSLog(@"portrait");
                    //with floor
                    cropRect= CGRectMake(currentPoint.x, currentPoint.y, floor(self.currentRect.size.width* ratioW* s.zoomScale), floor(self.currentRect.size.height* ratioH* s.zoomScale));
                    //without floor
                    //cropRect= CGRectMake(currentPoint.x, currentPoint.y, self.currentRect.size.width* ratioW* s.zoomScale, self.currentRect.size.height* ratioH* s.zoomScale);
                } else if (self.image.imageOrientation == UIImageOrientationLeft || self.image.imageOrientation == UIImageOrientationRight) {
                    //NSLog(@"landscape");
                    //conserve the aspect ratio
                    cropRect = CGRectMake(currentPoint.x, currentPoint.y, floor((self.currentRect.size.width/self.frame.size.width * self.frame.size.height)* ratioW* s.zoomScale), floor((self.currentRect.size.height/self.frame.size.height*self.frame.size.width)* ratioW* s.zoomScale));
                }
                
                //draw the rectangle in blank image to add with contours image
                //self.myView.image = [self selectObjectsFromImageByRect:res Rect:self.myView.currentRect];
                
                //self.currentRect=cropRect;//-------->added now
                
                //double circleSizeW = 30 * ratioW;
                //double circleSizeH = 30 * ratioH;
                
                //CGRect testRect1=[self croppedRect:image scaledToSize:CGSizeMake(300, 300)];//---added now1
                //croppedImg = [self croppIngimageByImageName:image toRect:testRect1];
                //croppedImg=[self squareImageWithImage:image scaledToSize:CGSizeMake(300, 300)];//---added now1
                //NSLog(@"uIimage scale=%f,uIimage width=%f,uIimage height=%f after test",croppedImg.scale,croppedImg.size.width,croppedImg.size.height);
                croppedImg = [self croppIngimageByImageName:image toRect:cropRect];
                [self setNeedsDisplay];//------->removed now
                
                //self.image = [self addImageToImage:self.image withImage2:croppedImg andRect:cropRect];
                self.croppedImage=croppedImg;
                //            self.image=nil;
                //            [self setNeedsDisplay];
                //            self.image=croppedImg;
                [self addViewController:KRectShape];
                
                currentLocation=location;
            }
            else if(shapeType==KImageShape){
                
            }
            s.scrollEnabled=YES;
        }
        else if (self.draggable){
            UIScrollView *motherSV=(UIScrollView *)rootSV.superview;
            motherSV.scrollEnabled=YES;
        }
        [pc.myToolbar setHidden:NO];
    }
    @catch (NSException *exception) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"exception"
                                                        message:@"Selection not completed succesfully"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        alert=nil;
        
    }
    @finally {
       
    }
}


- (UIImage *)normalizedImage {
    if (self.image.imageOrientation == UIImageOrientationUp) return self.image;
    
    //UIGraphicsBeginImageContextWithOptions(self.image.size, NO, self.image.scale);
    UIGraphicsBeginImageContextWithOptions(self.image.size, NO, 0.0);
    [self.image drawInRect:(CGRect){0, 0, self.image.size}];
    UIImage *normalizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return normalizedImage;
}


- (UIImage *)squareImageFromImage:(UIImage *)imagge scaledToSize:(CGFloat)newSize {
    CGAffineTransform scaleTransform;
    CGPoint origin;
    
    if (imagge.size.width > imagge.size.height) {
        CGFloat scaleRatio = newSize / imagge.size.height;
        scaleTransform = CGAffineTransformMakeScale(scaleRatio, scaleRatio);
        
        origin = CGPointMake(-(imagge.size.width - imagge.size.height) / 2.0f, 0);
    } else {
        CGFloat scaleRatio = newSize / imagge.size.width;
        scaleTransform = CGAffineTransformMakeScale(scaleRatio, scaleRatio);
        
        origin = CGPointMake(0, -(imagge.size.height - imagge.size.width) / 2.0f);
    }
    
    CGSize size = CGSizeMake(newSize, newSize);
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        UIGraphicsBeginImageContextWithOptions(size, YES, 0.0);
    } else {
        UIGraphicsBeginImageContext(size);
    }
    
    CGContextRef context1 = UIGraphicsGetCurrentContext();
    CGContextConcatCTM(context1, scaleTransform);
    
    [imagge drawAtPoint:origin];
    
    imagge = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return imagge;
}

void MyCGPathApplierFunc (void *info, const CGPathElement *element) {
    NSMutableArray *bezierPoints = (__bridge NSMutableArray *)info;
    
    CGPoint *points = element->points;
    CGPathElementType type = element->type;
    
    switch(type) {
        case kCGPathElementMoveToPoint: // contains 1 point
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[0]]];
            break;
            
        case kCGPathElementAddLineToPoint: // contains 1 point
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[0]]];
            break;
            
        case kCGPathElementAddQuadCurveToPoint: // contains 2 points
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[0]]];
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[1]]];
            break;
            
        case kCGPathElementAddCurveToPoint: // contains 3 points
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[0]]];
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[1]]];
            [bezierPoints addObject:[NSValue valueWithCGPoint:points[2]]];
            break;
            
        case kCGPathElementCloseSubpath: // contains no point
            break;
    }
}


- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}


- (void)processDrawingSelection
{
    //get the enclosing rectangles for the drawn contours
    SPolygon sp,spf;
    contoursTouchRect=[self calculateBoundingRectForContours:(contoursTouchDraw) approxPoly:sp];
    contoursTouchRectFrame=[self calculateBoundingRectForContours:(contoursTouchDrawFrame) approxPoly:spf];
    
    UIImage *croppedImg = nil;
    CGRect r,rf;
    
    for(int j=0;j<contoursTouchRect.size();j++){
        //make a CGRect from the cv::rect !!
        r=CGRectMake(contoursTouchRect[j].tl().x, contoursTouchRect[j].tl().y, contoursTouchRect[j].size().width, contoursTouchRect[j].size().height);
        rf=CGRectMake(contoursTouchRectFrame[j].tl().x, contoursTouchRectFrame[j].tl().y, contoursTouchRectFrame[j].size().width, contoursTouchRectFrame[j].size().height);
        self.currentRect=rf;
        croppedImg = [self croppIngimageByImageName2:self.image toPoly:sp inRect:r];
        self.croppedImage=croppedImg;
        //self.image = [self addImageToImage:self.image withImage2:croppedImg andRect:r];
    }
    contoursTouchRect.clear();
    contoursTouchDraw.clear();
    contoursTouchRectFrame.clear();
    contoursTouchDrawFrame.clear();
    [self setNeedsDisplay];
    currentLocation=location;
}

-(vector<cv::Rect>) calculateBoundingRectForContours:(TContours)contoursArr approxPoly:(SPolygon&)poly{
    
    @try {
        /// Approximate contours to polygons + get bounding rects
        vector<vector<cv::Point>> contours_poly(contoursArr.size());
        vector<cv::Rect> rectArr(contoursArr.size());
        for( int i = 0; i < contoursArr.size(); i++ )
        {
            //cv::approxPolyDP(<#InputArray curve#>, <#OutputArray approxCurve#>, <#double epsilon#>, <#bool closed#>)
            cv::approxPolyDP(contoursArr[i], contours_poly[i], 3, true );
            rectArr[i] = cv::boundingRect((cv::Mat)(contours_poly[i]));
        }
        poly=(SPolygon)contours_poly;
        return rectArr;
    }
    @catch (NSException *exception) {
    }
    @finally {
    }
}

- (void)drawBitmap // (3)
{
    //try this
    //UIGraphicsBeginImageContextWithOptions(self.bounds.size, YES, 0.0);
    //[self drawViewHierarchyInRect:self.bounds afterScreenUpdates:NO];
    
    //CGSize size = CGSizeMake(self.image.size.width, self.image.size.height);
    //UIGraphicsBeginImageContext(self.bounds.size);
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, NO, 0.0f);
    //UIGraphicsBeginImageContext(size);
    [[UIColor blackColor] setStroke];
    if (!image) // first draw; paint background white by ...
    {
        //UIBezierPath *rectpath = [UIBezierPath bezierPathWithRect:self.bounds]; // enclosing bitmap by a rectangle defined by another UIBezierPath object
        //[[UIColor whiteColor] setFill];
        //[rectpath fill]; // filling it with white
        //incrementalImage=[UIImage imageNamed:@"im2.png"];
    }
//    [image drawAtPoint:CGPointZero];
    //[self.image drawInRect:CGRectMake(0, 0, self.image.size.width, self.image.size.height)];
    [self.image drawInRect:self.bounds];
    [path stroke];
    self.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}



- (CGRect)drawText:(CGFloat)xPosition yPosition:(CGFloat)yPosition canvasWidth:(CGFloat)canvasWidth canvasHeight:(CGFloat)canvasHeight text:(NSString*)txt
{
    @try {
        //Draw Text
        CGRect textRect = CGRectMake(xPosition, yPosition, canvasWidth, canvasHeight);
        NSMutableParagraphStyle* textStyle = NSMutableParagraphStyle.defaultParagraphStyle.mutableCopy;
        textStyle.alignment = NSTextAlignmentCenter;
        NSDictionary* textFontAttributes = @{NSFontAttributeName: [UIFont fontWithName: @"Chalkduster" size: 20], NSForegroundColorAttributeName: UIColor.redColor, NSParagraphStyleAttributeName: textStyle};
        
        [txt drawInRect: textRect withAttributes: textFontAttributes];
        return textRect;
    }
    @catch (NSException *exception) {
    }
    @finally {
    }
   
}

- (void) MyDrawTransparencyLayer:(CGContextRef)myContext width:(CGFloat)wd height:(CGFloat)ht
{
    @try {
        //draw background gradient color
        UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
        CGRect area=CGRectMake(0, 0, window.bounds.size.width , window.bounds.size.height);
        //UIGraphicsBeginImageContext(area.size);
        UIGraphicsBeginImageContextWithOptions(area.size, NO, 0.0f);
        // 1
        CGContextRef contextt = myContext;
        //UIGraphicsPushContext(contextt);
        CGGradientRef gradient = [self CreateGradient:[UIColor magentaColor] endColor:[UIColor redColor]];
        
        CGPoint startPoint, endPoint;
        BOOL isVertical=NO;
        if (isVertical) {
            startPoint = CGPointMake(CGRectGetMinX(area), area.origin.y);
            endPoint = CGPointMake(startPoint.x, area.origin.y + area.size.height);
        }else{
            startPoint = CGPointMake(0, area.size.height / 2.0f);
            endPoint = CGPointMake(area.size.width, startPoint.y);
        }
        
        CGContextDrawLinearGradient(contextt, gradient, startPoint, endPoint, 0);
        //UIImage *i=UIGraphicsGetImageFromCurrentImageContext();
        
        CGGradientRelease(gradient);
        
        
        //NSString *txt=@"";//@"Choose a photo please";
        //CGRect rect;
        UIBezierPath* textPath;
        textPath=[self setupTextLayer];
        CGSize myShadowOffset = CGSizeMake (10, -20);// 2
        
        
        
        CGContextSetShadow (myContext, myShadowOffset, 10);   // 3
        CGContextBeginTransparencyLayer (myContext, NULL);// 4
        // Your drawing code here// 5
        CGContextSetRGBFillColor (myContext, drand48(), drand48(), drand48(), drand48());
        CGContextFillRect (myContext, CGRectMake (wd/3+ 50,ht/2 ,wd/4,ht/4));
        CGContextSetRGBFillColor (myContext, 0, 0, 1, 1);
        CGContextFillRect (myContext, CGRectMake (wd/3-50,ht/2-100,wd/4,ht/4));
        CGContextSetRGBFillColor (myContext, 1, 0, 0, 1);
        CGContextFillRect (myContext, CGRectMake (wd/3,ht/2-50,wd/4,ht/4));
        CGContextAddPath(myContext, textPath.CGPath);
        CGContextClosePath(myContext);
        CGContextSaveGState(myContext);
        CGContextClip(myContext);
        
        
        CGPoint point;
        //CGPoint pointCir;
        for(int i=0;i<100;i++)
        {
            //rect=[self drawText:0 yPosition:self.bounds.size.height/2 canvasWidth:self.bounds.size.width canvasHeight:self.bounds.size.height text:txt];
            //CGContextAddPath(myContext,rect);
            //CGContextClip(myContext);
            
            CGContextSetRGBFillColor(myContext, drand48(), drand48(), drand48(), drand48());
            CGContextSetLineWidth(myContext, arc4random_uniform(20)); // set the line width
            //CGContextAddArc(myContext,arc4random_uniform(self.bounds.size.width), arc4random_uniform(self.bounds.size.height/2), arc4random_uniform(self.bounds.size.width), arc4random_uniform(360), arc4random_uniform(360), arc4random_uniform(1));
            
            //draw circles at the equator
            point.x = arc4random_uniform(self.bounds.size.width);
            point.y = floor(self.bounds.size.height/2.4);
            //pointCir= CGPointMake(point.x/2 + radius * cos(cita) , (point.y-point.x/2) + radius * sin(cita) );
            CGRect circleMini = CGRectMake(point.x,point.y,arc4random_uniform(150),arc4random_uniform(150));
            
            CGContextFillEllipseInRect(myContext, circleMini);
            CGContextStrokePath(myContext);
        }
        CGContextRestoreGState(myContext);
        
        //Draw some arcs
        for(int i=0;i<arc4random_uniform(100);i++)
        {
            //rect=[self drawText:0 yPosition:self.bounds.size.height/2 canvasWidth:self.bounds.size.width canvasHeight:self.bounds.size.height text:txt];
            //CGContextAddPath(myContext,rect);
            //CGContextClip(myContext);
            
            CGContextSetRGBStrokeColor(myContext, drand48(), drand48(), drand48(), drand48());
            CGContextSetLineWidth(myContext, arc4random_uniform(20)); // set the line width
            CGContextAddArc(myContext,arc4random_uniform(self.bounds.size.width), arc4random_uniform(self.bounds.size.height/2), arc4random_uniform(self.bounds.size.width), arc4random_uniform(360), arc4random_uniform(360), arc4random_uniform(1));
            CGContextStrokePath(myContext);
        }
        
        //CGContextClosePath(myContext);
        
        //CGContextClearRect(myContext,CGRectMake(0,0,self.bounds.size.width,self.bounds.size.height));
        //CGContextStrokePath(myContext);
        
        
        CGContextEndTransparencyLayer (myContext);// 6
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}

- (UIImage*) MyDrawTransparencyLayer2:(CGContextRef)myContext width:(CGFloat)wd height:(CGFloat)ht
{
    @try {
        //draw background gradient color
        float width=621;
        float height=1104;
        //UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
        CGRect area=CGRectMake(0, 0, width, height);
        //UIGraphicsBeginImageContext(area.size);
        UIGraphicsBeginImageContextWithOptions(area.size, NO, 0.0f);
        // 1
        myContext = UIGraphicsGetCurrentContext();//myContext;
        //UIGraphicsPushContext(contextt);
        CGGradientRef gradient = [self CreateGradient:[UIColor magentaColor] endColor:[UIColor redColor]];
        
        CGPoint startPoint, endPoint;
        BOOL isVertical=NO;
        if (isVertical) {
            startPoint = CGPointMake(CGRectGetMinX(area), area.origin.y);
            endPoint = CGPointMake(startPoint.x, area.origin.y + area.size.height);
        }else{
            startPoint = CGPointMake(0, area.size.height / 2.0f);
            endPoint = CGPointMake(area.size.width, startPoint.y);
        }
        
        CGContextDrawLinearGradient(myContext, gradient, startPoint, endPoint, 0);
        UIImage *i=UIGraphicsGetImageFromCurrentImageContext();
        
        CGGradientRelease(gradient);
        
        
        //NSString *txt=@"";//@"Choose a photo please";
        //CGRect rect;
        UIBezierPath* textPath;
        textPath=[self setupTextLayer2];
        CGSize myShadowOffset = CGSizeMake (10, -20);// 2
        
        
        
        CGContextSetShadow (myContext, myShadowOffset, 10);   // 3
        CGContextBeginTransparencyLayer (myContext, NULL);// 4
        // Your drawing code here// 5
        CGContextSetRGBFillColor (myContext, drand48(), drand48(), drand48(), drand48());
        CGContextFillRect (myContext, CGRectMake (wd/3+ 50,ht/2 ,wd/4,ht/4));
        CGContextSetRGBFillColor (myContext, 0, 0, 1, 1);
        CGContextFillRect (myContext, CGRectMake (wd/3-50,ht/2-100,wd/4,ht/4));
        CGContextSetRGBFillColor (myContext, 1, 0, 0, 1);
        CGContextFillRect (myContext, CGRectMake (wd/3,ht/2-50,wd/4,ht/4));
        CGContextAddPath(myContext, textPath.CGPath);
        CGContextClosePath(myContext);
        CGContextSaveGState(myContext);
        CGContextClip(myContext);
        
        width=621;
        height=1104;
        CGPoint point;
        //CGPoint pointCir;
        for(int i=0;i<100;i++)
        {
            //rect=[self drawText:0 yPosition:self.bounds.size.height/2 canvasWidth:self.bounds.size.width canvasHeight:self.bounds.size.height text:txt];
            //CGContextAddPath(myContext,rect);
            //CGContextClip(myContext);
            
            CGContextSetRGBFillColor(myContext, drand48(), drand48(), drand48(), drand48());
            CGContextSetLineWidth(myContext, arc4random_uniform(20)); // set the line width
            //CGContextAddArc(myContext,arc4random_uniform(self.bounds.size.width), arc4random_uniform(self.bounds.size.height/2), arc4random_uniform(self.bounds.size.width), arc4random_uniform(360), arc4random_uniform(360), arc4random_uniform(1));
            
            //draw circles at the equator
            point.x = arc4random_uniform(width);
            point.y = floor(height/2.4);
            //pointCir= CGPointMake(point.x/2 + radius * cos(cita) , (point.y-point.x/2) + radius * sin(cita) );
            CGRect circleMini = CGRectMake(point.x,point.y,arc4random_uniform(150),arc4random_uniform(150));
            
            CGContextFillEllipseInRect(myContext, circleMini);
            CGContextStrokePath(myContext);
        }
        CGContextRestoreGState(myContext);
        
        //Draw some arcs
        for(int i=0;i<arc4random_uniform(100);i++)
        {
            //rect=[self drawText:0 yPosition:self.bounds.size.height/2 canvasWidth:self.bounds.size.width canvasHeight:self.bounds.size.height text:txt];
            //CGContextAddPath(myContext,rect);
            //CGContextClip(myContext);
            
            CGContextSetRGBStrokeColor(myContext, drand48(), drand48(), drand48(), drand48());
            CGContextSetLineWidth(myContext, arc4random_uniform(20)); // set the line width
            CGContextAddArc(myContext,arc4random_uniform(width), arc4random_uniform(height/2), arc4random_uniform(width), arc4random_uniform(360), arc4random_uniform(360), arc4random_uniform(1));
            CGContextStrokePath(myContext);
        }
        
        //CGContextClosePath(myContext);
        
        //CGContextClearRect(myContext,CGRectMake(0,0,self.bounds.size.width,self.bounds.size.height));
        //CGContextStrokePath(myContext);
        
        
        CGContextEndTransparencyLayer (myContext);// 6
        i=UIGraphicsGetImageFromCurrentImageContext();
        //UIGraphicsEndImageContext();
        return(i);
        
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}


- (UIBezierPath *)setupTextLayer
{
    @try {
        CGMutablePathRef letters = CGPathCreateMutable();
        
        CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica-Bold"), 23, NULL);
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                               (__bridge id)font, kCTFontAttributeName,
                               nil];
        NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:@"Choose a photo please"
                                                                         attributes:attrs];
        //    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:@""
        //                                                                     attributes:attrs];
        CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)attrString);
        CFArrayRef runArray = CTLineGetGlyphRuns(line);
        
        // for each RUN
        for (CFIndex runIndex = 0; runIndex < CFArrayGetCount(runArray); runIndex++)
        {
            // Get FONT for this run
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runArray, runIndex);
            //CTFontRef runFont = CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName);
            
            // for each GLYPH in run
            for (CFIndex runGlyphIndex = 0; runGlyphIndex < CTRunGetGlyphCount(run); runGlyphIndex++)
            {
                // get Glyph & Glyph-data
                CFRange thisGlyphRange = CFRangeMake(runGlyphIndex, 1);
                CGGlyph glyph;
                CGPoint position;
                CTRunGetGlyphs(run, thisGlyphRange, &glyph);
                CTRunGetPositions(run, thisGlyphRange, &position);
                
                // Get PATH of outline
                {
                    CGPathRef letter = CTFontCreatePathForGlyph(font, glyph, NULL);
                    // CGAffineTransform t = CGAffineTransformMakeTranslation(position.x,position.y);
                    CGAffineTransform xform = CGAffineTransformMake(1.0f,  0.0f,
                                                                    0.0f, -1.0f,
                                                                    position.x+20,  position.y+self.bounds.size.height/2);
                    CGPathAddPath(letters, &xform, letter);
                    CGPathRelease(letter);
                }
            }
        }
        CFRelease(line);
        
        UIBezierPath *pth = [UIBezierPath bezierPath];
        [pth moveToPoint:CGPointZero];
        [pth appendPath:[UIBezierPath bezierPathWithCGPath:letters]];
        
        
        CGPathRelease(letters);
        CFRelease(font);
        return pth;

    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
    
}

- (UIBezierPath *)setupTextLayer2
{
    @try {
        //float width=320;
        float height=1104;
        CGMutablePathRef letters = CGPathCreateMutable();
        
        CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica-Bold"), 23, NULL);
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                               (__bridge id)font, kCTFontAttributeName,
                               nil];
        NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:@"Choose a photo please"
                                                                         attributes:attrs];
        //    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:@""
        //                                                                     attributes:attrs];
        CTLineRef line = CTLineCreateWithAttributedString((CFAttributedStringRef)attrString);
        CFArrayRef runArray = CTLineGetGlyphRuns(line);
        
        // for each RUN
        for (CFIndex runIndex = 0; runIndex < CFArrayGetCount(runArray); runIndex++)
        {
            // Get FONT for this run
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runArray, runIndex);
            //CTFontRef runFont = CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName);
            
            // for each GLYPH in run
            for (CFIndex runGlyphIndex = 0; runGlyphIndex < CTRunGetGlyphCount(run); runGlyphIndex++)
            {
                // get Glyph & Glyph-data
                CFRange thisGlyphRange = CFRangeMake(runGlyphIndex, 1);
                CGGlyph glyph;
                CGPoint position;
                CTRunGetGlyphs(run, thisGlyphRange, &glyph);
                CTRunGetPositions(run, thisGlyphRange, &position);
                
                // Get PATH of outline
                {
                    CGPathRef letter = CTFontCreatePathForGlyph(font, glyph, NULL);
                    // CGAffineTransform t = CGAffineTransformMakeTranslation(position.x,position.y);
                    CGAffineTransform xform = CGAffineTransformMake(1.0f,  0.0f,
                                                                    0.0f, -1.0f,
                                                                    position.x+160,  position.y+height/2);
                    CGPathAddPath(letters, &xform, letter);
                    CGPathRelease(letter);
                }
            }
        }
        CFRelease(line);
        
        UIBezierPath *pth = [UIBezierPath bezierPath];
        [pth moveToPoint:CGPointZero];
        [pth appendPath:[UIBezierPath bezierPathWithCGPath:letters]];
        
        
        CGPathRelease(letters);
        CFRelease(font);
        return pth;
        
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
    
}



- (void)drawRect:(CGRect)rect {
    // Drawing code.
    
    @try {
        //NSString *txt=@"Choose a photo please";
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGRect r,x;
        CGPoint originFrame,originWindow;
        float tx,ty,originFrameNewx,originFrameNewy;
        switch (shapeType) {
            case KLineShape:
                [self MyDrawTransparencyLayer:ctx width:arc4random_uniform(300) height:arc4random_uniform(300)];
                break;
            case KCurveShape:
                [path moveToPoint:location];
                [path addLineToPoint:currentLocation];
                
                //translate the frameRect to the center before drawing
                originFrame=self.frameRect.origin;
                originWindow=self.bounds.origin;
                //get the center of frame rect
                originFrame.x=originFrame.x+self.frameRect.size.width/2;
                originFrame.y=originFrame.y+self.frameRect.size.height/2;
                //get the center of view
                originWindow.x=originWindow.x+self.bounds.size.width/2;
                originWindow.y=originWindow.y+self.bounds.size.height/2;
                
                //translation factors
                tx=originFrame.x-originWindow.x;
                ty=originFrame.y-originWindow.y;
                
                originFrameNewx=originFrame.x-tx;
                originFrameNewy=originFrame.y-ty;
                
                r=CGRectMake(originFrameNewx-self.frameRect.size.width/2, originFrameNewy-self.frameRect.size.height/2, self.frameRect.size.width, self.frameRect.size.height);
                self.frameRect=r;
                
                [self.image drawInRect:self.frameRect];
                [path stroke];
                
                
                break;
            case KRectShape:
                //translate the frameRect to the center before drawing
                originFrame=self.frameRect.origin;
                originWindow=self.bounds.origin;
                //get the center of frame rect
                originFrame.x=originFrame.x+self.frameRect.size.width/2;
                originFrame.y=originFrame.y+self.frameRect.size.height/2;
                //get the center of view
                originWindow.x=originWindow.x+self.bounds.size.width/2;
                originWindow.y=originWindow.y+self.bounds.size.height/2;
                
                //translation factors
                tx=originFrame.x-originWindow.x;
                ty=originFrame.y-originWindow.y;
                
                originFrameNewx=originFrame.x-tx;
                originFrameNewy=originFrame.y-ty;
                
                r=CGRectMake(originFrameNewx-self.frameRect.size.width/2, originFrameNewy-self.frameRect.size.height/2, self.frameRect.size.width, self.frameRect.size.height);
                self.frameRect=r;
                x=self.bounds;
                
                [self.image drawInRect:self.frameRect];
                self.context = UIGraphicsGetCurrentContext();
                self.currentRect = CGRectMake(
                                              (location.x > currentLocation.x)?currentLocation.x : location.x,
                                              (location.y > currentLocation.y)?currentLocation.y : location.y,
                                              fabsf((float)(location.x - currentLocation.x)),
                                              fabsf((float)(location.y - currentLocation.y)));
                CGContextAddRect(self.context, self.currentRect);
                CGContextStrokeRect(self.context, self.currentRect);
                
                break;
            case KImageShape:
                //translate the frameRect to the center before drawing
                originFrame=self.frameRect.origin;
                originWindow=self.bounds.origin;
                //get the center of frame rect
                originFrame.x=originFrame.x+self.frameRect.size.width/2;
                originFrame.y=originFrame.y+self.frameRect.size.height/2;
                //get the center of view
                originWindow.x=originWindow.x+self.bounds.size.width/2;
                originWindow.y=originWindow.y+self.bounds.size.height/2;
                
                //translation factors
                tx=originFrame.x-originWindow.x;
                ty=originFrame.y-originWindow.y;
                
                originFrameNewx=originFrame.x-tx;
                originFrameNewy=originFrame.y-ty;
                
                r=CGRectMake(originFrameNewx-self.frameRect.size.width/2, originFrameNewy-self.frameRect.size.height/2, self.frameRect.size.width, self.frameRect.size.height);
                self.frameRect=r;
                 x.size=self.image.size;
                [self.image drawInRect:self.frameRect];
                break;
            default:
                break;
        }

    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
    
    
}

//-(void)saveImg{
//    [UIImagePNGRepresentation(image) writeToFile:self.dpath atomically:YES];
//    NSLog(@"i am in");
//}


-(UIImage*)FillGradientRect:(CGRect)area startColor:(UIColor*)startColor endColor:(UIColor *)endColor isVertical:(BOOL)isVertical
{
    //UIGraphicsBeginImageContext(area.size);
    UIGraphicsBeginImageContextWithOptions(area.size, NO, 0.0f);
    // 1
    CGContextRef contextt = UIGraphicsGetCurrentContext();
    //UIGraphicsPushContext(contextt);
    CGGradientRef gradient = [self CreateGradient:startColor endColor:endColor];
    
    CGPoint startPoint, endPoint;
    if (isVertical) {
        startPoint = CGPointMake(CGRectGetMinX(area), area.origin.y);
        endPoint = CGPointMake(startPoint.x, area.origin.y + area.size.height);
    }else{
        startPoint = CGPointMake(0, area.size.height / 2.0f);
        endPoint = CGPointMake(area.size.width, startPoint.y);
    }
    
    CGContextDrawLinearGradient(contextt, gradient, startPoint, endPoint, 0);
    UIImage *i=UIGraphicsGetImageFromCurrentImageContext();
    
    
    gradient=nil;
    CGGradientRelease(gradient);
    //UIGraphicsPopContext();
    return i;
}

-(UIImage*)FillGradientRect2:(CGRect)area startColor:(UIColor*)startColor endColor:(UIColor *)endColor isVertical:(BOOL)isVertical
{
    //UIGraphicsBeginImageContext(area.size);
    UIGraphicsBeginImageContextWithOptions(area.size, NO, 0.0f);
    // 1
    CGContextRef contextt = UIGraphicsGetCurrentContext();
    //UIGraphicsPushContext(contextt);
    CGGradientRef gradient = [self CreateGradient:startColor endColor:endColor];
    
    CGPoint startPoint, endPoint;
    if (isVertical) {
        startPoint = CGPointMake(CGRectGetMinX(area), area.origin.y);
        endPoint = CGPointMake(startPoint.x, area.origin.y + area.size.height);
    }else{
        startPoint = CGPointMake(0, area.size.height / 2.0f);
        endPoint = CGPointMake(area.size.width, startPoint.y);
    }
    
    CGContextDrawLinearGradient(contextt, gradient, startPoint, endPoint, 0);
    UIImage *i=UIGraphicsGetImageFromCurrentImageContext();
    
    
    gradient=nil;
    CGGradientRelease(gradient);
    //UIGraphicsPopContext();
    return i;
}


-(CGGradientRef)CreateGradient:(UIColor*)startColor endColor:(UIColor*)endColor
{
    @try {
        CGGradientRef result;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGFloat locations[2] = {0.0f, 1.0f};
        CGFloat startRed, startGreen, startBlue, startAlpha;
        CGFloat endRed, endGreen, endBlue, endAlpha;
        
        [endColor getRed:&endRed green:&endGreen blue:&endBlue alpha:&endAlpha];
        [startColor getRed:&startRed green:&startGreen blue:&startBlue alpha:&startAlpha];
        
        CGFloat componnents[8] = {
            startRed, startGreen, startBlue, startAlpha,
            endRed, endGreen, endBlue, endAlpha
        };
        result = CGGradientCreateWithColorComponents(colorSpace, componnents, locations, 2);
        CGColorSpaceRelease(colorSpace);
        return result;
    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
    
}

-(void)addViewController :(ShapeType)sType{
    
    @try {
        //get the parent view controller and add a modal view controller
        ViewController *vc = (ViewController *)[self firstAvailableUIViewController];
        
        //update the current image of view controller
        vc.image=self.image;
        //re-enable scrolling and zooming
        vc.myScrollView.scrollEnabled=YES;
        vc.myScrollView.minimumZoomScale=vc.minimumZoomScale;
        vc.myScrollView.maximumZoomScale=vc.maximumZoomScale;
        
        UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone" bundle: nil];
        ViewController *croppedVC =(ViewController *)[mainStoryboard instantiateViewControllerWithIdentifier: @"ViewController"];
        //myScrollView.delegate = [croppedVC class];
        
        //test pasting cropped part to original image
        
        croppedVC.image=self.croppedImage;//-------->removed now
        self.croppedImage=nil;
        
//            //for generating some icon images
//            CGRect r=CGRectMake(self.currentRect.origin.x,self.currentRect.origin.y,621, 1104);
//            CGContextRef ctx = UIGraphicsGetCurrentContext();
//            croppedVC.image=[self MyDrawTransparencyLayer2:ctx width:arc4random_uniform(300) height:arc4random_uniform(300)];
//        //croppedVC.image=[self FillGradientRect:r startColor:[UIColor magentaColor] endColor:[UIColor redColor] isVertical:NO];
//        
//            croppedVC.imageRect=r;
        
        croppedVC.imageRect=self.currentRect;
        
        croppedVC.rootFlag=-1;
        [croppedVC setShapeType:sType];
        
        [vc presentViewController:croppedVC animated:YES completion:nil];

    }
    @catch (NSException *exception) {
        
    }
    @finally {
        
    }
}

@end
