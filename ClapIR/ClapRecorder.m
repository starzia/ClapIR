//
//  ClapRecorder.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/18/12.
//

#import "ClapRecorder.h"

#import "SpectrogramRecorder.h"
#import <Accelerate/Accelerate.h>

typedef struct{
    float slope;
    float yIntercept;
}Fit;

/** calculate slope of line fitting data using simple linear regression.
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

/** calculate the RMS error of a fit (such as the MMSE fit returned by regression() */
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
    Fit fit;
    float normalizedRmsError; // rms error divided by the sample length
    int prefixLength;
}PrefixFitResult;

/**
 Finds the best fit slope line among all prefix sequences of length at least
 $minPrefixLength, using the MMSE/length criterion.
 */
PrefixFitResult regressionAndKnee( float* curve, int size, int minPrefixLength );
PrefixFitResult regressionAndKnee( float* curve, int size, int minPrefixLength ){
    
    PrefixFitResult bestResult;
    bestResult.normalizedRmsError = INFINITY;
    
    if( minPrefixLength > size ){
        NSLog( @"regression parameter error" );
        return bestResult;
    }
    
    for( int i=minPrefixLength-1; i<size; i++ ){
        Fit fit_i = regression( curve, i );
        float normalizedRmsError_i = rootMeanSqrdError( curve, i, fit_i ) / i;
        if( normalizedRmsError_i < bestResult.normalizedRmsError ){
            bestResult.normalizedRmsError = normalizedRmsError_i;
            bestResult.prefixLength = i;
            bestResult.fit = fit_i;
        }
    }
    return bestResult;
}

@implementation ClapRecorder{
    SpectrogramRecorder* _spectrogramRecorder;
    
    // background energy level, set to the minimum observed
    float _backgroundEnergy;
    
    // are we currently observing a clap
    bool _isClap;
    int _stepsInClap; // number of buffers observed for this clap
    
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

-(id)init{
    self = [super init];
    if( self ){
        _spectrogramRecorder = [[SpectrogramRecorder alloc] init];
        _spectrogramRecorder.delegate = self;
        
        // set background level after we have observed a full buffer (of presumed silence)
        _backgroundEnergy = NAN;
        
        // are we currently observing a clap?
        _isClap = NO;
        
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

/** calculate rt60 from a decay curve */
-(float)calcReverb:(float*)curve{
            
    // calculate slope of region past direct sound (one sample offset)
    float directSoundLength = 0.01; // seconds
    float minPrefixLength = 0.05; // seconds
    int directSoundSamples = ceil( directSoundLength / _spectrogramRecorder.spectrumTime );
    int minPrefixSamples = ceil( minPrefixLength / _spectrogramRecorder.spectrumTime );
    
    // test that there is enough energy in curve (ie, that it really decays)
    float directSoundSum;
    vDSP_sve( curve, 1, &directSoundSum, directSoundSamples );
    float tailSoundSum;
    vDSP_sve( curve+(_stepsInClap-directSoundSamples), 1, &tailSoundSum, directSoundSamples );
    // if the decay is less than 10dB, abort by returning NaN
    float decayEstimate = (directSoundSum - tailSoundSum)/directSoundSamples;
    printf( "Decay estimate: %.1f dB\n", decayEstimate );
    if( decayEstimate < 10 ){
        return NAN;
    }
    
    // calculate best-fit regression line
    PrefixFitResult regressionResult = regressionAndKnee( curve+directSoundSamples-1, 
                                                          _stepsInClap-directSoundSamples, 
                                                          minPrefixSamples );
    float slope = regressionResult.fit.slope;
    slope /= _spectrogramRecorder.spectrumTime;
    float rt60 = -60 / slope;
    for( int i=0; i<_stepsInClap; i++ ){
        printf("%.0f ", curve[i] );
    }
    printf( "\n" );
    printf( "Calculated rt60 = %.3f seconds, with knee at sample %d of %d\n", rt60, 
            regressionResult.prefixLength+directSoundSamples, _stepsInClap );
    
    return rt60;
}

#pragma mark - SpectrogramRecorderDelegate
-(void)gotSpectrum:(float *)spec energy:(float)energy{
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
    if( !_isClap && energy > 40+_backgroundEnergy ){
        NSLog( @"Clap begin" );
        _isClap = YES;
        _stepsInClap = 1;
    
    // detect end of clap
    // We must be in a clap, sufficient time must have elapsed since the start, 
    // and the energy level must be low
    }else if( _isClap 
             && _stepsInClap * _spectrogramRecorder.spectrumTime > 0.1
             && energy < 3 + _backgroundEnergy ){
        NSLog( @"Clap end" );
        _isClap = NO;
        
        // copy decay curves in preparation for calculation
        // buffer will store all frequencies decay curves plus the energy decay curve
        float* curve = malloc( sizeof(float) * _stepsInClap );
        float* curves = malloc( sizeof(float) * _stepsInClap * ClapMeasurement.numFreqs );
        for( int i=0; i<_stepsInClap; i++ ){
            int bufIdx = (_bufferPtr-_stepsInClap+1+i)%_bufferSize;
            curve[i] = _buffer[ bufIdx ];
            for( int j=0; j<ClapMeasurement.numFreqs; j++ ){
                curves[ j*_stepsInClap + i ] = _specBuffer[ j ][ bufIdx ];
            }
        }
        
        // calculate reverb times
        ClapMeasurement* measurement = [[ClapMeasurement alloc] init];
        measurement.reverbTime = [self calcReverb:curve];
        for( int i=0; i<ClapMeasurement.numFreqs; i++ ){
            measurement.reverbTimeSpectrum[i] = [self calcReverb:(curves+i*_stepsInClap)];
        }
        free( curve );
        free( curves );
        
        for( int i=0; i<ClapMeasurement.numFreqs; i++ ){
            measurement.reverbTimeSpectrum[i] = [self calcReverb:_specBuffer[i]];
        }
        
        [delegate gotMeasurement:measurement];
    }
    
    // set background level, if this was the first time that the buffer was filled
    if( _bufferPtr == _bufferSize - 1 && isnan( _backgroundEnergy ) ){
        // we take the simple mean of energy levels (though for dB geometric mean makes more sense).
        vDSP_sve( _buffer, 1, &_backgroundEnergy, _bufferSize );
        _backgroundEnergy /= _bufferSize;
        NSLog( @"Background energy level set to %.0f", _backgroundEnergy );
        [delegate gotBackgroundLevel:_backgroundEnergy];
    }
    
    _timeStep++;
    _bufferPtr = (_bufferPtr+1) % _bufferSize; // circular buffer
}

@end
