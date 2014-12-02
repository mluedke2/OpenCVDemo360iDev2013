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

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

	self.testCase = 1;
	self.letsSeeButton.hidden = NO;
	self.nextTest.hidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];

	self.originalImage = self.imageView.image;
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (CGFloat)contentScaleFactor {
	CGFloat widthScale = self.imageView.bounds.size.width / self.imageView.image.size.width;
	CGFloat heightScale = self.imageView.bounds.size.height / self.imageView.image.size.height;

	if (self.imageView.contentMode == UIViewContentModeScaleToFill) {
		return (widthScale == heightScale) ? widthScale : NAN;
	}
	if (self.imageView.contentMode == UIViewContentModeScaleAspectFit) {
		return MIN(widthScale, heightScale);
	}
	if (self.imageView.contentMode == UIViewContentModeScaleAspectFill) {
		return MAX(widthScale, heightScale);
	}
	return 1.0;
}

- (IBAction)nextTestPressed:(id)sender {
	if (self.testCase == 1) {
		self.imageView.image = [UIImage imageNamed:@"fake_p.png"];
		self.testCase = 2;
		self.nextTest.hidden = YES;
		self.letsSeeButton.hidden = NO;
		self.resultLabel.text = @"";
	}
	else if (self.testCase == 2) {
		self.imageView.image = [UIImage imageNamed:@"tester.png"];
		self.testCase = 3;
		self.nextTest.hidden = YES;
		self.letsSeeButton.hidden = NO;
		self.resultLabel.text = @"";
	}
	else if (self.testCase == 3) {
		self.imageView.image = [UIImage imageNamed:@"logo.png"];
		self.testCase = 1;
		self.nextTest.hidden = YES;
		self.letsSeeButton.hidden = NO;
		self.resultLabel.text = @"";
	}
}

- (IBAction)detectCircles:(id)sender {
	self.nextTest.hidden = NO;
	self.letsSeeButton.hidden = YES;

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
	GaussianBlur(dst, dst, cv::Size(9, 9), 2, 2);

	vector <Vec3f> circles;

	/// Apply the Hough Transform to find the circles
	HoughCircles(dst, circles, HOUGH_GRADIENT, 1, dst.rows / 8, 60, 60);

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
	for (size_t i = 0; i < circles.size(); i++) {
		cv::Point center(cvRound(circles[i][0]), cvRound(circles[i][1]));
		int radius = cvRound(circles[i][2]);
		// circle center
		circle(cvMat, center, 3, Scalar(0, 255, 0), -1, 8, 0);
		// circle outline
		circle(cvMat, center, radius, Scalar(0, 0, 255), 3, 8, 0);

		NSLog(@"drawing a circle w center: %i,%i and radius: %i\n\n", center.x, center.y, radius);

		bigRadius = radius;
		bigCenter = center;

		// nest in a look at the other circles

		for (size_t j = i + 1; j < circles.size(); j++) {
			cv::Point center2(cvRound(circles[j][0]), cvRound(circles[j][1]));

			littleRadius = cvRound(circles[j][2]);
			littleCenter = center2;

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
	}
	else {
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

- (BOOL)compareBigRadius:(int)bigRadius LittleRadius:(int)littleRadius {
	float ratio = (float)bigRadius / (float)littleRadius;

	if (ratio > 10 && ratio < 12) {
		return YES;
	}

	return NO;
}

- (BOOL)compareBigRadius:(int)bigRadius DistBetweenBigCenter:(cv::Point)bigCenter LittleCenter:(cv::Point)littleCenter {
	float distance = sqrt(pow((bigCenter.x - littleCenter.x), 2) + pow((bigCenter.y - littleCenter.y), 2));

	float ratio = (float)bigRadius / distance;

	if (ratio > 1.75 && ratio < 2.75) {
		return YES;
	}

	return NO;
}

@end
