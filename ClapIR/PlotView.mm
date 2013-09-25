//
//  plotView.m
//  simpleUI
//
//  Created by Stephen Tarzia on 9/30/10.
//Vec

#import "PlotView.h"
#include <algorithm> //for min_element, max_element

@interface PlotView(){
    float* _data;
    unsigned int _length;
}
@end

@implementation PlotView

@synthesize data = _data;
@synthesize length = _length;
@synthesize minY, maxY;
@synthesize lineColor;
@synthesize autoZoomOut;
@synthesize clickToAutoRange;
@synthesize lineWidth;

- (id)initWithFrame:(CGRect)frame{
    if ((self = [super initWithFrame:frame])) {
        // Initialization code
		//self.backgroundColor = [UIColor whiteColor];
		//self.opaque = YES;
		self.opaque = NO;
		self.clearsContextBeforeDrawing = YES;

        self.lineWidth = 0.5;

		// TODO: automatically set range
		[self setYRange_min:-1 max:1];
		_data = NULL;
		
		[self setNeedsDisplay]; // make it redraw
	}
	self.lineColor = [UIColor redColor];
	
	// enable clicks
	self.userInteractionEnabled = YES;
    
    self.autoZoomOut = NO;
    self.clipsToBounds = YES; // do not let lines exceed plot boundary
	
    return self;
}

// to handle clicks
-(BOOL) canBecomeFirstResponder{ return YES; }
-(void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event{
    if( clickToAutoRange ){
        [self autoRange];
    }
}

-(void) setVector: (float*)dataPtr length:(unsigned int)len{
	_length = len;
	_data = dataPtr;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
	// do nothing is fingerprinter is not ready
	if( !self.data || self.length == 0 ) return;
    
	// Drawing code
    CGContextRef context = UIGraphicsGetCurrentContext();

	// zoom out, if necessary
    if( autoZoomOut ){
        float min_val = *std::min_element(self.data, self.data+self.length ); 
        float max_val = *std::max_element(self.data, self.data+self.length );
        if( min_val < self.minY ){
            [self setYRange_min:min_val max:self.maxY];
        }
        if( max_val > self.maxY ){
            [self setYRange_min:self.minY max:max_val];
        }
    }
	
	// Get boundary information for this view, so that drawing can be scaled
	float X = self.bounds.size.width;
	float Y = self.bounds.size.height;

	// Drawing lines with the appropriate color
	CGContextSetStrokeColor(context, CGColorGetComponents( self.lineColor.CGColor ) );

	float plot_range = self.maxY - self.minY;
	float xStep = X/(self.length-1);
	float yStep = Y/plot_range;
	
	if( self.length > 0 ){
		// start off the line at the left side
		CGContextMoveToPoint(context, 0, Y - (self.data[0]-self.minY) * yStep);
		for( int i=1; i<self.length; ++i ){ // starting w/2nd data point
            CGFloat dataPoint = self.data[i];
            // don't let plot go up or down to infinity
            if( isinf(dataPoint) ) dataPoint = NAN;
            
            // don't try to draw with invalid coordinates
            CGFloat drawY = Y - (dataPoint-self.minY) * yStep;
            if( !isfinite(drawY) ) drawY = Y;
            
            // draw
            CGContextAddLineToPoint(context, i * xStep, drawY );
			CGContextMoveToPoint(context, i * xStep, drawY );
			//printf("line %f %f %f\n", data[i], i * xStep, drawY);
		}
		CGContextSetLineWidth(context, lineWidth);
		CGContextStrokePath(context);
	}
	[self setNeedsDisplay]; // make it redraw
}

-(void) setYRange_min:(float)newMinY  max:(float)newMaxY {
	self.minY = newMinY;
	self.maxY = newMaxY;
	[self setNeedsDisplay]; // make it redraw
}

-(void) autoRange{
	// update view range
	float min_val = *std::min_element(self.data, self.data+self.length ); 
	float max_val = *std::max_element(self.data, self.data+self.length );
	[self setYRange_min:min_val max:max_val];	
}


@end
