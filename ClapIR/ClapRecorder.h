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
#import <Accelerate/Accelerate.h> // for vector operations and FFT


/** uses the AVCapture API for sound recording */
@interface ClapRecorder : NSObject <AVCaptureAudioDataOutputSampleBufferDelegate>{
    AVCaptureConnection* _audioConnection;
    
    // signal processing structs
    pthread_mutex_t _lock; // buffer lock
    FFTSetup _fftsetup;
	float* _A __attribute__ ((aligned (16))); // scratch // aligned for SIMD
	float* _hamm __attribute__ ((aligned (16))); // hamming window
	float* _acc __attribute__ ((aligned (16))); // spectrum accumulator
	int _accCount;
	float* _frameBuffer __attribute__ ((aligned (16))); // aligned for SIMD
	int _fbIndex; // index of next space to be filled in the frameBuffer
	int _startIndex; // index of next window to be analyzed
	unsigned int _fbLen; // number of frames (floats) in frameBuffer
	DSPSplitComplex _compl_buf;
}

@property (strong) id<ClapRecorderDelegate> delegate;
@property (strong) AVCaptureSession* captureSession;

/** start recording */
-(void)start;

@end
