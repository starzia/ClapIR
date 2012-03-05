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

-(id)init{
    self = [super init];
    if( self ){
        
    }
    return self;
}

-(void)start{
    // create an AV Capture session
    AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    // setup the audio input
    AVCaptureDevice *audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    NSError *error = nil;
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioCaptureDevice error:&error];
    if (audioInput) {
        [captureSession addInput:audioInput];
    }
    else {
        // Handle the failure.
        NSLog( @"ERROR: could not setup audio input" );
        return;
    }
    // setup the audio output
    AVCaptureAudioDataOutput* audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    [captureSession addOutput:audioOutput];
    
    dispatch_queue_t queue = dispatch_queue_create("myQueue", NULL);
    [audioOutput setSampleBufferDelegate:self queue:queue];
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
}

@end
