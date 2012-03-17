//
//  ClapRecorder.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/4/12.
//  Copyright (c) 2012 VaporStream, Inc. All rights reserved.
//

#import "ClapRecorder.h"

@implementation ClapRecorder
@synthesize delegate;
@synthesize captureSession;

const int FRAME_SIZE = 2048;
const int SPEC_RES = 1024;
const int SAMPLE_RATE = 44100;
const int ACC_NUM = 10; // number of frames in welch's method

-(id)init{
    self = [super init];
    if( self ){
        // init signal processing data
        {
            // first, collect all the data pointers the callback function will need
            UInt32 log2FFTLength = log2f( SPEC_RES );
            _fftsetup = vDSP_create_fftsetup( log2FFTLength, kFFTRadix2 ); // this only needs to be created once
            // initialize lock
            if( pthread_mutex_init( &_lock, NULL ) ) printf( "mutex init failed!\n" );
            // allocate buffers for signal processing
            _A = malloc( sizeof(float) * 2*SPEC_RES );
            _accCount=0;
            _acc = malloc( sizeof(float) * SPEC_RES );
            float zero=0.0f;
            vDSP_vfill( &zero, _acc, 1, SPEC_RES );
            // generate Hamming window
            _hamm = malloc( sizeof(float) * SPEC_RES );
            vDSP_hamm_window( _hamm, SPEC_RES, 0 );
            _fbLen = 0.5*SAMPLE_RATE; // just pick a large value for now.
            _frameBuffer = malloc( sizeof(float) * _fbLen );
            _compl_buf.realp = malloc( sizeof(float) * SPEC_RES );
            _compl_buf.imagp = malloc( sizeof(float) * SPEC_RES );
            _fbIndex = 0;
            _startIndex = 0;
        }
    }
    return self;
}

-(void)dealloc{
    free( _acc );
    pthread_mutex_destroy(&_lock);
}

-(void)start{
    // create an AV Capture session
    self.captureSession = [[AVCaptureSession alloc] init];
    
    
    // setup the audio input
	AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
	if(audioDevice) {
		
		NSError *error;
		AVCaptureDeviceInput *audioIn = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
		if ( !error ) {
			if ([self.captureSession canAddInput:audioIn]){
				[self.captureSession addInput:audioIn];
			}else{
				NSLog(@"Couldn't add audio input");
            }
		}else{
			NSLog(@"Couldn't create audio input");
        }
	}else{
		NSLog(@"Couldn't create audio capture device");
    }

    // setup the audio output
    AVCaptureAudioDataOutput* audioOut = [[AVCaptureAudioDataOutput alloc] init];
    [captureSession addOutput:audioOut];
    
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    
    if ([self.captureSession canAddOutput:audioOut]) {
		[self.captureSession addOutput:audioOut];
		_audioConnection = [audioOut connectionWithMediaType:AVMediaTypeAudio];
	}else{
		NSLog(@"Couldn't add audio output");
    }
    [audioOut setSampleBufferDelegate:self queue:queue];
    dispatch_release(queue);
        
    // start audio
    [captureSession startRunning];
}

#pragma mark - AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
       fromConnection:(AVCaptureConnection *)connection{
        
    // check format of audio
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    const AudioStreamBasicDescription *streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    #pragma unused( streamDescription )
    
    // get samples
    CMItemCount numSamples = CMSampleBufferGetNumSamples(sampleBuffer);
    NSLog( @"got %lu samples of audio", numSamples );
	NSUInteger channelIndex = 0;
    
	CMBlockBufferRef audioBlockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
	size_t audioBlockBufferOffset = (channelIndex * numSamples * sizeof(SInt16));
	size_t lengthAtOffset = 0;
	size_t numBlockSamples = 0; // I think this is the same as $numSamples above, since it's mono
	SInt16 *samples = NULL;
	CMBlockBufferGetDataPointer(audioBlockBuffer, audioBlockBufferOffset, &lengthAtOffset, &numBlockSamples, (char **)(&samples));
    
    // buffer samples
    int windowSamples = SPEC_RES; // the number of samples to include in each FFT
    {
        // If there is no space left in the buffer for the current frame, 
        // left-shift the right-half of the buffer to overwrite the old data.
        // After the new data is added there will be enough data left to
        // build a full window.  Also, there will not be a full window of old data.
        if( _fbIndex >= _fbLen - numSamples ){
            // left-shift right half of buffer
            memcpy(_frameBuffer + _fbLen/2, _frameBuffer, sizeof(float)*_fbLen/2);
            // adjust buffer index to reflect shift
            _fbIndex -= _fbLen/2;
            _startIndex -= _fbLen/2;
        }
        
        // convert 16-bit integers to floats, while copying into frameBuffer
        vDSP_vflt16( samples, 1, _frameBuffer + _fbIndex, 1, numSamples );		
        
        
        // increment frame buffer index
        _fbIndex += numSamples;
        
        // if we don't yet have sufficient data, just return.
        if( _fbIndex < windowSamples ) return;
    }
    
    // compute FFT for this frame
    {
        // setup FFT
        UInt32 log2FFTLength = log2f( SPEC_RES );
        
        // apply Hamming window
        vDSP_vmul(_A, 1, _hamm, 1, _A, 1, SPEC_RES); //apply
        
        // take fft 	
        // ctoz and ztoc are needed to convert from "split" and "interleaved" complex formats
        // see vDSP documentation for details.
        vDSP_ctoz((COMPLEX*) _A, 2, &(_compl_buf), 1, SPEC_RES);
        vDSP_fft_zip( _fftsetup, &(_compl_buf), 1, log2FFTLength, kFFTDirection_Forward );
        ///vDSP_ztoc(&compl_buf, 1, (COMPLEX*) A, 2, inNumberFrames/2); // convert back
        
        // use vDSP_zaspec to get power spectrum
        vDSP_zaspec( &(_compl_buf), _A, SPEC_RES );
        
        // accumulate this FFT vector for welch's algorithm
        vDSP_vadd(_A, 1, _acc, 1, _acc, 1, SPEC_RES);
    
        if ( ++_accCount >= ACC_NUM ){
            if( pthread_mutex_lock( &_lock ) ) printf( "lock failed!\n" );
            
            // convert to dB
            float reference=1.0f * ACC_NUM; //divide by number of summed spectra
            vDSP_vdbcon( _acc, 1, &reference, _acc, 1, SPEC_RES, 1 ); // 1 for power, not amplitude	
            
            // clear accumulator
			float zerof=0.0f;
			vDSP_vfill( &zerof, _acc, 1, SPEC_RES );
            _accCount = 0;
        }
    }
}

@end
