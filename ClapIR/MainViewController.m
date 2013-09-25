//
//  MainViewController.m
//  ClapIR
//
//  Created by Stephen Tarzia on 4/14/12.
//

#import "MainViewController.h"
#import "PlotView.h"
#import "AppDelegate.h"

@interface MainViewController (){
    // by storing ClapMeasurement objects in an NSObject, we manage their C-array memory
    NSMutableArray* _measurements;
    NSArray* _plotViews; // contains reverbPlotView, directSoundPlotView, freqResponsePlotView;
    UIAlertView* _waitAlert;
    BOOL _paused;
    PlotView *_reverbAvgPlot, *_directSoundAvgPlot, *_freqResponseAvgPlot;
    UIView* _flash;
}
-(void)reset;
-(void)start;
-(void)redraw;
-(void)flash;
@end

@implementation MainViewController

@synthesize toolbar;
@synthesize pauseButton, undoButton, optionsButton;
@synthesize toggleControl;
@synthesize reverbView, spectraView;
@synthesize reverbPlotView, directSoundPlotView, freqResponsePlotView;
@synthesize avgMeasurement;
@synthesize instructions;

@synthesize recorder;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _paused = NO;
    }
    return self;
}

-(void)dealloc{
    recorder.delegate = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    _flash = [[UIView alloc] initWithFrame:self.reverbView.frame];
    _flash.alpha = 0;
    _flash.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_flash];
    // make instructions appear in a shaded box
    instructions.backgroundColor = [UIColor yellowColor];
    instructions.shadowColor = [UIColor blackColor];
    instructions.shadowOffset = CGSizeMake(5, 5);
    
    _plotViews = [NSArray arrayWithObjects:reverbPlotView, directSoundPlotView, freqResponsePlotView, nil];
    
    // set up average plots
    // add them on top of the views containing the other curves
    _reverbAvgPlot = [[PlotView alloc] initWithFrame:reverbPlotView.frame];
    [reverbView addSubview:_reverbAvgPlot];
    _directSoundAvgPlot = [[PlotView alloc] initWithFrame:directSoundPlotView.frame];
    [spectraView addSubview:_directSoundAvgPlot];
    _freqResponseAvgPlot = [[PlotView alloc] initWithFrame:freqResponsePlotView.frame];
    [spectraView addSubview:_freqResponseAvgPlot];
    // set curve appearance
    UIColor* black = [UIColor colorWithRed:0 green:0 blue:0 alpha:1];
    _reverbAvgPlot.lineColor = _directSoundAvgPlot.lineColor = _freqResponseAvgPlot.lineColor = black;
    _reverbAvgPlot.lineWidth = _directSoundAvgPlot.lineWidth = _freqResponseAvgPlot.lineWidth = 1.5;
    // set curve range
    [_reverbAvgPlot       setYRange_min:0 max:3];
    [_directSoundAvgPlot  setYRange_min:0 max:80];
    [_freqResponseAvgPlot setYRange_min:0 max:80];
    
    // initialize view toggle selection
    toggleControl.selectedSegmentIndex = 0;
    [self indexDidChangeForSegmentedControl:toggleControl];
    
    // start audio
    recorder = [[ClapRecorder alloc] init];
    recorder.delegate = self;
    [self start];
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
-(void)reset{
    [((AppDelegate*)([UIApplication sharedApplication].delegate)) reset];
}

-(void)start{
    @synchronized( self ){
        // remove measurements
        _measurements = [NSMutableArray array];
        // delete plots
        for( UIView* plotSuperView in _plotViews ){
            for( PlotView* plot in plotSuperView.subviews ){
                [plot removeFromSuperview];
            }
        }
        // reset average curves
        avgMeasurement = [[ClapMeasurement alloc] init];
        [avgMeasurement clear];
    }
    [self redraw];
    
    // restart audio
    NSLog( @"￼Calculating background level..." );
    
    [recorder stop];
    [recorder start];
    
    // alert user that fingerprint is not yet ready
	_waitAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Please wait", nil)
                                            message:NSLocalizedString(@"WAIT INSTRUCTIONS", nil)
                                           delegate:nil 
                                  cancelButtonTitle:nil 
                                  otherButtonTitles:nil];
	[_waitAlert show];
	// add spinning activity indicator
	UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]  
										  initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];  
	indicator.center = CGPointMake(140, 130);  
	[indicator startAnimating];  
	[_waitAlert addSubview:indicator];  
}

-(IBAction)togglePause{
    // toggle
    [self setPaused:!_paused];    
}

-(void)setPaused:(BOOL)paused{
    _paused = paused;
    
    // update toolbar
    UIBarButtonSystemItem style = _paused? UIBarButtonSystemItemPlay : UIBarButtonSystemItemPause;
    UIBarButtonItem* newPauseButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:style
                                                                                    target:self
                                                                                    action:@selector(togglePause)];
    newPauseButton.style = UIBarButtonItemStyleBordered;
    pauseButton = newPauseButton;
    NSMutableArray* toolbarItems = [NSMutableArray arrayWithArray:toolbar.items];
    [toolbarItems replaceObjectAtIndex:0 withObject:newPauseButton];
    [toolbar setItems:toolbarItems];
    [toolbar setNeedsLayout];
}

-(void)flash{
    [UIView animateWithDuration:0.1
                     animations:^(void){
                         _flash.alpha = 1.0;
                     } completion:^(BOOL finished){
                        [UIView animateWithDuration:0.1
                                         animations:^(void){
                         _flash.alpha = 0;
                                         }];
                     }];
}

typedef enum{
    EMAIL_FEEDBACK,
    EMAIL_RESULTS
} EmailType;

