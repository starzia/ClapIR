//
//  ClapRecorder.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/18/12.
//

#import "ClapRecorder.h"

#import "SpectrogramRecorder.h"
#import <Accelerate/Accelerate.h>

#define VERBOSE 0

typedef struct{
    float slope;
    float yIntercept;
}Fit;

/** Calculate slope of line fitting data using simple linear regression.
 Data points are assumed to sampled at a uniform rate.
 ie, the (x,y) data points are (0,curve[0]), (1,curve[1]), ... (size-1,curve[size-1])
 http://en.wikipedia.org/wiki/Simple_linear_regression */
Fit regression( float* curve, int size );
Fit regression( float* curve, int size ){
    // calculate means
    float mean_x = (size-1)/2.0;
    float mean_y;
    vDSP_sve( curve, 1, &mean_y, size);
    mean_y /= size;
    
    // TODO: use closed form for \Sum_{0->size} x^2
    // http://en.wikipedia.org/wiki/Faulhaber%27s_formula
    float* x_sqrd = malloc( sizeof(float) * size );
    float* xy = malloc( sizeof(float) * size );
    float zero = 0;
    vDSP_vfill( &zero, x_sqrd, 1, size );
    float one = 1;
    vDSP_vramp( x_sqrd, &one, x_sqrd, 1, size ); // generate sequence 0,1,2,3...
    vDSP_vmul( curve, 1, x_sqrd, 1, xy, 1, size ); // x*y sequence
    float mean_xy;
    vDSP_sve( xy, 1, &mean_xy, size );
    free( xy );
    mean_xy /= size;
    
    vDSP_vsq( x_sqrd, 1, x_sqrd, 1, size ); // square sequence to get 0,1,4,9...
    float mean_x_sqrd;
    vDSP_sve( x_sqrd, 1, &mean_x_sqrd, size );
    mean_x_sqrd /= size;

    free( x_sqrd );
    
    float covariance_xy = mean_xy - mean_x * mean_y;
    float variance_x = mean_x_sqrd - mean_x * mean_x;
    
    Fit fit;
    fit.slope = covariance_xy / variance_x;
    
    // calculate y intercept
    fit.yIntercept = mean_y - fit.slope * mean_x;
    
    return fit;
}

void printVec( const char* description, float* vec, int size );
void printVec( const char* description, float* vec, int size ){
    printf( "%s ", description );
    for( int i=0; i<size; i++ ){
        printf("%.0f ", vec[i]);
    }
    printf("\n");
}

/** Calculate the RMS error of a fit (such as the MMSE fit returned by regression()). */
float rootMeanSqrdError( float* curve, int size, Fit fit );
float rootMeanSqrdError( float* curve, int size, Fit fit ){
    // evalute fit line at x points
    float* fitLine = malloc( sizeof(float) * size );
    vDSP_vfill( &(fit.yIntercept), fitLine, 1, size );
    vDSP_vramp( fitLine, &(fit.slope), fitLine, 1, size );
    
    // calculate difference vector
    vDSP_vsub( fitLine, 1, curve, 1, fitLine, 1, size );
    
    // square to get squared error vector
    vDSP_vsq( fitLine, 1, fitLine, 1, size );
    
    // sum, normalize and take sqrt to get RMS error
    float rmsError;
    vDSP_sve( fitLine, 1, &rmsError, size );
    rmsError /= size;
    rmsError = sqrtf( rmsError );
    
    return rmsError;
}

typedef struct{
    BOOL success;
    Fit fit;
    float normalizedRmsError; // rms error divided by the sample length
    int prefixLength;
}PrefixFitResult;

/**
 Finds the best fit negative-slope line among all prefix sequences of length at least
 $minPrefixLength, using the MMSE/length criterion.
 */
