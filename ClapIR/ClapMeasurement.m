//
//  ClapMeasurement.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/4/12.
//

#import "ClapMeasurement.h"
#import <Accelerate/Accelerate.h>

@implementation ClapMeasurement
@synthesize reverbTime;
@synthesize reverbTimeSpectrum;
@synthesize freqResponseSpectrum;
@synthesize directSoundSpectrum;
@synthesize sampleCount;

float* specFreqArray = nil;

-(id)init{
    self = [super init];
    if(self){
        reverbTimeSpectrum   = malloc( sizeof(float) * ClapMeasurement.numFreqs );
        freqResponseSpectrum = malloc( sizeof(float) * ClapMeasurement.numFreqs );
        directSoundSpectrum  = malloc( sizeof(float) * ClapMeasurement.numFreqs );
        sampleCount = 1; // by default, measurement is for only one sample (no averaging)
    }
    return self;
}

-(void)dealloc{
    free( reverbTimeSpectrum );
    free( freqResponseSpectrum );
    free( directSoundSpectrum );
}

// standard 1/3 octave bands
// see: https://www.engineeringtoolbox.com/octave-bands-frequency-limits-d_1602.html
static const float freqs[33] = {12.5, 16, 20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160, 200, 250,
    315, 400, 500, 630, 800, 1000, 1250, 1600, 2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000,
    12500, 16000, 20000};

+(int)numFreqs{
    return 33;
}

+(const float*)specFrequencies{
    return freqs;
}

-(NSString*)description{
    NSMutableString* desc = [NSMutableString string];
    if( sampleCount > 1 ){
        [desc appendFormat:@"Average from %d samples:\n\n", sampleCount ];
    }
    [desc appendFormat:@"Overall reverb RT60: %.3f seconds\n\n", reverbTime];
    [desc appendString:@"Frequency,\tReverb,\tResponse,\tDirect sound\n"];
    for( int f=0; f<ClapMeasurement.numFreqs; f++ ){
        [desc appendFormat:@"%.1f Hz\t%.3f s\t%.1f dB\t%.1f dB\t\n", 
         ClapMeasurement.specFrequencies[f], reverbTimeSpectrum[f],
         freqResponseSpectrum[f], directSoundSpectrum[f]];
    }
    return desc;
}

+(ClapMeasurement*)averageOfMeasurementsInArray:(NSArray*)measurements{
    if( !measurements ) return nil;
    
    ClapMeasurement* avg = [[ClapMeasurement alloc] init];
    // sum up values
    for( ClapMeasurement* measurement in measurements ){
        avg.reverbTime += measurement.reverbTime;
        vDSP_vadd( measurement.reverbTimeSpectrum, 1, avg.reverbTimeSpectrum, 1, 
                   avg.reverbTimeSpectrum, 1, ClapMeasurement.numFreqs );
        // !!!: we are using standard mean on log-scaled units (decibels)
        vDSP_vadd( measurement.freqResponseSpectrum, 1, avg.freqResponseSpectrum, 1, 
                  avg.freqResponseSpectrum, 1, ClapMeasurement.numFreqs );
        vDSP_vadd( measurement.directSoundSpectrum, 1, avg.directSoundSpectrum, 1, 
                   avg.directSoundSpectrum, 1, ClapMeasurement.numFreqs );
    }
    // divide by number of values
    float count = measurements.count;
    avg.reverbTime /= measurements.count;
    vDSP_vsdiv( avg.reverbTimeSpectrum, 1, &count, avg.reverbTimeSpectrum, 1,
                ClapMeasurement.numFreqs );
    vDSP_vsdiv( avg.freqResponseSpectrum, 1, &count, avg.freqResponseSpectrum, 1,
                ClapMeasurement.numFreqs );
    vDSP_vsdiv( avg.directSoundSpectrum, 1, &count, avg.directSoundSpectrum, 1,
                ClapMeasurement.numFreqs );
    return avg;
}

-(void)clear{
    sampleCount = 0;
    reverbTime = 0;
    vDSP_vclr( reverbTimeSpectrum,   1, ClapMeasurement.numFreqs );
    vDSP_vclr( directSoundSpectrum,  1, ClapMeasurement.numFreqs );
    vDSP_vclr( freqResponseSpectrum, 1, ClapMeasurement.numFreqs );
}
-(void)addSample:(ClapMeasurement*)another{
    sampleCount++;
    float oldWeight = ((float)(sampleCount-1))/sampleCount;
    float newWeight = ((float)1)/sampleCount;
    // perform weighted averaging
    reverbTime = oldWeight * reverbTime + newWeight * another.reverbTime;
    for( int f=0; f<ClapMeasurement.numFreqs; f++ ){
        if( isfinite( another.reverbTimeSpectrum[f] ) ){ 
            reverbTimeSpectrum[f] = oldWeight * reverbTimeSpectrum[f] 
                + newWeight * another.reverbTimeSpectrum[f];
        }
        // !!!: we are using standard mean on log-scaled units (decibels)
        if( isfinite( another.freqResponseSpectrum[f] ) ){
            freqResponseSpectrum[f] = oldWeight * freqResponseSpectrum[f] 
                + newWeight * another.freqResponseSpectrum[f];
        }
        if( isfinite( another.directSoundSpectrum[f] ) ){
            directSoundSpectrum[f] = oldWeight * directSoundSpectrum[f] 
                + newWeight * another.directSoundSpectrum[f];
        }
    }
}

-(void)removeSample:(ClapMeasurement*)another{
    if( sampleCount == 1 ){
        [self clear];
        return;
    }
    float oldWeight = (sampleCount-1.0)/sampleCount;
    float newWeight = 1.0/sampleCount;
    // reverse the weighted averaging
    reverbTime = ( reverbTime - newWeight * another.reverbTime ) / oldWeight;
    for( int f=0; f<ClapMeasurement.numFreqs; f++ ){
        if( isfinite( another.reverbTimeSpectrum[f] ) ){ 
            reverbTimeSpectrum[f] = ( reverbTimeSpectrum[f] - newWeight * another.reverbTimeSpectrum[f] ) / oldWeight;
        }
        // !!!: we are using standard mean on log-scaled units (decibels)
        if( isfinite( another.freqResponseSpectrum[f] ) ){
            directSoundSpectrum[f] = ( directSoundSpectrum[f] - newWeight * another.directSoundSpectrum[f] ) / oldWeight;
        }
        if( isfinite( another.directSoundSpectrum[f] ) ){
            freqResponseSpectrum[f] = ( freqResponseSpectrum[f] - newWeight * another.freqResponseSpectrum[f] ) / oldWeight;
        }
    }
    sampleCount--;
}

@end
