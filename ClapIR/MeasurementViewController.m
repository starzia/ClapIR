//
//  MeasurementViewController.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/19/12.
//

#import "MeasurementViewController.h"

@interface MeasurementViewController (){
    UILabel* _label;
}

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
    _label = [[UILabel alloc] initWithFrame:CGRectMake(10, 40, 320-20, 300)];
    _label.textColor = [UIColor blackColor];
    _label.text = @"Calculating background level...";
    [self.view addSubview:_label];
    
    // set up audio
    recorder = [[ClapRecorder alloc] init];
    recorder.delegate = self;
    [recorder start];
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

#pragma mark - ClapRecorderDelegate methods
-(void)gotMeasurement:(ClapMeasurement *)measurement{
    _label.text = [NSString stringWithFormat:@"rt60 = %.3f seconds", measurement.reverbTime];
}

@end
