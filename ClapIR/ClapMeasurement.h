//
//  ClapMeasurement.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/4/12.
//

#import <Foundation/Foundation.h>

@interface ClapMeasurement : NSObject
@property float reverbTime;
@property float* reverbTimeSpectrum;
@property float* powerSpectrum;

/** number of frequencies in spectra */
+(int)numFreqs;
/** @return array of length [ClapMeasurement numFreqs] specifying the frequencies in spectra, reported in Hertz */
+(float*)specFrequencies;
@end