-(void)emailWithType:(EmailType)type{
    if( [MFMailComposeViewController canSendMail] ){
        MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
        mailer.mailComposeDelegate = self;
        
        // email measurements
        @synchronized( self ){
            NSString* subj = (type==EMAIL_RESULTS) ? @"Results" : @"Feedback";
            [mailer setSubject:[NSString stringWithFormat:@"[ClapIR v%@] %@", 
                                [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],
                                subj]];
            NSString* body;
            if( type == EMAIL_RESULTS ){
                body = avgMeasurement.description;
            }else if( type == EMAIL_FEEDBACK ){
                [mailer setToRecipients:[NSArray arrayWithObjects:@"steve@stevetarzia.com", @"prem@u.northwestern.edu", nil]];
            }
            [mailer setMessageBody:body isHTML:NO];
        }
        [self presentModalViewController:mailer animated:YES];
    }else{
        UIAlertView *myAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString( @"Email unavailable", nil )
                                                          message:NSLocalizedString( @"EMAIL ERROR", nil )
                                                         delegate:self 
                                                cancelButtonTitle:@"OK" 
                                                otherButtonTitles:nil];
        [myAlert show];	
    }

}

-(void)redraw{
    @synchronized( self ){
        // make previously-most-recent lines yellow in all three plots
        if( _measurements.count > 1 ){
            for( UIView* curveSuperView in _plotViews ){            
                PlotView* prevPlot = [curveSuperView.subviews objectAtIndex:curveSuperView.subviews.count-2];
                prevPlot.lineColor = [UIColor yellowColor];
                [prevPlot setNeedsDisplay];
            }
        }
        
        // redraw
        [_reverbAvgPlot       setNeedsDisplay];
        [_directSoundAvgPlot  setNeedsDisplay];
        [_freqResponseAvgPlot setNeedsDisplay];
        for( UIView* view in _plotViews ){
            [view drawRect:view.bounds];
        }
    }
}

-(IBAction)undo{
    @synchronized( self ){
        // erase latest plot line from all three plots
        if( _measurements.count > 0 ){
            for( UIView* curveSuperView in _plotViews ){
                PlotView* lastPlot = curveSuperView.subviews.lastObject;
                [lastPlot removeFromSuperview];
            }
            ClapMeasurement* lastMeasurement = _measurements.lastObject;
            [_measurements removeLastObject];
            // recalculate average
            [avgMeasurement removeSample:lastMeasurement];
        }
    }
    [self redraw];
}

-(IBAction)indexDidChangeForSegmentedControl:(UISegmentedControl*)aSegmentedControl {
    if( aSegmentedControl == self.toggleControl ){
        // hide/show appropriate views
        self.reverbView.hidden  = ( self.toggleControl.selectedSegmentIndex != 0 );
        self.spectraView.hidden = ( self.toggleControl.selectedSegmentIndex != 1 );
    }
}

-(void)options{
    UIActionSheet* optionsSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                              delegate:self 
                                                     cancelButtonTitle:NSLocalizedString( @"Cancel", nil )
                                                destructiveButtonTitle:nil 
                                                     otherButtonTitles:NSLocalizedString( @"Visit the website", nil ),
                                                                       NSLocalizedString( @"Email us feedback", nil ),
                                                                       NSLocalizedString( @"Email your results", nil ),
                                                                       NSLocalizedString( @"Reset", nil ),
                                                                       nil];
    [optionsSheet showFromBarButtonItem:self.optionsButton animated:YES];

    // pause recorder while on the actionsheet or composing email
    [self setPaused:YES];
}


#pragma mark - ClapRecorderDelegate methods
-(void)gotMeasurement:(ClapMeasurement *)measurement{
    // ignore measurement if we're paused
    if( _paused ) return;
    
    @synchronized( self ){
        // store measurement
        [_measurements addObject:measurement];
        
        // recalculate average
        [avgMeasurement addSample:measurement];

        // add data pointer to plots for average
        // below, average plot is last sibling to view containing measurement curves
        [_reverbAvgPlot       setVector:avgMeasurement.reverbTimeSpectrum   length:ClapMeasurement.numFreqs];
        [_directSoundAvgPlot  setVector:avgMeasurement.directSoundSpectrum  length:ClapMeasurement.numFreqs];
        [_freqResponseAvgPlot setVector:avgMeasurement.freqResponseSpectrum length:ClapMeasurement.numFreqs];   
        
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
    }
    [self redraw];
    
    // flash screen
    [self flash];
    
    // hide instructions
    instructions.hidden = YES;
}

-(void)gotBackgroundLevel:(float)energy{
    float decibels = 20 * log10f( energy );
    NSLog( @"background level is %.0f dB",decibels );
    
    // dismiss waiting indicator
    [_waitAlert dismissWithClickedButtonIndex:0 animated:YES];
    _waitAlert = nil;
    
    // show instructions
    instructions.hidden = NO;
    [self.view addSubview:instructions];
}

#pragma mark - UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
    if( buttonIndex == 0 ){ // zero is the bottom red buttom for cancel confirmation
        // website
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/starzia/ClapIR"]];
    }else if( buttonIndex == 1 ) {
        // feedback
        [self emailWithType:EMAIL_FEEDBACK];
    }else if( buttonIndex == 2 ){
        // email results
        [self emailWithType:EMAIL_RESULTS];
    }else if( buttonIndex == 3 ){
        // reset
        [self reset];
    }else if( buttonIndex == 4 ){
        // dismiss view
    }
}

#pragma mark - MKMailComposeViewControllerDelegate

// finished trying to email
- (void)mailComposeController:(MFMailComposeViewController*)controller 
		  didFinishWithResult:(MFMailComposeResult)result 
						error:(NSError*)error{
	// make email window disappear
	[controller dismissModalViewControllerAnimated:YES];
}

@end
