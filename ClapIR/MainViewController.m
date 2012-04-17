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
    UIAlertView* _waitAlert;
}
-(void)reset;
@end

@implementation MainViewController

@synthesize pauseButton, undoButton, optionsButton;
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
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    _plotViews = [NSArray arrayWithObjects:reverbPlotView, directSoundPlotView, freqResponsePlotView, nil];
    
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
-(void)reset{
    // clear plots
    for( int i=0; i<_measurements.count; i++ ){
        [self undo];
    }
    
    // restart audio
    NSLog( @"￼Calculating background level..." );
    
    [recorder stop];
    [recorder start];
    
    // alert user that fingerprint is not yet ready
	_waitAlert = [[UIAlertView alloc] initWithTitle:@"Please wait" 
                                            message:@"Five seconds of audio are needed to compute the background level.  Be quiet!" 
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

typedef enum{
    EMAIL_FEEDBACK,
    EMAIL_RESULTS
} EmailType;

-(void)emailWithType:(EmailType)type{
    if( [MFMailComposeViewController canSendMail] ){
        MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
        mailer.mailComposeDelegate = self;
        
        // email measurements
        NSString* subj = (type==EMAIL_RESULTS) ? @"Results" : @"Feedback";
        [mailer setSubject:[NSString stringWithFormat:@"[ClapIR v%@] %@", 
                            [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],
                            subj]];
        NSString* body;
        if( type == EMAIL_RESULTS ){
            body = ((ClapMeasurement*)(_measurements.lastObject)).description;
        }else if( type == EMAIL_FEEDBACK ){
            [mailer setToRecipients:[NSArray arrayWithObjects:@"steve@stevetarzia.com", @"prem@u.northwestern.edu", nil]];
        }
        [mailer setMessageBody:body isHTML:NO];
        
        [self presentModalViewController:mailer animated:YES];
    }else{
        UIAlertView *myAlert = [[UIAlertView alloc] initWithTitle:@"Email unavailable" 
                                                          message:@"Please configure your email settings before trying to use this option." 
                                                         delegate:self 
                                                cancelButtonTitle:@"OK" 
                                                otherButtonTitles:nil];
        [myAlert show];	
    }

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

-(void)options{
    UIActionSheet* optionsSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                              delegate:self 
                                                     cancelButtonTitle:@"Cancel" 
                                                destructiveButtonTitle:nil 
                                                     otherButtonTitles:@"Visit the website",@"Email us feedback",@"Email your results",@"Reset",nil];
    [optionsSheet showFromBarButtonItem:self.optionsButton animated:YES];
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
    
    // dismiss waiting indicator
    [_waitAlert dismissWithClickedButtonIndex:0 animated:YES];
    _waitAlert = nil;
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
        [self dismissModalViewControllerAnimated:YES];
        
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