PrefixFitResult regressionWithNegativeSlopeAndKnee( float* curve, int size, int minPrefixLength );
PrefixFitResult regressionWithNegativeSlopeAndKnee( float* curve, int size, int minPrefixLength ){
    
    PrefixFitResult bestResult;
    bestResult.normalizedRmsError = INFINITY;
    
    if( minPrefixLength > size ){
        NSLog( @"regression parameter error" );
        return bestResult;
    }
    
    for( int i=minPrefixLength-1; i<size; i++ ){
        Fit fit_i = regression( curve, i );
        float normalizedRmsError_i = rootMeanSqrdError( curve, i, fit_i ) / i;
        if( normalizedRmsError_i < bestResult.normalizedRmsError && fit_i.slope < 0){
            bestResult.normalizedRmsError = normalizedRmsError_i;
            bestResult.prefixLength = i;
            bestResult.fit = fit_i;
        }
    }
    bestResult.success = (bestResult.fit.slope < 0);
    return bestResult;
}

@implementation ClapRecorder{
    SpectrogramRecorder* _spectrogramRecorder;
    
    // background energy level, set to the minimum observed
    float _backgroundEnergy;
    float* _backgroundSpectrum;
    
    // are we currently observing a clap
    bool _isClap;
    int _stepsInClap; // number of buffers observed for this clap
    bool _ignoringClaps;
    
    // history of energy measurements
    float* _buffer;
    int _bufferSize; // length of _buffer array
    int _bufferPtr; // index where next measurement will be stored
    
    // history of spectra
    float** _specBuffer;
    
    // counter for the number of spectrograms observed
    long _timeStep;
}
@synthesize delegate;

// constants
-(float)directSoundLength{ return 0.01; /* seconds */ }
-(int)directSoundSamples{ return ceil( self.directSoundLength / _spectrogramRecorder.spectrumTime ); }

-(id)init{
    self = [super init];
    if( self ){
        _spectrogramRecorder = [[SpectrogramRecorder alloc] init];
        _spectrogramRecorder.delegate = self;
        
        // set background level after we have observed a full buffer (of presumed silence)
        _backgroundEnergy = NAN;
        _backgroundSpectrum = malloc( sizeof(float) * ClapMeasurement.numFreqs );
        
        // are we currently observing a clap?
        _isClap = NO;
        _ignoringClaps = NO;
        
        _timeStep = 0;
        
        // allocate a 5 second circular buffer for energy measurements
        _bufferSize = ceil( 5.0 / _spectrogramRecorder.spectrumTime );
        _buffer = malloc( sizeof(float) * _bufferSize );
        _bufferPtr = 0;
        
        // allocate a 2D circular buffer for spectra:
        // _specBuffer[freq][time]
        _specBuffer = malloc( sizeof(float*) * ClapMeasurement.numFreqs );
        for( int i=0; i<ClapMeasurement.numFreqs; i++ ){
            _specBuffer[i] = malloc( sizeof(float) * _bufferSize );
        }
    }
    return self;
}

-(void)dealloc{
    _spectrogramRecorder.delegate = nil;
    free( _buffer );
}

-(void)start{
    [_spectrogramRecorder start];
}
-(void)stop{
    [_spectrogramRecorder stop];
    _isClap = NO;
    _backgroundEnergy = NAN;
    _bufferPtr = 0;
}

/** Calculate rt60 from a decay curve.  Returns NAN if no decay curve was found. */
-(float)calcReverb:(float*)curve{
    
    // convert decay curve to decibels for linear fitting
    float* dbCurve = malloc( sizeof(float) * _stepsInClap );
    float reference=1.0f;
    vDSP_vdbcon( curve, 1, &reference, dbCurve, 1, _stepsInClap, 1 ); // 1 for power, not amplitude	
            
    // calculate slope of region past direct sound
    float minPrefixLength = 0.05; // seconds
    int minPrefixSamples = ceil( minPrefixLength / _spectrogramRecorder.spectrumTime );
    
    // test that there is enough energy in curve (ie, that it really decays)
    float directSoundSum;
    vDSP_sve( dbCurve, 1, &directSoundSum, self.directSoundSamples );
    float tailSoundSum;
    vDSP_sve( dbCurve+(_stepsInClap-self.directSoundSamples), 1, &tailSoundSum, self.directSoundSamples );
    // if the decay is less than 10dB, abort by returning NaN
    float decayEstimate = (directSoundSum - tailSoundSum) / self.directSoundSamples;
    if( VERBOSE ) printf( "Decay estimate: %.1f dB\n", decayEstimate );
    if( decayEstimate < 10 ){
        if( VERBOSE ) printf( "Decay estimate too small, returning NaN.\n" );
        return NAN;
    }
    
    // calculate best-fit regression line
    PrefixFitResult regressionResult = regressionWithNegativeSlopeAndKnee(
                                                          dbCurve + self.directSoundSamples - 1,
                                                          _stepsInClap - self.directSoundSamples, 
                                                          minPrefixSamples );
    if( !regressionResult.success ) {
        if( VERBOSE ) printf( "Regression failed, returning NaN.\n" );
        return NAN;
    }
    float slope = regressionResult.fit.slope;
    slope /= _spectrogramRecorder.spectrumTime;
    float rt60 = -60 / slope;
    if( VERBOSE ){
        for( int i=0; i<_stepsInClap; i++ ){
            printf("%.0f ", dbCurve[i] );
        }
        printf( "\n" );
        printf( "Calculated rt60 = %.3f seconds, with knee at sample %d of %d\n", rt60, 
               regressionResult.prefixLength + self.directSoundSamples, _stepsInClap );
        printf( "Normalized RMS error: %f\n\n", regressionResult.normalizedRmsError );

    }    
    free( dbCurve );
    return rt60;
}

