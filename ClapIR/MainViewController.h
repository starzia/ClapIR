//
//  MainViewController.h
//  ClapIR
//
//  Created by Stephen Tarzia on 4/14/12.
//  Copyright (c) 2012 VaporStream, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ClapRecorder.h"

@interface MainViewController : UIViewController <ClapRecorderDelegate>

@property (strong,nonatomic) IBOutlet UIBarButtonItem* pauseButton;
@property (strong,nonatomic) IBOutlet UIBarButtonItem* undoButton;
@property (strong,nonatomic) IBOutlet UIBarButtonItem* pageCurlButton;
@property (strong,nonatomic) IBOutlet UISegmentedControl* toggleControl;
@property (strong,nonatomic) IBOutlet UIView* reverbView;
@property (strong,nonatomic) IBOutlet UIView* reverbPlotView;
@property (strong,nonatomic) IBOutlet UIView* spectraView;
@property (strong,nonatomic) IBOutlet UIView* directSoundPlotView;
@property (strong,nonatomic) IBOutlet UIView* freqResponsePlotView;

@property (strong) ClapRecorder* recorder;

@end
