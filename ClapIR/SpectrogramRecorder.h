//
//  ClapRecorder.h
//  ClapIR
//
//  Created by Stephen Tarzia on 3/4/12.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "SpectrogramRecorderDelegate.h"
#import <Accelerate/Accelerate.h> // for vector operations and FFT


/** uses the AVCapture API for sound recording */
@interface SpectrogramRecorder : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>

@property (assign) id<SpectrogramRecorderDelegate> delegate;

/** start recording */
-(void)start;

/** recorder properties */
-(int)sampleRate;
-(int)spectrumResolution;
/** time between spectrogram calculataions, in seconds */
-(float)spectrumTime;

@end
