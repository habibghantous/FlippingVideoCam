//
//  ViewController.h
//  FlippingVideoCam
//
//  Created by Habib Ghantous on 8/22/17.
//  Copyright © 2017 hgh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface ViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
{
    IBOutlet UIView *viewCanvasRecording;
    IBOutlet UIButton *btnRecord;
    
    AVCaptureDevice *frontCamera; // A pointer to the front camera
    AVCaptureDevice *backCamera; // A pointer to the back camera
    
    AVCaptureDeviceInput *captureFrontInput;
    AVCaptureDeviceInput *captureBackInput;
    
    __block AVAssetWriter *_assetWriter;
    __block AVAssetWriterInput *_videoWriterInput;
    __block AVAssetWriterInput *_audioWriterInput;
    
    __block AVCaptureVideoDataOutput *videoOutput;
    
    dispatch_queue_t _captureQueue;
    
    BOOL currentFrontCamera;
    BOOL isCapturingInput;
    NSURL *recordingFile;
}

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;

@end


