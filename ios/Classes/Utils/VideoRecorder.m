//
//  VideoRecorder.m
//  arkit_plugin
//
//  Created by 上江洲　智久 on 2020/04/13.
//

#import "VideoRecorder.h"

static const int frameRate = 30;
static const int USE_MIC = 1;

@interface VideoRecorder()

@property CGFloat scale;
@property BOOL isRecording;
@property CADisplayLink* displayLink;

@property int frameCount;
@property NSURL* outputURL;
@property AVAssetWriter* assetWriter;
@property AVAssetWriterInput* videoInput;
@property int movPixelWidth;
@property int movPixelHeight;
@property CGSize movieSize;
@property AVAssetWriterInputPixelBufferAdaptor* adaptor;
@property dispatch_queue_t queue;
@property CMTime lastUpdateTime;

@property AVCaptureSession* session;
@property AVAssetWriterInput* audioInput;
@property dispatch_queue_t audioBufferQueue;

@end

@implementation VideoRecorder

- (nonnull instancetype)initWithView:(nonnull SCNView*)view {
    if (self = [super init]) {
        _view = view;
        _scale = UIScreen.mainScreen.scale;
    }
    return self;
}


- (void) startRecord:(NSString*) path useAudio:(int)useAudio {
    if (_isRecording) return;
    NSLog(@"startScreenRecord audio:%d", useAudio);
    _isRecording = true;
    [self clearFiles:path];
    [self initVideoRecorderWithPath: path useAudio:useAudio];

    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(saveFrameImage)];
    _displayLink.preferredFramesPerSecond = frameRate;
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

    NSError *error = nil;
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error != nil) {
        NSLog(@"Error when preparing audio session : %@", [error localizedDescription]);
        return;
    }
    [session setActive:YES error:&error];
    if (error != nil) {
        NSLog(@"Error when enabling audio session : %@", [error localizedDescription]);
        return;
    }
    if (_delegate != nil) {
        [_delegate recStateChanged:true];
    }
}

- (void) stopRecord {
    if (!_isRecording) return;
    NSLog(@"stopScreenRecord");
    _isRecording = false;
    [_displayLink removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];

    [self stopRecordMic];
    [self finishVideoWriting];
    if (_delegate != nil) {
        [_delegate recStateChanged:false];
    }
}

- (void) stopRecordMic {
    if (_session.isRunning) {
        [_session stopRunning];
    }
}

- (void) toggleRecord:(NSString*) path useAudio:(int)useAudio {
    if (!_isRecording) {
        [self startRecord:path useAudio:useAudio];
    } else {
        [self stopRecord];
    }
}

- (void) clearFiles: (NSString*) path {
    NSFileManager* fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path]) {
        [fm removeItemAtPath:path error:nil];
    }
}

- (void) initVideoRecorderWithPath: (NSString*) path useAudio:(int)useAudio{
    _frameCount = 0;
    _queue = dispatch_queue_create("makingMovie", DISPATCH_QUEUE_SERIAL);
    _outputURL = [NSURL fileURLWithPath:path];

    _assetWriter = [AVAssetWriter assetWriterWithURL:_outputURL fileType:AVFileTypeQuickTimeMovie error:nil];
    
    if (useAudio == USE_MIC) {
        [self prepareAudioDevice];
    }

    [self calcPixelSizeForMovie:_view.frame.size scale:_scale];
    NSDictionary* outputSetting = @{AVVideoCodecKey: AVVideoCodecTypeH264, AVVideoWidthKey: @(_movPixelWidth), AVVideoHeightKey: @(_movPixelHeight)};
    _videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:outputSetting];
    _videoInput.expectsMediaDataInRealTime = true;
    _adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoInput sourcePixelBufferAttributes:@{
        (__bridge_transfer NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB),
        (__bridge_transfer NSString *)kCVPixelBufferWidthKey: @(_movPixelWidth),
        (__bridge_transfer NSString *)kCVPixelBufferHeightKey: @(_movPixelHeight)
    }];

    if ([_assetWriter canAddInput:_videoInput]) {
        [_assetWriter addInput:_videoInput];
    } else {
        NSLog(@"An error occurred while adding video input");
    }
}

- (void) prepareAudioDevice {
    _audioBufferQueue = dispatch_queue_create("AudioBufferQueue", DISPATCH_QUEUE_SERIAL);

    AVCaptureDevice* device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput* audioDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:nil];
    
    AVCaptureAudioDataOutput* audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [audioDataOutput setSampleBufferDelegate:self queue:_queue];

    _session = [[AVCaptureSession alloc] init];
    _session.sessionPreset = AVCaptureSessionPresetMedium;
    _session.usesApplicationAudioSession = true;
    _session.automaticallyConfiguresApplicationAudioSession = false;
    
    if ([_session canAddInput:audioDeviceInput]) {
        [_session addInput:audioDeviceInput];
    }
    if ([_session canAddOutput:audioDataOutput]) {
        [_session addOutput:audioDataOutput];
    }
    
    NSDictionary* audioSettings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVNumberOfChannelsKey: @(1),
        AVSampleRateKey: @(44100.0),
        AVEncoderBitRateKey: @(128000)
    };
    
    _audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    _audioInput.expectsMediaDataInRealTime = true;

    dispatch_async(_audioBufferQueue, ^{
        [self->_session startRunning];
    });
    
    if ([_assetWriter canAddInput:_audioInput]) {
        [_assetWriter addInput:_audioInput];
    }
}

