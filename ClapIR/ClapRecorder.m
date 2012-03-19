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
        _spectrogramRecorder.delegate = self;
    }
    return self;
}

-(void)start{
    [_spectrogramRecorder start];
}

#pragma mark - SpectrogramRecorderDelegate
-(void)gotSpectrum:(float *)spec energy:(float)energy{
    printf("got spectrum with energy: %.0f dB\n", energy );
}

@end
