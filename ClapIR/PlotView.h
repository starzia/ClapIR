//
//  plotView.h
//  simpleUI
//
//  Created by Stephen Tarzia on 9/30/10.
//

#import <UIKit/UIKit.h>
//#import <vector>

@interface PlotView : UIView {
    float* data; // the data to plot
	unsigned int length; // the length of data array
	// y axis range for plot:
	float minY;
	float maxY;
}

@property (nonatomic,readonly) float* data;
@property (nonatomic,readonly) unsigned int length;
@property (nonatomic) float minY;
@property (nonatomic) float maxY;
// TODO: [UIColor blackColor] does not work here because it is in a mono color space
@property (strong,nonatomic) UIColor* lineColor;
@property (nonatomic) float lineWidth;
@property (nonatomic) BOOL autoZoomOut;
@property (nonatomic) BOOL clickToAutoRange;

// set the y axis range of the plot
-(void)setYRange_min: (float)Ymin  max:(float)Ymax;
// automatically set the range based on the values in the vector
-(void)autoRange;
-(id)initWithFrame:(CGRect)frame;
-(void)setVector: (float*)data length:(unsigned int)len;

@end
