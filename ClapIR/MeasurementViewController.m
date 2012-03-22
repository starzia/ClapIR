//
//  MeasurementViewController.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/19/12.
//

#import "MeasurementViewController.h"

@interface MeasurementViewController (){
    UILabel* _rt60Label;
    UILabel* _backgroundLabel;
    UIButton* _resetButton;
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
    _rt60Label = [[UILabel alloc] initWithFrame:CGRectMake(10, 40, 320-20, 60)];
    _rt60Label.text = @"";
    [self.view addSubview:_rt60Label];

    _backgroundLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 200, 320-20, 60)];
    [self.view addSubview:_backgroundLabel];
    
    _resetButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _resetButton.frame = CGRectMake( 100, 300, 320-200, 80 );
    [_resetButton setTitle:@"reset" forState:UIControlStateNormal];
    [_resetButton addTarget:self 
                     action:@selector(reset) 
           forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_resetButton];
    
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
    _backgroundLabel.text = @"￼Calculating background level...";
    
    [recorder stop];
    [recorder start];
}

#pragma mark - ClapRecorderDelegate methods
-(void)gotMeasurement:(ClapMeasurement *)measurement{
    _rt60Label.text = [NSString stringWithFormat:@"rt60 = %.3f seconds", measurement.reverbTime];
}

-(void)gotBackgroundLevel:(float)decibels{
    _backgroundLabel.text = [NSString stringWithFormat:@"background level is %.0f dB",decibels];
}
@end
