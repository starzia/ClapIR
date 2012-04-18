//
//  ClapMeasurement.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/4/12.
//

#import <Foundation/Foundation.h>

@interface ClapMeasurement : NSObject
// reverb times are in seconds
@property float reverbTime;
@property float* reverbTimeSpectrum;
// power spectra are in dB
@property float* freqResponseSpectrum;
@property float* directSoundSpectrum;

/** nubmer of samples which have been averaged */
@property int sampleCount;

/** number of frequencies in spectra */
+(int)numFreqs;
/** @return array of length [ClapMeasurement numFreqs] specifying the frequencies in spectra, reported in Hertz */
+(float*)specFrequencies;

+(ClapMeasurement*)averageOfMeasurementsInArray:(NSArray*)measurements;

/** adds a given sample to this measurement, incrementing the sampleCount and re-averaging the values. Ignore NaN values.*/
-(void)addSample:(ClapMeasurement*)anotherMeasurement;
/** undo addSample */
-(void)removeSample:(ClapMeasurement*)another;

/** set values to zero and sets sampleCount=0 (so addSample can be used to set value subsequently) */
-(void)clear;
@end
