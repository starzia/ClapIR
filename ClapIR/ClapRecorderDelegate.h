//
//  ClapRecorderDelegate.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/4/12.
//

#import <Foundation/Foundation.h>
#import "ClapMeasurement.h"

@protocol ClapRecorderDelegate <NSObject>

-(void)gotMeasurement:(ClapMeasurement*)measurement;
-(void)gotBackgroundLevel:(float)decibels;

@end
