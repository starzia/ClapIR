//
//  ClapRecorder.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/18/12.
//

#import "ClapRecorder.h"

#import "SpectrogramRecorder.h"
#import <Accelerate/Accelerate.h>

/** calculate slope of line fitting data using simple linear regression.
 Data points are assumed to sampled at a uniform rate.
 ie, the (x,y) data points are (0,curve[0]), (1,curve[1]), ... (size-1,curve[size-1])
 http://en.wikipedia.org/wiki/Simple_linear_regression */
float calcSlope( float* curve, int size );
float calcSlope( float* curve, int size ){
    // calculate means
    float mean_x = (size-1)/2.0;
    float mean_y;
    vDSP_sve( curve, 1, &mean_y, size);
    mean_y /= size;
    
    // TODO: use closed form for \Sum_{0->size} x^2
    float* x_sqrd = malloc( sizeof(float) * size );
    float zero = 0;
    vDSP_vfill( &zero, x_sqrd, 1, size );
    float one = 1;
    vDSP_vramp( x_sqrd, &one, x_sqrd, 1, size ); // generate sequence 0,1,2,3...
    vDSP_vmul( curve, 1, x_sqrd, 1, curve, 1, size ); // x*y sequence
    float mean_xy;
    vDSP_sve( curve, 1, &mean_xy, size );
    mean_xy /= size;
    
    vDSP_vsq( x_sqrd, 1, x_sqrd, 1, size ); // square sequence to get 0,1,4,9...
    float mean_x_sqrd;
    vDSP_sve( x_sqrd, 1, &mean_x_sqrd, size );
    mean_x_sqrd /= size;

    free( x_sqrd );
    
    float covariance_xy = mean_xy - mean_x * mean_y;
    float variance_x = mean_x_sqrd - mean_x * mean_x;
    return covariance_xy / variance_x;
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
        
        // allocate a 5 second circular buffer
        _bufferSize = ceil( 5.0 / _spectrogramRecorder.spectrumTime );
        _buffer = malloc( sizeof(float) * _bufferSize );
        _bufferPtr = 0;
    }
    return self;
}

-(void)dealloc{
    free( _buffer );
}

-(void)start{
    [_spectrogramRecorder start];
}

#pragma mark - SpectrogramRecorderDelegate
-(void)gotSpectrum:(float *)spec energy:(float)energy{
    // store sample in buffer
    ///NSLog( @"got spectrum with energy: %.0f dB\n", energy );
    // TODO: deal with entire spectrum, not just energy
    _buffer[_bufferPtr] = energy;
    
    // increment clap length counter if we are in the middle of a clap
    if( _isClap ) _stepsInClap++;
    
    // detect clap
    if( !_isClap && energy > 40+_backgroundEnergy ){
        NSLog( @"Clap begin" );
        _isClap = YES;
        _stepsInClap = 1;
    
    // detect end of clap.
    // We must be in a clap, sufficient time must have elapsed since the start, 
    // and the energy level must be low
    }else if( _isClap 
             && _stepsInClap * _spectrogramRecorder.spectrumTime > 0.1
             && energy < 3 + _backgroundEnergy ){
        NSLog( @"Clap end" );
        _isClap = NO;
        
        // copy decay curve in preparation for calculation
        float* curve = malloc( sizeof(float) * _stepsInClap );
        for( int i=0; i<_stepsInClap; i++ ){
            curve[i] = _buffer[(_bufferPtr-_stepsInClap+1+i)%_bufferSize];
            printf( "%.0f ", curve[i] );
        }
        printf( "\n" );
        
        // calculate slope of region past direct sound
        float slope = calcSlope( curve, _stepsInClap );
        slope /= _spectrogramRecorder.spectrumTime;
        float rt60 = -60 / slope;
        printf( "Calculated rt60 = %.2f seconds\n", rt60 );
        ClapMeasurement* measurement = [[ClapMeasurement alloc] init];
        measurement.reverbTime = rt60;
        [delegate gotMeasurement:measurement];
        
        free( curve );
    }
    
    // set background level, if this was the first time that the buffer was filled
    if( _bufferPtr == _bufferSize - 1 && isnan( _backgroundEnergy ) ){
        // we take the simple mean of energy levels (though for dB geometric mean makes more sense).
        vDSP_sve( _buffer, 1, &_backgroundEnergy, _bufferSize );
        _backgroundEnergy /= _bufferSize;
        NSLog( @"Background energy level set to %.0f", _backgroundEnergy );
    }
    
    _timeStep++;
    _bufferPtr = (_bufferPtr+1) % _bufferSize; // circular buffer
}

@end
