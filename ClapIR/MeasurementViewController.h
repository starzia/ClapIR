//
//  MeasurementViewController.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/19/12.
//  Copyright (c) 2012 VaporStream, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ClapRecorder.h"

@interface MeasurementViewController : UIViewController <ClapRecorderDelegate>

@property (strong) ClapRecorder* recorder;

@end
