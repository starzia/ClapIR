//
//  ClapRecorder.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/18/12.
//  Copyright (c) 2012 VaporStream, Inc. All rights reserved.
//

#import "ClapRecorder.h"

#import "SpectrogramRecorder.h"

@implementation ClapRecorder{
    SpectrogramRecorder* _spectrogramRecorder;
}
@synthesize delegate;

-(id)init{
    self = [super init];
    if( self ){
        _spectrogramRecorder = [[SpectrogramRecorder alloc] init];
    }
    return self;
}

-(void)start{
    [_spectrogramRecorder start];
}

#pragma mark - SpectrogramRecorderDelegate
-(void)gotSpectrum:(float *)spec ofLength:(int)length{
    printf("got spectrogram: ");
    for( int i=0; i<length; i++ ){
        printf( "%.0f ", spec[i] );
    }
    printf( "\n" );
}

@end