- (void) saveFrameImage {
    @autoreleasepool {
        CMTime time = [self getTime];
        if (_frameCount == 0) {
            if (_assetWriter != nil) {
                if (!_assetWriter.startWriting) {
                    NSLog(@"videoWriter startWriting is false");
                }
                [_assetWriter startSessionAtSourceTime:time];
                NSLog(@"making movie is started");
            } else {
                NSLog(@"videoWriter is nil");
            }
        }
        UIImage* img = _view.snapshot;
        UIImage* cropped = [img cropImage:_movieSize];
        dispatch_async(_queue, ^{
            @autoreleasepool {
                [self appendImageToBuffer:cropped time:time];
            }
        });
    }
}

- (void) calcPixelSizeForMovie: (CGSize) size scale:(CGFloat) scale {
    const int num = 16;
    int pixelWidth = (int)(size.width * scale);
    _movPixelWidth = (pixelWidth / num) * num;
    int pixelHeight = (int)(size.height * scale);
    _movPixelHeight = (pixelHeight / num) * num;
    _movieSize = CGSizeMake(((CGFloat)_movPixelWidth), ((CGFloat)_movPixelHeight));
}

- (void) appendImageToBuffer:(UIImage*) image time: (CMTime) time {
    if (_adaptor == nil) return;
    _frameCount ++;
    if (!_adaptor.assetWriterInput.isReadyForMoreMediaData) return;
    CMTime frameTime = time;
    CVPixelBufferRef buffer = [self pixelBufferFromCGImage:image.CGImage];
    [_adaptor appendPixelBuffer:buffer withPresentationTime:frameTime];
    CFRelease(buffer);
    _lastUpdateTime = frameTime;
}

- (CVPixelBufferRef) pixelBufferFromCGImage:(CGImageRef) image {
    NSDictionary *options = @{
        (__bridge_transfer NSString *)kCVPixelBufferCGImageCompatibilityKey: @(true),
        (__bridge_transfer NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @(true)
    };
    CVPixelBufferRef pxBuffer = nil;

    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    CVPixelBufferCreate(kCFAllocatorDefault,
                        width,
                        height,
                        kCVPixelFormatType_32ARGB,
                        (__bridge CFDictionaryRef)options,
                        &pxBuffer);

    CVPixelBufferLockBaseAddress(pxBuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxBuffer);

    size_t bitsPerComponent = 8;
    size_t bytesPerRow = 4 * width;
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 width,
                                                 height,
                                                 bitsPerComponent,
                                                 bytesPerRow,
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    
    CGContextDrawImage(context, CGRectMake(0, 0, (CGFloat) width, (CGFloat) height), image);
    CFRelease(context);
    CFRelease(rgbColorSpace);
    
    CVPixelBufferUnlockBaseAddress(pxBuffer, 0);
    return pxBuffer;
}

- (void) finishVideoWriting {
    dispatch_async(_queue, ^{
        [self->_videoInput markAsFinished];
        [self->_assetWriter endSessionAtSourceTime: self->_lastUpdateTime];
        [self->_assetWriter finishWritingWithCompletionHandler:^{
            NSLog(@"movie created count:%d", self->_frameCount);
            CVPixelBufferPoolRelease(self->_adaptor.pixelBufferPool);
            [self registerVideoToGallery];
        }];
    });
}

- (void) registerVideoToGallery {
    if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(self->_outputURL.path)) {
        UISaveVideoAtPathToSavedPhotosAlbum(self->_outputURL.path, self, nil, nil);
        NSLog(@"save to album");
    } else {
        NSLog(@"failure saving to album");
    }
}

- (CMTime) getTime {
    return CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000000);
}

/* AVCaptureAudioDataOutputSampleBufferDelegate implements */
- (void) captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (_audioInput != nil) {
        CFRetain(sampleBuffer);
        dispatch_async(_audioBufferQueue, ^{
            if (self->_audioInput.isReadyForMoreMediaData && self->_isRecording) {
                [self->_audioInput appendSampleBuffer:sampleBuffer];
                CFRelease(sampleBuffer);
            }
        });
    }
}


@end

@implementation UIView (Capture)

- (UIImage*) getCaptureImageFromView {
    CGSize contextSize = self.frame.size;
    UIGraphicsBeginImageContextWithOptions(contextSize, false, 0.0);
    [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:false];
    UIImage* captureImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return captureImage;
}

@end


@implementation UIImage (Crop)

- (UIImage*)cropImage:(CGSize) croppedSize {
    CGFloat orgWidth = self.size.width;
    CGFloat orgHeight = self.size.height;
    
    CGFloat cropWidth = croppedSize.width;
    CGFloat cropHeight = croppedSize.height;
    
    CGRect cropRect = CGRectMake((orgWidth - cropWidth) / 2, (orgHeight - cropHeight) / 2, cropWidth, cropHeight);
    UIGraphicsBeginImageContextWithOptions(croppedSize, false, 0.0);
    [self drawInRect:cropRect];
    UIImage* croppedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return croppedImage;
}

@end
