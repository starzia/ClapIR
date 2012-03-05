//
//  ClapRecorderDelegate.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/4/12.
//  Copyright (c) 2012 VaporStream, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ClapMeasurement.h"

@protocol ClapRecorderDelegate <NSObject>

-(void)gotMeasurement:(ClapMeasurement*)measurement;

@end
