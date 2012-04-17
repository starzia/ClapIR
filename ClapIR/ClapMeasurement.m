//
//  ClapMeasurement.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/4/12.
//

#import "ClapMeasurement.h"

@implementation ClapMeasurement
@synthesize reverbTime;
@synthesize reverbTimeSpectrum;
@synthesize freqResponseSpectrum;
@synthesize directSoundSpectrum;

float* specFreqArray = nil;

-(id)init{
    self = [super init];
    if(self){
        reverbTimeSpectrum   = malloc( sizeof(float) * ClapMeasurement.numFreqs );
        freqResponseSpectrum = malloc( sizeof(float) * ClapMeasurement.numFreqs );
        directSoundSpectrum  = malloc( sizeof(float) * ClapMeasurement.numFreqs );
    }
    return self;
}

-(void)dealloc{
    free( reverbTimeSpectrum );
    free( freqResponseSpectrum );
    free( directSoundSpectrum );
}

+(int)numFreqs{
    return 40;
}

+(float*)specFrequencies{
    if( specFreqArray == nil ){
        // init array of spectrum frequencies the first time they are required
        specFreqArray = malloc( sizeof(float) * ClapMeasurement.numFreqs );
                         
        double sqrt2 = sqrt(2);
        double sqrtsqrt2 = sqrt(sqrt2);
        double x = 22.09708691207964; // 1000/(sqrt(2)^11)
        for( int i=0; i<ClapMeasurement.numFreqs; i++ ){
            specFreqArray[i] = x;
            x *= sqrtsqrt2;
        }
    }
    return specFreqArray;
}

-(NSString*)description{
    NSMutableString* desc = [NSMutableString string];
    [desc appendFormat:@"overall RT60: %.3f seconds\n\n", reverbTime];
    [desc appendString:@"Frequency,\tReverb,\tResponse,\tDirect sound\n"];
    for( int f=0; f<ClapMeasurement.numFreqs; f++ ){
        [desc appendFormat:@"%.1f Hz\t%.3f s\t%.1f dB\t%.1f dB\t\n", 
         ClapMeasurement.specFrequencies[f], reverbTimeSpectrum[f],
         freqResponseSpectrum[f], directSoundSpectrum[f]];
    }
    return desc;
}
@end
