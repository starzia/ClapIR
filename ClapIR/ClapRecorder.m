//
//  ClapRecorder.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/18/12.
//

#import "ClapRecorder.h"

#import "SpectrogramRecorder.h"
#import <Accelerate/Accelerate.h>

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
        // trigger calculation
        //...
        
        // print decay curve
        for( int i=0; i<_stepsInClap; i++ ){
            printf( "%.0f ", _buffer[(_bufferPtr-_stepsInClap+1+i)%_bufferSize] );
        }
        printf( "\n" );
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
