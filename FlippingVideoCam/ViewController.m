//
//  ViewController.m
//  FlippingVideoCam
//
//  Created by Habib Ghantous on 8/22/17.
//  Copyright © 2017 hgh. All rights reserved.
//

#import "ViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <MediaPlayer/MediaPlayer.h>
#import <Photos/Photos.h>

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    currentFrontCamera=NO;
    isCapturingInput=NO;
    _assetWriter=nil;
    
    [self findCamera:YES]; // init the front camera
    [self findCamera:NO]; // init the back camera
    
    [self performSelector:@selector(initCaptureWithCamera) withObject:nil afterDelay:1];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

-(IBAction)tapStartRecord:(id)sender
{
    if([[btnRecord titleForState:UIControlStateNormal] isEqualToString:@"START"])
    {
        [btnRecord setTitle:@"STOP" forState:UIControlStateNormal];
        isCapturingInput=YES;
    }
    else if([[btnRecord titleForState:UIControlStateNormal] isEqualToString:@"STOP"])
    {
        isCapturingInput=NO;
        
       
        
        dispatch_async(_captureQueue, ^{
            
            
            
            [_assetWriter finishWritingWithCompletionHandler:^{
                // Save to the album
                __block PHObjectPlaceholder *placeholder;
                
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    PHAssetChangeRequest* createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:recordingFile];
                    placeholder = [createAssetRequest placeholderForCreatedAsset];
                    
                } completionHandler:^(BOOL success, NSError *error) {
                    if (success)
                    {
                        NSLog(@"Video successfully saved!");
                        // remove old file at path if exists
                        recordingFile = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/tmp_vid.mov", NSTemporaryDirectory()]];
                        [[NSFileManager defaultManager] removeItemAtURL:recordingFile error:nil];
                    }
                    else
                    {
                        NSLog(@"%@", error);
                    }
                    //[self.captureSession stopRunning];
                    _assetWriter=nil;
                   //recordingFile = nil;
                    //[self initCaptureWithCamera];
                    
                }];
            }];
            
        });

        [btnRecord setTitle:@"START" forState:UIControlStateNormal];
    }
    
}

-(IBAction)tapSwitchCamera:(id)sender
{
    // switch outputs
    [self swipeCamera];
}

-(void)swipeCamera
{
    currentFrontCamera=!currentFrontCamera; // swipe camera
    
    [self.captureSession beginConfiguration];
    
    [self.captureSession removeInput:captureBackInput];
    [self.captureSession removeInput:captureFrontInput];
    
    if(!currentFrontCamera)
        [self.captureSession addInput:captureBackInput];
    else
        [self.captureSession addInput:captureFrontInput];
    
    [self.captureSession commitConfiguration];
}

#pragma mark - Camera methods

-(BOOL)findCamera:(BOOL)useFrontCamera
{
    // 0. Make sure we initialize our camera pointer:
    AVCaptureDevice *m_camera = NULL;
    
    // 1. Get a list of available devices:
    
    AVCaptureDeviceDiscoverySession *captureDeviceDiscoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera]
                                                                                                                            mediaType:AVMediaTypeVideo
                                                                                                                             position:AVCaptureDevicePositionUnspecified];
    NSArray *devices = [captureDeviceDiscoverySession devices];
    
    // 2. Iterate through the device array and if a device is a camera, check if it's the one we want:
    for ( AVCaptureDevice * device in devices )
    {
        if ( useFrontCamera && AVCaptureDevicePositionFront == [ device position ] )
        {
            // We asked for the front camera and got the front camera, now keep a pointer to it:
            m_camera = device;
        }
        else if ( !useFrontCamera && AVCaptureDevicePositionBack == [ device position ] )
        {
            // We asked for the back camera and here it is:
            m_camera = device;
        }
    }
    
    // 3. Set a frame rate for the camera:
    if ( NULL != m_camera )
    {
        // We firt need to lock the camera, so noone else can mess with its configuration:
        if ( [ m_camera lockForConfiguration: NULL ] )
        {
            // Set a minimum frame rate of 10 frames per second
            [ m_camera setActiveVideoMinFrameDuration: CMTimeMake( 1, 10 ) ];
            
            // and a maximum of 30 frames per second
            [ m_camera setActiveVideoMaxFrameDuration: CMTimeMake( 1, 30 ) ];
            
            [ m_camera unlockForConfiguration ];
        }
    }
    
    if(!useFrontCamera)
        backCamera=m_camera;
    else
        frontCamera=m_camera;
    
    // 4. If we've found the camera we want, return true
    return ( NULL != m_camera );
}

