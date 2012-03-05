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

-(id)init{
    self = [super init];
    if( self ){
        
    }
    return self;
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
    
    size_t samples = CMSampleBufferGetTotalSampleSize( sampleBuffer );
    NSLog( @"got %lu samples of audio", samples );
    
    // check format of audio
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
    const AudioStreamBasicDescription *streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);

}

@end
