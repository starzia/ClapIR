//
//  MeasurementViewController.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/19/12.
//

#import "MeasurementViewController.h"
#import "PlotView.h"

@interface MeasurementViewController (){
    UILabel* _rt60Label;
    UILabel* _backgroundLabel;
    UIButton* _resetButton;
    NSMutableArray* _plots;
    NSMutableArray* _plotCurves;
    UIImageView* _gridView;
}
-(void)reset;
@end

@implementation MeasurementViewController
@synthesize recorder;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    _rt60Label = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 320-20, 30)];
    _rt60Label.text = @"";
    [self.view addSubview:_rt60Label];

    _backgroundLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 50, 320-20, 30)];
    [self.view addSubview:_backgroundLabel];
    
    _resetButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _resetButton.frame = CGRectMake( 100, 90, 320-200, 40 );
    [_resetButton setTitle:@"reset" forState:UIControlStateNormal];
    [_resetButton addTarget:self 
                     action:@selector(reset) 
           forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_resetButton];
    
    _plotCurves = [NSMutableArray array];
    _plots = [NSMutableArray array];
    

    _gridView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"grid"]];
    _gridView.frame = CGRectMake(0, 480-320-20, 320, 320);
    [self.view addSubview:_gridView];
    
    // start audio
    recorder = [[ClapRecorder alloc] init];
    recorder.delegate = self;
    [self reset];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - 
-(void) reset{
    // clear plots
    for( PlotView* plot in _plots ){
        [plot removeFromSuperview];
    }
    [_plots removeAllObjects];
    for( NSNumber* floatPointer in _plotCurves ){
        free( (float*)floatPointer.longValue );
    }
    [_plotCurves removeAllObjects];
    
    // restart audio
    _backgroundLabel.text = @"￼Calculating background level...";
    
    [recorder stop];
    [recorder start];
}

#pragma mark - ClapRecorderDelegate methods
-(void)gotMeasurement:(ClapMeasurement *)measurement{
    _rt60Label.text = [NSString stringWithFormat:@"rt60 = %.3f seconds", measurement.reverbTime];
    for( int i=0; i<ClapMeasurement.numFreqs; i++ ){
        NSLog( @"%.0f Hz\t%.3f seconds", ClapMeasurement.specFrequencies[i], 
               measurement.reverbTimeSpectrum[i] );
    }
    // copy vector to plot
    PlotView* plot = [[PlotView alloc] initWithFrame:CGRectMake(29, (480-320-20)+6, 282, 286)];
    [self.view addSubview:plot];
    [_plots addObject:plot];
    
    float* plotCurve = malloc( sizeof(float) * ClapMeasurement.numFreqs );
    memcpy( plotCurve, measurement.reverbTimeSpectrum, sizeof(float) * ClapMeasurement.numFreqs );
    // below store float* in NSarray by casting it as an unsigned long (ugly!)
    [_plotCurves addObject:[NSNumber numberWithUnsignedLong:(unsigned long)plotCurve]];
    
    // update plot
    [plot setVector:plotCurve length:ClapMeasurement.numFreqs];
    [plot setYRange_min:0 max:5];
    
    // redraw
    [self.view setNeedsDisplay];
}

-(void)gotBackgroundLevel:(float)decibels{
    _backgroundLabel.text = [NSString stringWithFormat:@"background level is %.0f dB",decibels];
}
@end
