//
//  ClapRecorder.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/4/12.
//  Copyright (c) 2012 VaporStream, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "ClapRecorderDelegate.h"

/** uses the AVCapture API for sound recording */
@interface ClapRecorder : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>

@property (strong) id<ClapRecorderDelegate> delegate;

/** start recording */
-(void)start;

@end
