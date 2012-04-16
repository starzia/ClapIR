//
//  SpectrogramRecorderDelegate.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/18/12.
//

#import <Foundation/Foundation.h>

@protocol SpectrogramRecorderDelegate <NSObject>

/** 
 * spectrum and energy are reported in natural units, NOT decibels.  
 * Use [SpectrogramRecorder spectrumResolution] to determine the length of the spectrum array
 */
-(void)gotSpectrum:(float *)spec energy:(float)energy;

@end
