//
//  plotView.h
//  simpleUI
//
//  Created by Stephen Tarzia on 9/30/10.
//  Copyright 2010 Northwestern University. All rights reserved.
//

#import <UIKit/UIKit.h>
//#import <vector>

@interface PlotView : UIView {
    float* data; // the data to plot
	unsigned int length; // the length of data array
	// y axis range for plot:
	float minY;
	float maxY;
	float* lineColor; // RGB array
}

@property (nonatomic) float* data;
@property (nonatomic) unsigned int length;
@property (nonatomic) float minY;
@property (nonatomic) float maxY;
@property (nonatomic) float* lineColor;
@property (nonatomic) BOOL autoZoomOut;

// set the y axis range of the plot
-(void)setYRange_min: (float)Ymin  max:(float)Ymax;
// automatically set the range based on the values in the vector
-(void)autoRange;
-(id)initWithFrame:(CGRect)frame;
-(void)setVector: (float*)data length:(unsigned int)len;

@end
