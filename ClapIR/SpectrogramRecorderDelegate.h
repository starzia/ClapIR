//
//  SpectrogramRecorderDelegate.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/18/12.
//  Copyright (c) 2012 VaporStream, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SpectrogramRecorderDelegate <NSObject>

-(void)gotSpectrum:(float*)spec ofLength:(int)length;

@end
