//
//  SpectrogramRecorderDelegate.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/18/12.
//  Copyright (c) 2012 VaporStream, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SpectrogramRecorderDelegate <NSObject>

/** 
 * spectrum and energy are reported in decibels.  
 * Use [SpectrogramRecorder spectrumResolution] to determine the length of the spectrum array
 */
-(void)gotSpectrum:(float *)spec energy:(float)energy;

@end
