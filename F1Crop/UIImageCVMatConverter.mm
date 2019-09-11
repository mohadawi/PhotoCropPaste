//
//  UIImageCVMatConverter.mm
//

#import "UIImageCVMatConverter.h"

@implementation UIImageCVMatConverter

+ (UIImage *)UIImageFromCVMat:(cv::Mat)cvMat withUIImage:(UIImage*)image;
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace( image.CGImage );
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    CGFloat widthStep = image.size.width;
    CGContextRef contextRef = CGBitmapContextCreate( NULL, cols, rows, 8, widthStep*4, colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault );
    CGContextDrawImage( contextRef, CGRectMake(0, 0, cols, rows), image.CGImage );
    CGContextSetRGBStrokeColor( contextRef, 1, 0, 0, 1 );
    CGImageRef cgImage = CGBitmapContextCreateImage( contextRef );
    UIImage* result = [UIImage imageWithCGImage:cgImage];
    CGImageRelease( cgImage );
    CGContextRelease( contextRef );
    //CGColorSpaceRelease( colorSpace );
    return result;
}


//added feb 27,2018
+(UIImage*) imageWithMat:(const cv::Mat&) image
{
    cv::Mat rgbaView;
    
    if (image.channels() == 3)
    {
        cv::cvtColor(image, rgbaView, cv::COLOR_BGR2RGBA);
    }
    else if (image.channels() == 4)
    {
        cv::cvtColor(image, rgbaView, cv::COLOR_BGRA2RGBA);
    }
    else if (image.channels() == 1)
    {
        cv::cvtColor(image, rgbaView, cv::COLOR_GRAY2RGBA);
    }
    
    NSData *data = [NSData dataWithBytes:rgbaView.data length:rgbaView.elemSize() * rgbaView.total()];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGBitmapInfo bmInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(rgbaView.cols,                              //width
                                        rgbaView.rows,                              //height
                                        8,                                          //bits per component
                                        8 * rgbaView.elemSize(),                    //bits per pixel
                                        rgbaView.step.p[0],                         //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        bmInfo,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

+(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    if ( cvMat.elemSize() == 1 ) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    }
    else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData( (__bridge CFDataRef)data );
    CGImageRef imageRef = CGImageCreate( cvMat.cols, cvMat.rows, 8, 8 * cvMat.elemSize(), cvMat.step[0], colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault );
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease( imageRef );
    CGDataProviderRelease( provider );
    CGColorSpaceRelease( colorSpace );
    return finalImage;
}


//added feb 27,2018
+(cv::Mat) toMat:(UIImage *)image
{
    CGImageRef imageRef = image.CGImage;
    
    const int srcWidth        = (int)CGImageGetWidth(imageRef);
    const int srcHeight       = (int)CGImageGetHeight(imageRef);
    //const int stride          = CGImageGetBytesPerRow(imageRef);
    //const int bitPerPixel     = CGImageGetBitsPerPixel(imageRef);
    //const int bitPerComponent = CGImageGetBitsPerComponent(imageRef);
    //const int numPixels       = bitPerPixel / bitPerComponent;
    
    CGDataProviderRef dataProvider = CGImageGetDataProvider(imageRef);
    CFDataRef rawData = CGDataProviderCopyData(dataProvider);
    
    //unsigned char * dataPtr = const_cast<unsigned char*>(CFDataGetBytePtr(rawData));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    cv::Mat rgbaContainer(srcHeight, srcWidth, CV_8UC4);
    CGContextRef context = CGBitmapContextCreate(rgbaContainer.data,
                                                 srcWidth,
                                                 srcHeight,
                                                 8,
                                                 4 * srcWidth,
                                                 colorSpace,
                                                 kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
    
    CGContextDrawImage(context, CGRectMake(0, 0, srcWidth, srcHeight), imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    CFRelease(rawData);
    
    cv::Mat t;
    cv::cvtColor(rgbaContainer, t, cv::COLOR_RGBA2BGRA);
    
    //cv::Vec4b a = rgbaContainer.at<cv::Vec4b>(0,0);
    //cv::Vec4b b = t.at<cv::Vec4b>(0,0);
    //std::cout << std::hex << (int)a[0] << " "<< (int)a[1] << " " << (int)a[2] << " "  << (int)a[3] << std::endl;
    //std::cout << std::hex << (int)b[0] << " "<< (int)b[1] << " " << (int)b[2] << " "  << (int)b[3] << std::endl;
    
    return t;
}



+ (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace( image.CGImage );
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    CGContextRef contextRef;
    cv::Mat cvMat;
    
    if (CGColorSpaceGetModel(CGImageGetColorSpace(image.CGImage)) == kCGColorSpaceModelMonochrome) {
        // Image is grayscale
        cvMat =  cv::Mat( rows, cols, CV_8UC1);
        if(cvMat.data != nil)
            contextRef = CGBitmapContextCreate( cvMat.data, cols, rows, 8, cvMat.step[0], colorSpace,kCGImageAlphaNone);
        else
            contextRef = CGBitmapContextCreate( NULL, cols, rows, 8, 0, colorSpace, kCGImageAlphaNone);
    } else {
        // Image allows color
        cvMat =  cv::Mat( rows, cols, CV_8UC4 );
        if(cvMat.data != nil)
            contextRef = CGBitmapContextCreate( cvMat.data, cols, rows, 8, cvMat.step[0], colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault );
        else
            contextRef = CGBitmapContextCreate( NULL, cols, rows, 8, 0, colorSpace, kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault );
    }
    
        CGContextDrawImage( contextRef, CGRectMake(0, 0, cols, rows), image.CGImage );
        CGContextRelease( contextRef );
        return cvMat;
    }


+ (cv::Mat)cvMatGrayFromUIImage:(UIImage *)image
{
    cv::Mat cvMat = [UIImageCVMatConverter cvMatFromUIImage:image];
    cv::Mat grayMat;
    if ( cvMat.channels() == 1 ) {
        grayMat = cvMat;
    }
    else {
        grayMat = cv :: Mat( cvMat.rows,cvMat.cols, CV_8UC1 );
        cv::cvtColor( cvMat, grayMat, CV_BGR2GRAY );
    }
    return grayMat;
}

+ (UIImage *)scaleAndRotateImageBackCamera:(UIImage *)image
{
    static int kMaxResolution = 640;
    CGImageRef imgRef = image.CGImage;
    CGFloat width = CGImageGetWidth( imgRef );
    CGFloat height = CGImageGetHeight( imgRef );
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGRect bounds = CGRectMake( 0, 0, width, height );
    if ( width > kMaxResolution || height > kMaxResolution ) {
        CGFloat ratio = width/height;
        if ( ratio > 1 ) {
            bounds.size.width = kMaxResolution;
            bounds.size.height = bounds.size.width / ratio;
        }
        else {
            bounds.size.height = kMaxResolution;
            bounds.size.width = bounds.size.height * ratio;
        }
    }
    CGFloat scaleRatio = bounds.size.width / width;
    CGSize imageSize = CGSizeMake( CGImageGetWidth(imgRef), CGImageGetHeight(imgRef) );
    CGFloat boundHeight;
    UIImageOrientation orient = image.imageOrientation;
    switch( orient ) {
        case UIImageOrientationUp:
            transform = CGAffineTransformIdentity;
            break;
        case UIImageOrientationUpMirrored:
            transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            break;
        case UIImageOrientationDown:
            transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
            transform = CGAffineTransformScale(transform, 1.0, -1.0);
            break;
        case UIImageOrientationLeftMirrored:
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
        case UIImageOrientationLeft:
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
        case UIImageOrientationRightMirrored:
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeScale(-1.0, 1.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
        case UIImageOrientationRight:
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, 0.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Invalid image orientation"];
    }
    UIGraphicsBeginImageContext( bounds.size );
    CGContextRef context = UIGraphicsGetCurrentContext();
    if ( orient == UIImageOrientationRight || orient == UIImageOrientationLeft ) {
        CGContextScaleCTM( context, -scaleRatio, scaleRatio );
        CGContextTranslateCTM( context, -height, 0 );
    }
    else {
        CGContextScaleCTM( context, scaleRatio, -scaleRatio );
        CGContextTranslateCTM( context, 0, -height );
    }
    CGContextConcatCTM( context, transform );
    CGContextDrawImage( UIGraphicsGetCurrentContext(), CGRectMake(0, 0, width, height), imgRef );
    UIImage *returnImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return returnImage;
}

+ (UIImage *)scaleAndRotateImageFrontCamera:(UIImage *)image
{
    static int kMaxResolution = 640;
    CGImageRef imgRef = image.CGImage;
    CGFloat width = CGImageGetWidth(imgRef);
    CGFloat height = CGImageGetHeight(imgRef);
    CGAffineTransform transform = CGAffineTransformIdentity;
    CGRect bounds = CGRectMake( 0, 0, width, height);
    if (width > kMaxResolution || height > kMaxResolution) {
        CGFloat ratio = width/height;
        if (ratio > 1) {
            bounds.size.width = kMaxResolution;
            bounds.size.height = bounds.size.width / ratio;
        } else {
            bounds.size.height = kMaxResolution;
            bounds.size.width = bounds.size.height * ratio;
        }
    }
    
    CGFloat scaleRatio = bounds.size.width / width;
    CGSize imageSize = CGSizeMake(CGImageGetWidth(imgRef), CGImageGetHeight(imgRef));
    CGFloat boundHeight;
    UIImageOrientation orient = image.imageOrientation;
    switch(orient) {
        case UIImageOrientationUp:
            transform = CGAffineTransformIdentity;
            break;
        case UIImageOrientationUpMirrored:
            transform = CGAffineTransformMakeTranslation(imageSize.width, 0.0);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            break;
        case UIImageOrientationDown:
            transform = CGAffineTransformMakeTranslation(imageSize.width, imageSize.height);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
        case UIImageOrientationDownMirrored:
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.height);
            transform = CGAffineTransformScale(transform, 1.0, -1.0);
            break;
        case UIImageOrientationLeftMirrored:
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(imageSize.height, imageSize.width);
            transform = CGAffineTransformScale(transform, -1.0, 1.0);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
        case UIImageOrientationLeft:
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeTranslation(0.0, imageSize.width);
            transform = CGAffineTransformRotate(transform, 3.0 * M_PI / 2.0);
            break;
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored:
            boundHeight = bounds.size.height;
            bounds.size.height = bounds.size.width;
            bounds.size.width = boundHeight;
            transform = CGAffineTransformMakeScale(-1.0, 1.0);
            transform = CGAffineTransformRotate(transform, M_PI / 2.0);
            break;
        default:
            [NSException raise:NSInternalInconsistencyException format:@"Invalid image orientation"];
    }
    UIGraphicsBeginImageContext( bounds.size );
    CGContextRef context = UIGraphicsGetCurrentContext();
    if ( orient == UIImageOrientationRight || orient == UIImageOrientationLeft ) {
        CGContextScaleCTM(context, -scaleRatio, scaleRatio);
        CGContextTranslateCTM(context, -height, 0);
    }
    else {
        CGContextScaleCTM(context, scaleRatio, -scaleRatio);
        CGContextTranslateCTM(context, 0, -height);
    }
    CGContextConcatCTM( context, transform );
    CGContextDrawImage( UIGraphicsGetCurrentContext(), CGRectMake(0, 0, width, height), imgRef );
    UIImage *returnImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return returnImage;
}

@end