-(void)calcDirectSoundSpectrumFromSpectrogram:(float*)curves 
                                       saveTo:(float*)outputVector{
    // for each frequency, calculate average energy in direct sound region
    for( int f=0; f<ClapMeasurement.numFreqs; f++ ){
        float sum;
        vDSP_sve( curves+(f*_stepsInClap), 1, &sum, self.directSoundSamples );
        outputVector[f] = sum / self.directSoundSamples;
    }
    // convert to dB, with minimum at 60 dB below the background energy level
    float reference = _backgroundEnergy / 1000;
    // vDSP_minv( outputVector, 1, &reference, ClapMeasurement.numFreqs );
    vDSP_vdbcon( outputVector, 1, &reference, outputVector, 1, ClapMeasurement.numFreqs, 1 ); // 1 for power, not amplitude	
}

-(void)calcFreqResponseSpectrumFromSpectrogram:(float*)curves
                                   directSound:(float*)directSoundSpectrum
                                        saveTo:(float*)outputVector{
    // for each frequency, calculate average energy in reverberant region
    int reverbSamples = _stepsInClap - self.directSoundSamples;
    for( int f=0; f<ClapMeasurement.numFreqs; f++ ){
        float sum;
        vDSP_sve( curves+(f*_stepsInClap + self.directSoundSamples), 1, 
                  &sum, reverbSamples );
        float reverbAvgEnergy = sum / reverbSamples;
        // freq response is ratio between reverb and direct sound spectra
        outputVector[f] = reverbAvgEnergy / directSoundSpectrum[f];
    }
    // convert to dB, with minimum at 100 dB below the background energy level
    float reference = _backgroundEnergy / 100000;
    // vDSP_minv( outputVector, 1, &reference, ClapMeasurement.numFreqs );
    vDSP_vdbcon( outputVector, 1, &reference, outputVector, 1, ClapMeasurement.numFreqs, 1 ); // 1 for power, not amplitude	
}

