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
    // by storing ClapMeasurement objects in an NSObject, we manage their C-array memory
    NSMutableArray* _measurements;
    NSArray* _plotViews; // contains reverbPlotView, directSoundPlotView, freqResponsePlotView;
}
-(IBAction)reset;
@end

@implementation MainViewController

@synthesize pauseButton, undoButton, pageCurlButton;
@synthesize toggleControl;
@synthesize reverbView, spectraView;
@synthesize reverbPlotView, directSoundPlotView, freqResponsePlotView;

@synthesize recorder;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _measurements = [NSMutableArray array];
        _plotViews = [NSArray arrayWithObjects:reverbPlotView, directSoundPlotView, freqResponsePlotView, nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    // initialize view toggle selection
    toggleControl.selectedSegmentIndex = 0;
    [self indexDidChangeForSegmentedControl:toggleControl];
    
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
    return (interfaceOrientation == UIInterfaceOrientationPortrait)
        || (interfaceOrientation == UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - UIControls
-(IBAction)reset{
    // clear plots
    for( int i=0; i<_measurements.count; i++ ){
        [self undo];
    }
    
    // restart audio
    NSLog( @"￼Calculating background level..." );
    
    [recorder stop];
    [recorder start];
}

-(IBAction)undo{
    // erase latest plot line from all three plots
    if( _measurements.count > 0 ){
        for( UIView* curveSuperView in _plotViews ){
            PlotView* lastPlot = curveSuperView.subviews.lastObject;
            [lastPlot removeFromSuperview];
         }
        [_measurements removeLastObject];
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
    // store measurement
    [_measurements addObject:measurement];
    
    NSLog( @"rt60 = %.3f seconds", measurement.reverbTime );
    for( int i=0; i<ClapMeasurement.numFreqs; i++ ){
        NSLog( @"%.0f Hz\t%.3f seconds", ClapMeasurement.specFrequencies[i], 
              measurement.reverbTimeSpectrum[i] );
    }

    // update plot
    {
        // copy vector to plot
        PlotView* plot = [[PlotView alloc] initWithFrame:reverbPlotView.bounds];
        [reverbPlotView addSubview:plot];
        // set curve values
        [plot setVector:measurement.reverbTimeSpectrum length:ClapMeasurement.numFreqs];
        [plot setYRange_min:0 max:3];
        // make most recent line red
        [plot setLineColor:[UIColor redColor]];
    }
    {
        // copy vector to plot
        PlotView* plot = [[PlotView alloc] initWithFrame:directSoundPlotView.bounds];
        [directSoundPlotView addSubview:plot];
        // set curve values
        [plot setVector:measurement.directSoundSpectrum length:ClapMeasurement.numFreqs];
        [plot setYRange_min:0 max:80];
        // make most recent line red
        [plot setLineColor:[UIColor redColor]];
    }
    {
        // copy vector to plot
        PlotView* plot = [[PlotView alloc] initWithFrame:freqResponsePlotView.bounds];
        [freqResponsePlotView addSubview:plot];
        // set curve values
        [plot setVector:measurement.freqResponseSpectrum length:ClapMeasurement.numFreqs];
        [plot setYRange_min:0 max:80];
        // make most recent line red
        [plot setLineColor:[UIColor redColor]];
    }
        
    // make previously-most-recent lines yellow in all three plots
    if( _measurements.count > 1 ){
        for( UIView* curveSuperView in _plotViews ){            
            PlotView* prevPlot = [curveSuperView.subviews objectAtIndex:_measurements.count-2];
            prevPlot.lineColor = [UIColor yellowColor];
            [prevPlot setNeedsDisplay];
        }
    }
    
    // redraw
    for( UIView* view in _plotViews ){
        [view setNeedsDisplay];
    }
}

-(void)gotBackgroundLevel:(float)energy{
    float decibels = 20 * log10f( energy );
    NSLog( @"background level is %.0f dB",decibels );
}


@end
