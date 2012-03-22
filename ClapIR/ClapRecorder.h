//
//  ClapRecorder.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/18/12.
//

#import <Foundation/Foundation.h>
#import "ClapRecorderDelegate.h"
#import "SpectrogramRecorderDelegate.h"

@interface ClapRecorder : NSObject <SpectrogramRecorderDelegate>

@property (assign) id<ClapRecorderDelegate> delegate;

-(void)stop;
-(void)start;

@end