-(void) setupWriter
{
    NSError *error = nil;
    if(recordingFile == nil){
         recordingFile = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/tmp_vid.mov", NSTemporaryDirectory()]];
    }
    _assetWriter = [[AVAssetWriter alloc] initWithURL:recordingFile fileType:AVFileTypeQuickTimeMovie error:&error];
    
    NSDictionary* actual = videoOutput.videoSettings;
    int _cy = [[actual objectForKey:@"Height"] intValue];
    int _cx = [[actual objectForKey:@"Width"] intValue];
    
    NSDictionary* settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              AVVideoCodecH264, AVVideoCodecKey,
                              [NSNumber numberWithInt: _cx], AVVideoWidthKey,
                              [NSNumber numberWithInt: _cy], AVVideoHeightKey,
                              nil];
    
    _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    _videoWriterInput.expectsMediaDataInRealTime = YES;
    
    _videoWriterInput.transform=CGAffineTransformMakeRotation(M_PI/2); // else it will shot in landscape even though we hold our phone in portrait mode
    
    _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType: AVMediaTypeAudio outputSettings: nil];
    _audioWriterInput.expectsMediaDataInRealTime = YES;
    
    // add input
    if([_assetWriter canAddInput:_videoWriterInput])
    {
        NSLog(@"added output to video");
        [_assetWriter addInput:_videoWriterInput];
    }
    
    if([_assetWriter canAddInput:_audioWriterInput])
    {
        NSLog(@"added output to audio");
        [_assetWriter addInput:_audioWriterInput];
    }
}

- (void)initCaptureWithCamera
{
    if(self.captureVideoPreviewLayer!=nil) // refresh the views
        [self.captureVideoPreviewLayer removeFromSuperlayer];
    
    // remove old file at path if exists
    recordingFile = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/tmp_vid.mov", NSTemporaryDirectory()]];
    [[NSFileManager defaultManager] removeItemAtURL:recordingFile error:nil];
    
    // ========================= configure session
    
    self.captureSession = [[AVCaptureSession alloc] init];
    NSString* preset = 0;
    if (!preset) {
        preset = AVCaptureSessionPresetHigh;
    }
    self.captureSession.sessionPreset = preset;
    
    // ========================= input devices from camera and mic
    
    NSError * error = NULL;
    captureFrontInput = [AVCaptureDeviceInput deviceInputWithDevice:frontCamera error: &error];
    captureBackInput = [AVCaptureDeviceInput deviceInputWithDevice:backCamera error: &error];
    
    if ( NULL != error )
        return;
    
    if ([self.captureSession canAddInput:captureBackInput])
    {
        NSLog(@"added input from camera");
        [self.captureSession addInput:captureBackInput];
    }
    
    // audio input from default mic
    AVCaptureDevice* mic = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput* micinput = [AVCaptureDeviceInput deviceInputWithDevice:mic error:nil];
    
    if ([self.captureSession canAddInput:micinput])
    {
        NSLog(@"added input from mic");
        [self.captureSession addInput:micinput];
    }
    
    // ========================= now output forms: video and audio in asset writter
    
    _captureQueue = dispatch_queue_create("com.myapp.capture", DISPATCH_QUEUE_SERIAL);
    
    videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    
    [videoOutput setSampleBufferDelegate:self queue:_captureQueue];
    [audioOutput setSampleBufferDelegate:self queue:_captureQueue];
    
    //    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    //    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    //    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    //
    //    [videoOutput setVideoSettings:videoSettings];
    
    if ([self.captureSession canAddOutput:videoOutput]) {
        [self.captureSession addOutput:videoOutput];
    }
    
    if ([self.captureSession canAddOutput:audioOutput]) {
        [self.captureSession addOutput:audioOutput];
    }
    
    // add the preview layer to see what we film
    if (!self.captureVideoPreviewLayer)
        self.captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    
    // if you want to adjust the previewlayer frame, here!
    self.captureVideoPreviewLayer.frame = viewCanvasRecording.bounds;
    self.captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    [viewCanvasRecording.layer addSublayer: self.captureVideoPreviewLayer];
    
    [self.captureSession startRunning];
}

-(void)captureOutput:(AVCaptureOutput*)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection*)connection
{
    BOOL frameFromVideoCaptured = NO;
    
    @synchronized(self)
    {
        if (!isCapturingInput) // we haven't started filming yet just ignore the frames
            return;
        
        if(!_assetWriter)
        {
            [self setupWriter];
        }
        
        frameFromVideoCaptured=(captureOutput==videoOutput);
    }
    
    // pass frame to the assset writer
    [self writeFrame:sampleBuffer isVideo:frameFromVideoCaptured];
}

-(BOOL)writeFrame:(CMSampleBufferRef)sampleBuffer isVideo:(BOOL)isVideo
{
    if (CMSampleBufferDataIsReady(sampleBuffer))
    {
        if (_assetWriter.status == AVAssetWriterStatusUnknown)
        {
            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [_assetWriter startWriting];
            [_assetWriter startSessionAtSourceTime:startTime];
        }
        
        if (_assetWriter.status == AVAssetWriterStatusFailed)
        {
            NSLog(@"writer error %@", _assetWriter.error.localizedDescription);
            return NO;
        }
        
        if (isVideo)
        {
            if (_videoWriterInput.readyForMoreMediaData == YES)
            {
                [_videoWriterInput appendSampleBuffer:sampleBuffer];
                return YES;
            }
        }
        else
        {
            if (_audioWriterInput.readyForMoreMediaData)
            {
                [_audioWriterInput appendSampleBuffer:sampleBuffer];
                return YES;
            }
        }
    }
    
    return NO;
}

@end
