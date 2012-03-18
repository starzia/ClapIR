//
//  ClapRecorder.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/18/12.
//  Copyright (c) 2012 VaporStream, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ClapRecorderDelegate.h"
#import "SpectrogramRecorderDelegate.h"

@interface ClapRecorder : NSObject <SpectrogramRecorderDelegate>

@property (assign) id<ClapRecorderDelegate> delegate;

-(void)start;

@end
