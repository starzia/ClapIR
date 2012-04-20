//
//  MainViewController.h
//  ClapIR
//
//  Created by Stephen Tarzia on 4/14/12.
//

#import <UIKit/UIKit.h>
#import "ClapRecorder.h"

// for email
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

@interface MainViewController : UIViewController <ClapRecorderDelegate, 
    UIActionSheetDelegate, MFMailComposeViewControllerDelegate>

@property (strong,nonatomic) IBOutlet UIToolbar* toolbar;

@property (strong,nonatomic) IBOutlet UIBarButtonItem* pauseButton;
@property (strong,nonatomic) IBOutlet UIBarButtonItem* undoButton;
@property (strong,nonatomic) IBOutlet UIBarButtonItem* optionsButton;
@property (strong,nonatomic) IBOutlet UISegmentedControl* toggleControl;

@property (strong,nonatomic) IBOutlet UIView* reverbView;
@property (strong,nonatomic) IBOutlet UIView* spectraView;
@property (strong,nonatomic) IBOutlet UILabel* instructions;

@property (strong,nonatomic) IBOutlet UIView* reverbPlotView;
@property (strong,nonatomic) IBOutlet UIView* directSoundPlotView;
@property (strong,nonatomic) IBOutlet UIView* freqResponsePlotView;

@property (strong) ClapRecorder* recorder;

@property (strong) ClapMeasurement* avgMeasurement;

-(IBAction)options;
-(IBAction)togglePause;
-(void)setPaused:(BOOL)paused;

@end
