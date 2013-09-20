//
//  ViewController.m
//  CubeFaceGrabber
//
//  Created by Carl Brown on 8/15/13.
//  Copyright (c) 2013 PDAgent. All rights reserved.
//

#import "ViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <opencv2/opencv.hpp>
#import <math.h>

#define EPS 0.1

using namespace std;
using namespace cv;


@interface ViewController ()
@property (nonatomic) int testCase;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *resultLabel;
@property (weak, nonatomic) IBOutlet UIButton *letsSeeButton;
@property (weak, nonatomic) IBOutlet UIButton *nextTest;
@property (strong, nonatomic) UIImage *originalImage;
@property (strong, nonatomic) UIImage *perspectiveShiftedImage;
@property (strong, nonatomic) NSArray *cubeCorners;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.testCase = 1;
    self.letsSeeButton.hidden = NO;
    self.nextTest.hidden = YES;
}

-(void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.originalImage = self.imageView.image;

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(CGFloat)contentScaleFactor
{
    CGFloat widthScale = self.imageView.bounds.size.width / self.imageView.image.size.width;
    CGFloat heightScale = self.imageView.bounds.size.height / self.imageView.image.size.height;
    
    if (self.imageView.contentMode == UIViewContentModeScaleToFill) {
        return (widthScale==heightScale) ? widthScale : NAN;
    }
    if (self.imageView.contentMode == UIViewContentModeScaleAspectFit) {
        return MIN(widthScale, heightScale);
    }
    if (self.imageView.contentMode == UIViewContentModeScaleAspectFill) {
        return MAX(widthScale, heightScale);
    }
    return 1.0;
    
}

/*
 Determine the intersection point of two line segments
 Return FALSE if the lines don't intersect
 
 Adapted from http://paulbourke.net/geometry/pointlineplane/pdb.c
 
 */
int LineIntersect(Vec4i l1, Vec4i l2)
{
    
    double x1=l1[0];
    double x2=l1[2];
    double x3=l2[0];
    double x4=l2[2];
    
    
    double y1=l1[1];
    double y2=l1[3];
    double y3=l2[1];
    double y4=l2[3];
    
    double mua,mub;
    double denom,numera,numerb;
    
    denom  = (y4-y3) * (x2-x1) - (x4-x3) * (y2-y1);
    numera = (x4-x3) * (y1-y3) - (y4-y3) * (x1-x3);
    numerb = (x2-x1) * (y1-y3) - (y2-y1) * (x1-x3);
    
    /* Are the line coincident? */
    if (ABS(numera) < EPS && ABS(numerb) < EPS && ABS(denom) < EPS) {
        return(FALSE);
    }
    
    /* Are the line parallel-ish */
    if (ABS(denom) < 1.0) {
        return(TRUE);
    }
    
    /* Is the intersection along the the segments */
    mua = numera / denom;
    mub = numerb / denom;
    if (mua < -0.1 || mua > 1.1 || mub < -0.1 || mub > 1.1) {
        return(FALSE);
    }
    return(TRUE);
}

- (IBAction)nextTestPressed:(id)sender {
    
    if (self.testCase == 1) {
        self.imageView.image = [UIImage imageNamed:@"fake_p.png"];
        self.testCase = 2;
        self.nextTest.hidden=YES;
        self.letsSeeButton.hidden = NO;
        self.resultLabel.text = @"";
    }
    else if (self.testCase == 2) {
        self.imageView.image = [UIImage imageNamed:@"tester.png"];
        self.testCase = 3;
        self.nextTest.hidden=YES;
        self.letsSeeButton.hidden = NO;
        self.resultLabel.text = @"";
    }
    else if (self.testCase == 3) {
        self.imageView.image = [UIImage imageNamed:@"logo.png"];
        self.testCase = 1;
        self.nextTest.hidden=YES;
        self.letsSeeButton.hidden = NO;
        self.resultLabel.text = @"";
    }
    
}


- (IBAction)detectCircles:(id)sender {
    
    self.nextTest.hidden=NO;
    self.letsSeeButton.hidden=YES;
    
    //Conversion from http://stackoverflow.com/a/10254561
    //See Also http://stackoverflow.com/a/14336157 for orientation
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(self.imageView.image.CGImage);
    CGFloat cols = self.imageView.image.size.width;
    CGFloat rows = self.imageView.image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to backing data
                                                    cols,                      // Width of bitmap
                                                    rows,                     // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), self.imageView.image.CGImage);
    CGContextRelease(contextRef);
    
    cv::Mat dst;
    
    // http://docs.opencv.org/doc/tutorials/imgproc/imgtrans/canny_detector/canny_detector.html
    // Canny(cvMat, dst, 100, 200, 3);
    Canny(cvMat, dst, 10, 30, 3);
    
     
    // ML sept 19, 2013
    // http://docs.opencv.org/doc/tutorials/imgproc/imgtrans/hough_circle/hough_circle.html
    
    /// Reduce the noise so we avoid false circle detection
    GaussianBlur( dst, dst, cv::Size(9, 9), 2, 2 );
    
    vector<Vec3f> circles;
    
    /// Apply the Hough Transform to find the circles
    HoughCircles( dst, circles, CV_HOUGH_GRADIENT, 1, dst.rows/8, 60, 60);
    
    NSLog(@"circles found must be equal to or greater than 2. found: %lu\n\n", circles.size());
    
    if (![self testNumberOfCirclesFound:circles.size()]) {
        
        self.resultLabel.textColor = [UIColor redColor];
        self.resultLabel.text = @"NO, FOOL!";
       // return;
    }
    
    int bigRadius = 0;
    int littleRadius = 0;
    cv::Point bigCenter, littleCenter;
    
    
    /// Draw the circles detected
    for( size_t i = 0; i < circles.size(); i++ )
    {
        cv::Point center(cvRound(circles[i][0]), cvRound(circles[i][1]));
        int radius = cvRound(circles[i][2]);
        // circle center
        circle( cvMat, center, 3, Scalar(0,255,0), -1, 8, 0 );
        // circle outline
        circle( cvMat, center, radius, Scalar(0,0,255), 3, 8, 0 );
        
        NSLog(@"drawing a circle w center: %i,%i and radius: %i\n\n", center.x, center.y, radius);
        
        bigRadius = radius;
        bigCenter = center;
        
        // nest in a look at the other circles
        
        for( size_t j = i + 1; j < circles.size(); j++) {
            
            cv::Point center2(cvRound(circles[j][0]), cvRound(circles[j][1]));
            
            littleRadius = cvRound(circles[j][2]);
            littleCenter = center2;
                
                cv::Point center3(cvRound(circles[j][0]), cvRound(circles[j][1]));
                
                littleRadius = cvRound(circles[j][2]);
                littleCenter = center3;

                // test possibility
                if (![self testOrderingOfBigRadius:bigRadius LittleRadius:littleRadius]) {
                    continue;
                }
                
                if (![self compareBigRadius:bigRadius LittleRadius:littleRadius]) {
                    NSLog(@"ratio of big radius to little radius is off, this possibility fails\n\n");
                    continue;
                }
                
                if (![self compareBigRadius:bigRadius DistBetweenBigCenter:bigCenter LittleCenter:littleCenter]) {
                    NSLog(@"ratio of big radius to center distances is off, this possibility fails\n\n");
                    continue;
                }
                
                // if you passed all those tests it is a match!
                self.resultLabel.textColor = [UIColor blueColor];
                self.resultLabel.text = @"YES!!";
                
                break;
            
        }
    }
    
    if (!self.resultLabel.text.length > 0) {
        
        self.resultLabel.textColor = [UIColor redColor];
        self.resultLabel.text = @"NO, FOOL!";
    }
    
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize() * cvMat.total()];
        
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                     // Width
                                        cvMat.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * cvMat.elemSize(),                           // Bits per pixel
                                        cvMat.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Colorspace
                                        kCGImageAlphaNone | kCGBitmapByteOrderDefault,  // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);                     // Intent
    
    UIImage *newImage = [[UIImage alloc] initWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);

    [self.imageView setImage:newImage];
}

