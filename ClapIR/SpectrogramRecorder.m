//
//  ClapRecorder.m
//  ClapIR
//
//  Created by Stephen Tarzia on 3/4/12.
//  Copyright (c) 2012 VaporStream, Inc. All rights reserved.
//

#import "SpectrogramRecorder.h"

@implementation SpectrogramRecorder{
    AVCaptureSession* _captureSession;
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

@synthesize delegate;

#pragma mark - constants

-(int)spectrumResolution{ return 1024; }

-(int)sampleRate{ return 44100; }

-(float)spectrumTime{ return 0.01; }

const int ACC_NUM = 10; // number of frames in welch's method

#pragma mark -
-(id)init{
    self = [super init];
    if( self ){
        // init signal processing data
        {
            // first, collect all the data pointers the callback function will need
            UInt32 log2FFTLength = log2f( self.spectrumResolution );
            _fftsetup = vDSP_create_fftsetup( log2FFTLength, kFFTRadix2 ); // this only needs to be created once
            // initialize lock
            if( pthread_mutex_init( &_lock, NULL ) ) printf( "mutex init failed!\n" );
            // allocate buffers for signal processing
            _A = malloc( sizeof(float) * 2*self.spectrumResolution );
            _accCount=0;
            _acc = malloc( sizeof(float) * self.spectrumResolution );
            float zero=0.0f;
            vDSP_vfill( &zero, _acc, 1, self.spectrumResolution );
            // generate Hamming window
            _hamm = malloc( sizeof(float) * self.spectrumResolution );
            vDSP_hamm_window( _hamm, self.spectrumResolution, 0 );
            _fbLen = 0.5*self.sampleRate; // just pick a large value for now.
            _frameBuffer = malloc( sizeof(float) * _fbLen );
            _compl_buf.realp = malloc( sizeof(float) * self.spectrumResolution );
            _compl_buf.imagp = malloc( sizeof(float) * self.spectrumResolution );
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
    _captureSession = [[AVCaptureSession alloc] init];
    
    
    // setup the audio input
	AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
	if(audioDevice) {
		
		NSError *error;
		AVCaptureDeviceInput *audioIn = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
		if ( !error ) {
			if ([_captureSession canAddInput:audioIn]){
				[_captureSession addInput:audioIn];
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
    [_captureSession addOutput:audioOut];
    
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    
    if ([_captureSession canAddOutput:audioOut]) {
		[_captureSession addOutput:audioOut];
		_audioConnection = [audioOut connectionWithMediaType:AVMediaTypeAudio];
	}else{
		NSLog(@"Couldn't add audio output");
    }
    [audioOut setSampleBufferDelegate:self queue:queue];
    dispatch_release(queue);
        
    // start audio
    [_captureSession startRunning];
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
	NSUInteger channelIndex = 0;
    
	CMBlockBufferRef audioBlockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
	size_t audioBlockBufferOffset = (channelIndex * numSamples * sizeof(SInt16));
	size_t lengthAtOffset = 0;
	size_t numBlockSamples = 0; // I think this is the same as $numSamples above, since it's mono
	SInt16 *samples = NULL;
	CMBlockBufferGetDataPointer(audioBlockBuffer, audioBlockBufferOffset, &lengthAtOffset, &numBlockSamples, (char **)(&samples));
    
    // buffer samples
    int windowSamples = self.spectrumResolution; // the number of samples to include in each FFT
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
        // loop over as many overlapping windows as are present in the buffer.
        int stepSize = floor(self.spectrumTime * self.sampleRate);
        for( ; _startIndex <= _fbIndex-windowSamples; _startIndex+=stepSize ){
            // copy the window into buffer A, where signal processing will occur
            memcpy( _A, _frameBuffer+_startIndex, sizeof(float)*self.spectrumResolution );

            // setup FFT
            UInt32 log2FFTLength = log2f( self.spectrumResolution );
            
            // apply Hamming window
            vDSP_vmul(_A, 1, _hamm, 1, _A, 1, self.spectrumResolution); //apply
            
            // take fft 	
            // ctoz and ztoc are needed to convert from "split" and "interleaved" complex formats
            // see vDSP documentation for details.
            vDSP_ctoz((COMPLEX*) _A, 2, &(_compl_buf), 1, self.spectrumResolution);
            vDSP_fft_zip( _fftsetup, &(_compl_buf), 1, log2FFTLength, kFFTDirection_Forward );
            ///vDSP_ztoc(&compl_buf, 1, (COMPLEX*) A, 2, inNumberFrames/2); // convert back
            
            // use vDSP_zaspec to get power spectrum
            vDSP_zaspec( &(_compl_buf), _A, self.spectrumResolution );
            
            // accumulate this FFT vector for welch's algorithm
            vDSP_vadd(_A, 1, _acc, 1, _acc, 1, self.spectrumResolution);
        
            if ( ++_accCount >= ACC_NUM ){
                if( pthread_mutex_lock( &_lock ) ) printf( "lock failed!\n" );
                
                // sum spectrum to get total energy
                float energy;
                vDSP_sve( _acc, 1, &energy, self.spectrumResolution );
                
                // convert spectrum and energy to dB
                float reference=1.0f * ACC_NUM; //divide by number of summed spectra
                vDSP_vdbcon( _acc, 1, &reference, _acc, 1, self.spectrumResolution, 1 ); // 1 for power, not amplitude	
                vDSP_vdbcon( &energy, 1, &reference, &energy, 1, 1, 1 ); // 1 for power, not amplitude	
                
                // call delegate method with results
                [self.delegate gotSpectrum:_acc energy:energy];
                
                // clear accumulator
                float zerof=0.0f;
                vDSP_vfill( &zerof, _acc, 1, self.spectrumResolution );
                _accCount = 0;
                
                pthread_mutex_unlock( &_lock );
            }
        }
    }
}

@end