#pragma mark - SpectrogramRecorderDelegate
-(void)gotSpectrum:(float *)spec energy:(float)energy{
  @synchronized(self){
    // store sample in buffer
    {
        // store energy
        _buffer[_bufferPtr] = energy;
        // store spectrum
        {
            // pick out each of the frequencies of interest from the spectrum
            for( int i=0; i<ClapMeasurement.numFreqs; i++ ){
                int specIdx = floor( ( ClapMeasurement.specFrequencies[i] / ( _spectrogramRecorder.sampleRate * 0.5 ) ) 
                                    * _spectrogramRecorder.spectrumResolution );
                _specBuffer[i][_bufferPtr] = spec[specIdx];
            }
        }
    }
    
    // increment clap length counter if we are in the middle of a clap
    if( _isClap ) _stepsInClap++;
    
    // detect clap
    if( !_ignoringClaps && !_isClap
       && energy > 100 * _backgroundEnergy ){ // 100x or 40dB above bg level
        if( VERBOSE ) NSLog( @"Clap begin" );
        _isClap = YES;
        _stepsInClap = 1;
    
    // detect end of clap
    // We must be in a clap, sufficient time must have elapsed since the start, 
    // and the energy level must be low
    }else if( _isClap 
             && _stepsInClap * _spectrogramRecorder.spectrumTime > 0.1
             && energy < 2 * _backgroundEnergy ){ // 2x or 3dB above bg level
        if( VERBOSE ) NSLog( @"Clap end" );
        _isClap = NO;
        
        // don't allow another clap to be detected immediately
        _ignoringClaps = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^(){
            self->_ignoringClaps = NO;
        });

        // copy decay curves in preparation for calculation
        // buffer will store all frequencies decay curves plus the energy decay curve
        float* curve = malloc( sizeof(float) * _stepsInClap );
        float* curves = malloc( sizeof(float) * _stepsInClap * ClapMeasurement.numFreqs );
        for( int t=0; t<_stepsInClap; t++ ){
            int bufIdx = (_bufferPtr+1-_stepsInClap+t+_bufferSize)%_bufferSize;
            if( VERBOSE ) printf( "t=%d bufIdx=%d, ", t, bufIdx );
            
            curve[t] = _buffer[ bufIdx ];
            for( int f=0; f<ClapMeasurement.numFreqs; f++ ){
                curves[ f*_stepsInClap + t ] = _specBuffer[ f ][ bufIdx ];
            }
        }
        if( VERBOSE ){
            printf( "\n" );
        
            // print spectrogram for debugging
            printf( "\nSPECTROGRAM\n" );
            for( int f=0; f<ClapMeasurement.numFreqs; f++ ){
                printf( "%.2e Hz\t", ClapMeasurement.specFrequencies[f] );
                for( int t=0; t<_stepsInClap; t++ ){
                    printf( "%.0f\t", curves[ f*_stepsInClap + t ] );
                }
                printf( "\n" );
            }
            printf( "\n" );
        }
        
        // calculate reverb times
        ClapMeasurement* measurement = [[ClapMeasurement alloc] init];
        measurement.reverbTime = [self calcReverb:curve];
        for( int i=0; i<ClapMeasurement.numFreqs; i++ ){
            // Initial energy in this frequency must be at least 20dB (10x) above the background level
            if ((curves+i*_stepsInClap)[0] < 10 * _backgroundSpectrum[i]) {
                if (VERBOSE) printf( "Skipping freq %.2e Hz due to low level\n", ClapMeasurement.specFrequencies[i]);
                measurement.reverbTimeSpectrum[i] = NAN;
            } else {
                measurement.reverbTimeSpectrum[i] = [self calcReverb:(curves+i*_stepsInClap)];
            }
        }
        // calculate direct sound spectrum
        [self calcDirectSoundSpectrumFromSpectrogram:curves 
                                              saveTo:measurement.directSoundSpectrum];
        // calculate frequency response
        [self calcFreqResponseSpectrumFromSpectrogram:curves
                                          directSound:measurement.directSoundSpectrum
                                               saveTo:measurement.freqResponseSpectrum];
        free( curve );
        free( curves );
        
        [delegate gotMeasurement:measurement];
    }
    
    // set background level, if this was the first time that the buffer was filled
    if( _bufferPtr == _bufferSize - 1 && isnan( _backgroundEnergy ) ){
        // we take the simple mean of energy levels.
        vDSP_sve( _buffer, 1, &_backgroundEnergy, _bufferSize );
        _backgroundEnergy /= _bufferSize;
        NSLog( @"Background energy level set to %.0f", _backgroundEnergy );
        [delegate gotBackgroundLevel:_backgroundEnergy];

        // also save background spectrum by calculating the average of the buffer data
        printf( "Background spectrum:\n" );
        for( int i=0; i<ClapMeasurement.numFreqs; i++ ){
            vDSP_sve( _specBuffer[i], 1, &_backgroundSpectrum[i], _bufferSize );
            _backgroundSpectrum[i] /= _bufferSize;
            printf( "%.2e Hz: ", ClapMeasurement.specFrequencies[i] );
            printf( "%.0f\t", _backgroundSpectrum[i] );
        }
        printf( "\n" );
    }
    
    _timeStep++;
    _bufferPtr = (_bufferPtr+1) % _bufferSize; // circular buffer
  }
}

@end