- (BOOL)testNumberOfCirclesFound:(int)numberOfCirclesFound {
    
    if (numberOfCirclesFound >= 2) {
        return YES;
    }
    
    return NO;
}

- (BOOL)testOrderingOfBigRadius:(int)bigRadius LittleRadius:(int)littleRadius {
    
    if (bigRadius > littleRadius) {
        return YES;
    }
    
    return NO;
}

-(BOOL)compareBigRadius:(int)bigRadius LittleRadius:(int)littleRadius {
    
    float ratio = (float)bigRadius / (float)littleRadius;
    
    if (ratio > 10 && ratio < 12) {
        return YES;
    }

    return NO;
}

-(BOOL)compareBigRadius:(int)bigRadius DistBetweenBigCenter:(cv::Point)bigCenter LittleCenter:(cv::Point)littleCenter {
    
    float distance = sqrt(pow((bigCenter.x-littleCenter.x),2) + pow((bigCenter.y-littleCenter.y),2));
    
    float ratio = (float)bigRadius / distance;
    
    if (ratio > 1.75 && ratio < 2.75) {
        return YES;
    }
    
    return NO;
}


- (IBAction)getAndApplyTransformPressed:(id)sender {
    
    //See alternate tutorial and method at http://opencv-code.com/tutorials/automatic-perspective-correction-for-quadrilateral-objects/
        
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(self.originalImage.CGImage);
    CGFloat cols = self.originalImage.size.width;
    CGFloat rows = self.originalImage.size.height;
        
    cv::Mat originalMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(originalMat.data,                 // Pointer to backing data
                                                    cols,                      // Width of bitmap
                                                    rows,                     // Height of bitmap
                                                    8,                          // Bits per component
                                                    originalMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), self.originalImage.CGImage);
    CGContextRelease(contextRef);

    Point2f src[4];
    Point2f dst[4];

    src[0]=cv::Point([self.cubeCorners[0] floatValue],[self.cubeCorners[1] floatValue]); //upper left
    src[1]=cv::Point([self.cubeCorners[2] floatValue],[self.cubeCorners[3] floatValue]); //upper right
    src[2]=cv::Point([self.cubeCorners[4] floatValue],[self.cubeCorners[5] floatValue]); //lower left
    src[3]=cv::Point([self.cubeCorners[6] floatValue],[self.cubeCorners[7] floatValue]); //lower right
    
    dst[0]=cv::Point(0,0);
    dst[1]=cv::Point(self.imageView.frame.size.width,0);
    dst[2]=cv::Point(0,self.imageView.frame.size.height);
    dst[3]=cv::Point(self.imageView.frame.size.width,self.imageView.frame.size.height);
    
    cv::Mat transform = cv::getPerspectiveTransform(src, dst);
    
    cv::Mat transformedimage = Mat::zeros( self.imageView.frame.size.height, self.imageView.frame.size.width, originalMat.type() );
    
    cv::warpPerspective(originalMat, transformedimage, transform, transformedimage.size() );

    
    NSData *data = [NSData dataWithBytes:transformedimage.data length:transformedimage.elemSize() * transformedimage.total()];
    
    if (transformedimage.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGImageRef imageRef = CGImageCreate(transformedimage.cols,                                     // Width
                                        transformedimage.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * transformedimage.elemSize(),                           // Bits per pixel
                                        transformedimage.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Colorspace
                                        kCGImageAlphaNone | kCGBitmapByteOrderDefault,  // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);                     // Intent
    
    self.perspectiveShiftedImage = [[UIImage alloc] initWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    [self.imageView setImage:self.perspectiveShiftedImage];

}

- (IBAction)extractColorsPressed:(id)sender {
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(self.self.perspectiveShiftedImage.CGImage);
    CGFloat cols = self.self.perspectiveShiftedImage.size.width;
    CGFloat rows = self.self.perspectiveShiftedImage.size.height;
        
    cv::Mat facesMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(facesMat.data,                 // Pointer to backing data
                                                    cols,                      // Width of bitmap
                                                    rows,                     // Height of bitmap
                                                    8,                          // Bits per component
                                                    facesMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), self.self.perspectiveShiftedImage.CGImage);
    CGContextRelease(contextRef);
    
    //Convert to HSV to make it easier to see colors
    cv::Mat fullImageHSV;
    cvtColor(facesMat, fullImageHSV, CV_RGB2HSV);

    //Get Average color from http://answers.opencv.org/question/10758/get-the-average-color-of-image-inside-the/
    
    int subCubeWidth = int(cols/3.0f+0.5);
    int subCubeHeight = int(rows/3.0f+0.5);
    int marginX=int(subCubeWidth/5.0f+0.5);
    int marginY=int(subCubeHeight/5.0f+0.5);
    int roiWidth = subCubeWidth - 2* marginX;
    int roiHeight = subCubeHeight - 2* marginY;

    
    //Extraction here from http://opencv-users.1802565.n2.nabble.com/Assign-a-value-to-an-ROI-in-a-Mat-td4540333.html
    for (int hSlice=0; hSlice<3; hSlice++) {
        for (int vSlice= 0; vSlice<3; vSlice++) {
            cv::Rect r(marginX+subCubeWidth*hSlice, marginY+subCubeHeight*vSlice, roiWidth, roiHeight);
            Mat roi(fullImageHSV,r);
            cv::Scalar avgColor=cv::mean(roi); //Average Color
            roi = avgColor;
            //Put text from http://stackoverflow.com/questions/5175628/how-to-overlay-text-on-image-when-working-with-cvmat-type
            if (avgColor[1] < 10) {
                //No Saturation - must be white
                cv::putText(roi, [[NSString stringWithFormat:@"%d,%d=%.0f",hSlice,vSlice,avgColor[1]] cStringUsingEncoding:NSASCIIStringEncoding], cvPoint(0,10),
                            FONT_HERSHEY_COMPLEX_SMALL, 0.6, cvScalar(0,0,0), 1, CV_AA);
                cv::putText(roi, [@"White" cStringUsingEncoding:NSASCIIStringEncoding], cvPoint(0,30),
                            FONT_HERSHEY_COMPLEX_SMALL, 0.6, cvScalar(0,0,0), 1, CV_AA);
            } else {
                cv::putText(roi, [[NSString stringWithFormat:@"%d,%d=%.0f",hSlice,vSlice,avgColor[0]] cStringUsingEncoding:NSASCIIStringEncoding], cvPoint(0,10),
                            FONT_HERSHEY_COMPLEX_SMALL, 0.5, cvScalar(200,200,200), 1, CV_AA);
                NSString *color=@"unknown";
                CGFloat hue =avgColor[0];
                if (hue < 10) {
                    color=@"orange";
                } else if (hue > 10 && hue < 30) {
                    color=@"yellow";
                } else if (hue > 55 && hue < 65) {
                    color=@"green";
                } else if (hue > 115 && hue < 130) {
                    color=@"blue";
                } else if (hue > 170 && hue < 190) {
                    color=@"red";
                }
                cv::putText(roi, [color cStringUsingEncoding:NSASCIIStringEncoding], cvPoint(0,30),
                            FONT_HERSHEY_COMPLEX_SMALL, 0.6, cvScalar(0,0,0), 1, CV_AA);

                Mat rgbroi;
                cvtColor(roi, rgbroi, CV_HSV2RGB);
                cv::Scalar avgColorRGB=cv::mean(rgbroi); //Average Color
                cv::putText(roi, [[NSString stringWithFormat:@"%.0f/%.0f/%.0f",avgColorRGB[0],avgColorRGB[1],avgColorRGB[2]] cStringUsingEncoding:NSASCIIStringEncoding], cvPoint(0,50),
                            FONT_HERSHEY_COMPLEX_SMALL, 0.5, cvScalar(200,200,200), 1, CV_AA);

            }
        }
    }
    
    //Convert Back to RGB to display to make it easier to see colors
    cv::Mat fullImageRGB;
    cvtColor(fullImageHSV, fullImageRGB, CV_HSV2RGB);

    
    NSData *data = [NSData dataWithBytes:fullImageRGB.data length:fullImageRGB.elemSize() * fullImageRGB.total()];
    
    colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGImageRef imageRef = CGImageCreate(fullImageRGB.cols,                                     // Width
                                        fullImageRGB.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * fullImageRGB.elemSize(),                           // Bits per pixel
                                        fullImageRGB.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Colorspace
                                        kCGImageAlphaNone | kCGBitmapByteOrderDefault,  // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);                     // Intent
    
    UIImage *newImage = [[UIImage alloc] initWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    [self.imageView setImage:newImage];
    
    
}

@end
