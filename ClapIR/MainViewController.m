//
//  MainViewController.m
//  ClapIR
//
//  Created by Stephen Tarzia on 4/14/12.
//  Copyright (c) 2012 VaporStream, Inc. All rights reserved.
//

#import "MainViewController.h"
#import "PlotView.h"

@interface MainViewController (){
    NSMutableArray* _plots;
    NSMutableArray* _plotCurves;
}
-(IBAction)reset;
@end

@implementation MainViewController

@synthesize pauseButton, undoButton, pageCurlButton;
@synthesize toggleControl;
@synthesize reverbView, reverbPlotView;
@synthesize spectraView, directSoundPlotView, freqResponsePlotView;

@synthesize recorder;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _plotCurves = [NSMutableArray array];
        _plots = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    // start audio
    recorder = [[ClapRecorder alloc] init];
    recorder.delegate = self;
    [self reset];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - UIControls
-(IBAction)reset{
    // clear plots
    for( int i=0; i<_plots.count; i++ ){
        [self undo];
    }
    
    // restart audio
    NSLog( @"￼Calculating background level..." );
    
    [recorder stop];
    [recorder start];
}

-(IBAction)undo{
    // erase latest plot line
    if( _plots.count > 0 ){
        PlotView* lastPlot = _plots.lastObject;
        [_plots removeLastObject];
        [lastPlot removeFromSuperview];
        NSNumber* lastFloatPointer = _plotCurves.lastObject;
        [_plotCurves removeLastObject];
        free( (float*)lastFloatPointer.longValue );
    }
}

-(IBAction)indexDidChangeForSegmentedControl:(UISegmentedControl*)aSegmentedControl {
    if( aSegmentedControl == self.toggleControl ){
        // hide/show appropriate views
        self.reverbView.hidden  = ( self.toggleControl.selectedSegmentIndex != 0 );
        self.spectraView.hidden = ( self.toggleControl.selectedSegmentIndex != 1 );
    }
}

#pragma mark - ClapRecorderDelegate methods
-(void)gotMeasurement:(ClapMeasurement *)measurement{
    NSLog( @"rt60 = %.3f seconds", measurement.reverbTime );
    for( int i=0; i<ClapMeasurement.numFreqs; i++ ){
        NSLog( @"%.0f Hz\t%.3f seconds", ClapMeasurement.specFrequencies[i], 
              measurement.reverbTimeSpectrum[i] );
    }
    // copy vector to plot
    PlotView* plot = [[PlotView alloc] initWithFrame:reverbPlotView.bounds];
    [reverbPlotView addSubview:plot];
    [_plots addObject:plot];
    
    float* plotCurve = malloc( sizeof(float) * ClapMeasurement.numFreqs );
    memcpy( plotCurve, measurement.reverbTimeSpectrum, sizeof(float) * ClapMeasurement.numFreqs );
    // below store float* in NSarray by casting it as an unsigned long (hack!)
    [_plotCurves addObject:[NSNumber numberWithUnsignedLong:(unsigned long)plotCurve]];
    
    // update plot
    [plot setVector:plotCurve length:ClapMeasurement.numFreqs];
    [plot setYRange_min:0 max:3];
    // make most recent line red
    [plot setLineColor:[UIColor redColor]];
    // make previously-most-recent line yellow
    if( _plots.count > 1 ){
        PlotView* prevPlot = [_plots objectAtIndex:_plots.count-2];
        prevPlot.lineColor = [UIColor yellowColor];
        [prevPlot setNeedsDisplay];
    }
    
    // redraw
    [reverbPlotView setNeedsDisplay];
}

-(void)gotBackgroundLevel:(float)decibels{
    NSLog( @"background level is %.0f dB",decibels );
}


@end
