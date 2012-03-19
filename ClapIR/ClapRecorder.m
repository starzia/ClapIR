//
//  ClapRecorder.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/18/12.
//

#import "ClapRecorder.h"

#import "SpectrogramRecorder.h"

@implementation ClapRecorder{
    SpectrogramRecorder* _spectrogramRecorder;
    
    // background energy level, set to the minimum observed
    float _backgroundEnergy;
    
    // are we currently observing a clap
    bool _isClap;
    double _clapStartTime;
    
    // history of energy measurements
    float* _buffer;
    
    // number of spectrograms observed
    long _timeStep;
}
@synthesize delegate;

-(id)init{
    self = [super init];
    if( self ){
        _spectrogramRecorder = [[SpectrogramRecorder alloc] init];
        _spectrogramRecorder.delegate = self;
        
        // TODO: set background level dynamically
        _backgroundEnergy = 177;
        
        // are we currently observing a clap?
        _isClap = NO;
        
        _timeStep = 0;
    }
    return self;
}

-(void)start{
    [_spectrogramRecorder start];
}

#pragma mark - SpectrogramRecorderDelegate
-(void)gotSpectrum:(float *)spec energy:(float)energy{
    _timeStep++;
    NSLog( @"got spectrum with energy: %.0f dB\n", energy );
    
    // detect clap
    double currentTime = _timeStep * _spectrogramRecorder.spectrumTime;
    if( !_isClap && energy > 30+_backgroundEnergy ){
        NSLog( @"Clap begin" );
        _isClap = YES;
        _clapStartTime = currentTime;
    }
    // detect end of clap.
    // We must be in a clap, sufficient time must have elapsed since the start, 
    // and the energy level must be low
    else if( _isClap 
             && currentTime - _clapStartTime > 0.1
             && energy < 3 + _backgroundEnergy ){
        NSLog( @"Clap end" );
        _isClap = NO;
        // trigger calculation
        //...
    }
}

@end
