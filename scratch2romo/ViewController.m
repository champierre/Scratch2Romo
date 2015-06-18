//
//  ViewController.m
//  scratch2romo
//
//  Created by Ishihara Junya on 2014/11/26.
//  Copyright (c) 2014年 Tsukurusha. All rights reserved.
//

#import "ViewController.h"
#import "GCDAsyncSocket.h"
#import "NSData+NSData_Conversion.h"
#import "AppDelegate.h"
#import "Utilities.h"

#define PORT 42001
#define MAX_RETRY 10

@interface ViewController ()
@end

@implementation ViewController

static void AudioInputCallback(
                               void* inUserData,
                               AudioQueueRef inAQ,
                               AudioQueueBufferRef inBuffer,
                               const AudioTimeStamp *inStartTime,
                               UInt32 inNumberPacketDescriptions,
                               const AudioStreamPacketDescription *inPacketDescs)
{
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [RMCore setDelegate:self];
    
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:mainQueue];

    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
    [self.view addGestureRecognizer:tapRecognizer];

    AppDelegate *app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    app.viewController = self;

    // initialize network related variables
    NSString *currentIPAddress = [Utilities currentIPAddress];
    NSArray *numbers = [currentIPAddress componentsSeparatedByString: @"."];
    ipRange = [NSString stringWithFormat:@"%@.%@.%@.", numbers[0], numbers[1], numbers[2]];
    lastNumberOfIPAddress = 1;
    retryCount = 0;
    autoConnecting = NO;

    degrees = 10;
    steps = 10;
    speed = 30;
    faceAppeared = NO;

    _hostAddressTextField.text = ipRange;

    _degreesLabel.text = [NSString stringWithFormat:@"degrees: %d", degrees];
    _stepsLabel.text = [NSString stringWithFormat:@"steps: %d", steps];
    _speedLabel.text = [NSString stringWithFormat:@"speed: %d", speed];
    _speechLabel.text = [NSString stringWithFormat:@"speech: %@", speech];

    [self setupAVCapture];
    
    [self startMonitoringAudio];

    motionManager = [[CMMotionManager alloc] init];
    if (motionManager.accelerometerAvailable)
    {
        // センサーの更新間隔の指定
        motionManager.accelerometerUpdateInterval = 0.2;

        // ハンドラを指定
        CMAccelerometerHandler handler = ^(CMAccelerometerData *data, NSError *error)
        {
            // 画面に表示
            _axLabel.text = [NSString stringWithFormat:@"ax: %f", data.acceleration.x];
            _ayLabel.text = [NSString stringWithFormat:@"ay: %f", data.acceleration.y];
            _azLabel.text = [NSString stringWithFormat:@"az: %f", data.acceleration.z];
            
            NSDictionary *sensors = @{
                                      @"ax": [[NSNumber alloc] initWithDouble:data.acceleration.x],
                                      @"ay": [[NSNumber alloc] initWithDouble:data.acceleration.y],
                                      @"az": [[NSNumber alloc] initWithDouble:data.acceleration.z],
                                      };
            [self sensorUpdate:sensors];
        };
        
        // 加速度の取得開始
        [motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:handler];
    }
    
    
    // 近接センサオン
    [UIDevice currentDevice].proximityMonitoringEnabled = YES;
    
    // 近接センサ監視
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(proximitySensorStateDidChange:)
                                                 name:UIDeviceProximityStateDidChangeNotification
                                               object:nil];

    // 音声読み上げ
    synthesizer = [[AVSpeechSynthesizer alloc] init];
    synthesizer.delegate = self;

    self.RomoCharacter = [RMCharacter Romo];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!faceAppeared) {
        [self.RomoCharacter addToSuperview:self.view];
        faceAppeared = YES;
    } else {
        [self.RomoCharacter removeFromSuperview];
        faceAppeared = NO;
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (motionManager.accelerometerActive) {
        [motionManager stopAccelerometerUpdates];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)connectButtonTouchDown:(id)sender {
    retryCount = MAX_RETRY;
    [self disconnect];

    lastNumberOfIPAddress = 1;

    NSArray *numbers = [_hostAddressTextField.text componentsSeparatedByString: @"."];
    if ([numbers count] == 4 && [numbers[0] length] > 0 && [numbers[1] length] > 0 && [numbers[2] length] > 0 && [numbers[3] length] > 0) {
        autoConnecting = NO;
        hostAddress = _hostAddressTextField.text;
        [self connectToScratch];
    } else {
        autoConnecting = YES;
        [self autoConnect];
    }
}

- (IBAction)helpButtonTouchDown:(id)sender {
    NSURL *url = [NSURL URLWithString:@"http://scratch2romo.tumblr.com/post/108642514907/getting-started"];
    [[UIApplication sharedApplication] openURL:url];
}

- (void)disconnect {
    [asyncSocket disconnect];
}

- (void)forward {
    [self stop];
    [self showMessage:@"Forward"];

    // If Romo3 is driving, let's stop driving
    BOOL RomoIsDriving = (self.Romo3.leftDriveMotor.powerLevel != 0) || (self.Romo3.rightDriveMotor.powerLevel != 0);
    if (!RomoIsDriving) {
        // Change Romo's LED to pulse
        [self.Romo3.LEDs pulseWithPeriod:1.0 direction:RMCoreLEDPulseDirectionUpAndDown];

        // Romo's top speed is around 0.75 m/s
        float speedInMetersPerSecond = speed / 100.0 * 0.75;

        // Give Romo the drive command
        if (steps > 0) {
            [self.Romo3 driveForwardWithSpeed: speedInMetersPerSecond];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * (steps / 10.0) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self stop];
            });
        } else {
            [self.Romo3 driveBackwardWithSpeed: speedInMetersPerSecond];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * (-steps / 10.0) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self stop];
            });
        }
    }
}

- (void)backward {
    [self stop];
    [self showMessage:@"Backward"];
    
    // If Romo3 is driving, let's stop driving
    BOOL RomoIsDriving = (self.Romo3.leftDriveMotor.powerLevel != 0) || (self.Romo3.rightDriveMotor.powerLevel != 0);
    if (!RomoIsDriving) {
        // Change Romo's LED to pulse
        [self.Romo3.LEDs pulseWithPeriod:1.0 direction:RMCoreLEDPulseDirectionUpAndDown];
        
        // Romo's top speed is around 0.75 m/s
        float speedInMetersPerSecond = speed / 100.0 * 0.75;
        
        // Give Romo the drive command
        if (steps > 0) {
            [self.Romo3 driveBackwardWithSpeed: speedInMetersPerSecond];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * (steps / 10.0) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self stop];
            });
        } else {
            [self.Romo3 driveForwardWithSpeed: speedInMetersPerSecond];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * (-steps / 10.0) * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self stop];
            });
        }
    }
}

- (void)stop {
    [self showMessage:@"Stop"];
    
    // If Romo3 is driving, let's stop driving
    BOOL RomoIsDriving = (self.Romo3.leftDriveMotor.powerLevel != 0) || (self.Romo3.rightDriveMotor.powerLevel != 0);
    if (RomoIsDriving) {
        // Change Romo's LED to be solid at 80% power
        [self.Romo3.LEDs setSolidWithBrightness:0.8];
        
        // Tell Romo3 to stop
        [self.Romo3 stopDriving];
    }
}

- (void)right {
    [self stop];
    [self showMessage:@"Right"];
    
    // If Romo3 is driving, let's stop driving
    BOOL RomoIsDriving = (self.Romo3.leftDriveMotor.powerLevel != 0) || (self.Romo3.rightDriveMotor.powerLevel != 0);
    if (!RomoIsDriving) {
        float radius = 0;
        
        // Give Romo the drive command
        [self.Romo3 turnByAngle:degrees * -1 withRadius:radius completion:nil];
    }
}

- (void)left {
    [self stop];
    [self showMessage:@"Left"];
    
    // If Romo3 is driving, let's stop driving
    BOOL RomoIsDriving = (self.Romo3.leftDriveMotor.powerLevel != 0) || (self.Romo3.rightDriveMotor.powerLevel != 0);
    if (!RomoIsDriving) {
        float radius = 0;
        
        // Give Romo the drive command
        [self.Romo3 turnByAngle:degrees withRadius:radius completion:nil];
    }
}

- (void)up
{
    [self showMessage:@"Up"];

    // If Romo3 is tilting, stop tilting
    BOOL RomoIsTilting = (self.Romo3.tiltMotor.powerLevel != 0);
    if (RomoIsTilting) {
        // Tell Romo3 to stop tilting
        [self.Romo3 stopTilting];
    } else {
        // Tilt up by ten degrees
        float tiltByAngleInDegrees = 10.0;
        
        [self.Romo3 tiltByAngle:tiltByAngleInDegrees
                     completion:^(BOOL success) {
                         // Reset button title on the main queue
                     }];
    }
}

- (void)down
{
    [self showMessage:@"Down"];

    // If Romo3 is tilting, stop tilting
    BOOL RomoIsTilting = (self.Romo3.tiltMotor.powerLevel != 0);
    if (RomoIsTilting) {
        
        // Tell Romo3 to stop tilting
        [self.Romo3 stopTilting];
        
    } else {
        
        // Tilt down by ten degrees
        float tiltByAngleInDegrees = -10.0;
        
        [self.Romo3 tiltByAngle:tiltByAngleInDegrees
                     completion:^(BOOL success) {
                     }];
    }
}

-(void)light:(bool)on
{
    // check if flashlight available
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([device hasTorch] && [device hasFlash]){

            [device lockForConfiguration:nil];
            if (on) {
                [device setTorchMode:AVCaptureTorchModeOn];
                [device setFlashMode:AVCaptureFlashModeOn];
                [self showMessage:@"Light On"];
            } else {
                [device setTorchMode:AVCaptureTorchModeOff];
                [device setFlashMode:AVCaptureFlashModeOff];
                [self showMessage:@"Light Off"];
            }
            [device unlockForConfiguration];
        }
    }
}

-(void)led:(bool)on
{
    if (on) {
        [self.Romo3.LEDs setSolidWithBrightness:0.8];
        [self showMessage:@"LED On"];
    } else {
        [self.Romo3.LEDs turnOff];
        [self showMessage:@"LED Off"];
    }
}

-(void)photo
{
    [self showMessage:@"Take Photo"];
    
    // ビデオ入力のAVCaptureConnectionを取得
    AVCaptureConnection *videoConnection = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if (videoConnection == nil) {
        return;
    }
    
    // ビデオ入力から画像を非同期で取得。ブロックで定義されている処理が呼び出され、画像データを引数から取得する
    [self.stillImageOutput
     captureStillImageAsynchronouslyFromConnection:videoConnection
     completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
         if (imageDataSampleBuffer == NULL) {
             return;
         }
         
         // 入力された画像データからJPEGフォーマットとしてデータを取得
         NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
         
         // JPEGデータからUIImageを作成
         UIImage *image = [[UIImage alloc] initWithData:imageData];
         
         // アルバムに画像を保存
         UIImageWriteToSavedPhotosAlbum(image, self, nil, nil);
     }];
}

- (void)say {
    if ([speech length] > 0) {
        [self pauseMonitoringAudio];

        AVSpeechUtterance *utterance = [AVSpeechUtterance speechUtteranceWithString:speech];
        utterance.rate = 0.2;
        utterance.pitchMultiplier = 0.7;
        utterance.preUtteranceDelay = 0.1f;
        [synthesizer speakUtterance:utterance];
    }
}

- (void)showMessage:(NSString *)message {
    _messageLabel.text = message;
    _messageLabel.alpha = 1.0;
}

- (void)updateHeading {
    AppDelegate *app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    _headingLabel.text = [NSString stringWithFormat:@"heading: %f", app.heading];
    NSDictionary *sensors = @{@"heading": [[NSNumber alloc] initWithDouble:app.heading]};
    [self sensorUpdate:sensors];
}

- (void)updateVolume:(NSTimer *)timer {
    AudioQueueLevelMeterState levelMeter;
    UInt32 levelMeterSize = sizeof(AudioQueueLevelMeterState);
    AudioQueueGetProperty(queue,kAudioQueueProperty_CurrentLevelMeterDB,&levelMeter,&levelMeterSize);

    _audioLabel.text = [NSString stringWithFormat:@"audio: %f", levelMeter.mPeakPower];
    NSDictionary *sensors = @{@"audio": [[NSNumber alloc] initWithDouble:levelMeter.mPeakPower]};
    [self sensorUpdate:sensors];
}

- (void)sensorUpdate:(NSDictionary *)sensors {
    if (asyncSocket.isDisconnected){
        return;
    }
    
    NSMutableArray *sensorPairs = [[NSMutableArray alloc] init];
    for (id key in [sensors keyEnumerator]) {
        [sensorPairs addObject:[NSString stringWithFormat:@"\"%@\" %@", key, sensors[key]]];
    }
    NSString *message = [NSString stringWithFormat:@"sensor-update %@", [sensorPairs componentsJoinedByString:@" "]];
    NSData *data = [[NSString stringWithString:message] dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *toSend;
    Byte *toAppend = (Byte*)malloc(4);
    
    toAppend[0]=(([data length] >> 24) & 0xFF);
    toAppend[1]=(([data length] >> 16) & 0xFF);
    toAppend[2]=(([data length] >> 8) & 0xFF);
    toAppend[3]=([data length] & 0xFF);
    
    toSend = [NSMutableData dataWithBytes:toAppend length:4];
    [toSend appendData:data];

    [asyncSocket writeData:toSend withTimeout:-1 tag:0];
}

- (void)broadcast:(NSString *)message {
    if (asyncSocket.isDisconnected){
        return;
    }

    NSString *str = [NSString stringWithFormat:@"broadcast \"%@\"", message];
    NSData *data = [[NSString stringWithString:str] dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *toSend;
    Byte *toAppend = (Byte*)malloc(4);
    
    toAppend[0]=(([data length] >> 24) & 0xFF);
    toAppend[1]=(([data length] >> 16) & 0xFF);
    toAppend[2]=(([data length] >> 8) & 0xFF);
    toAppend[3]=([data length] & 0xFF);
    
    toSend = [NSMutableData dataWithBytes:toAppend length:4];
    [toSend appendData:data];

    [asyncSocket writeData:toSend withTimeout:-1 tag:0];
}

- (void)setupAVCapture
{
    NSError *error = nil;
    
    // 入力と出力からキャプチャーセッションを作成
    self.session = [[AVCaptureSession alloc] init];
    
    // 正面に配置されているカメラを取得
    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    // カメラからの入力を作成し、セッションに追加
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:camera error:&error];

    if ([self.session canAddInput: self.videoInput])
    {
        [self.session addInput:self.videoInput];
    }
    
    // 画像への出力を作成し、セッションに追加
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    [self.session addOutput:self.stillImageOutput];
    
    // セッション開始
    [self.session startRunning];
}

- (void)startMonitoringAudio {
    NSLog(@"startMonitoringAudio");

    AudioStreamBasicDescription dataFormat;
    dataFormat.mSampleRate = 44100.0f;
    dataFormat.mFormatID = kAudioFormatLinearPCM;
    dataFormat.mFormatFlags = kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    dataFormat.mBytesPerPacket = 2;
    dataFormat.mFramesPerPacket = 1;
    dataFormat.mBytesPerFrame = 2;
    dataFormat.mChannelsPerFrame = 1;
    dataFormat.mBitsPerChannel = 16;
    dataFormat.mReserved = 0;
    AudioQueueNewInput(&dataFormat, AudioInputCallback, (__bridge void *)(self), CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &queue);
    AudioQueueStart(queue, NULL);
    UInt32 enabledLevelMeter = true;
    AudioQueueSetProperty(queue,kAudioQueueProperty_EnableLevelMetering,&enabledLevelMeter,sizeof(UInt32));

    timer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                             target:self
                                           selector:@selector(updateVolume:)
                                           userInfo:nil
                                            repeats:YES];
}

- (void)stopMonitoringAudio {
    if ([timer isValid]) {
        [timer invalidate];
    }
    timer = nil;

    AudioQueueFlush(queue);
    AudioQueueStop(queue, NO);
    AudioQueueDispose(queue, YES);
}

- (void)pauseMonitoringAudio {
    // stop immediately
    AudioQueueStop(queue, YES);
}

- (void)resumeMonitoringAudio {
    AudioQueueStart(queue, NULL);
}

- (void)tap:(UIGestureRecognizer *)gestureRecognizer
{
    [self.view endEditing:YES];
}

- (void)proximitySensorStateDidChange:(NSNotification *)notification
{
    _proximityLabel.text = [NSString stringWithFormat:@"proximity: %d", [UIDevice currentDevice].proximityState];
    
    NSDictionary *sensors = @{
                              @"proximity": [[NSNumber alloc] initWithInt:[UIDevice currentDevice].proximityState]
                              };
    [self sensorUpdate:sensors];
}

- (void) autoConnect {
    hostAddress = [NSString stringWithFormat:@"%@%d", ipRange, lastNumberOfIPAddress];
    [self connectToScratch];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Socket Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSString *message = [NSString stringWithFormat:@"Connected to %@", host];
    [self showMessage:message];
    NSLog(@"%@", message);

    _hostAddressTextField.text = host;
    autoConnecting = NO;
    retryCount = 0;
    
    [self broadcast:@"forward"];
    [self broadcast:@"backward"];
    [self broadcast:@"right"];
    [self broadcast:@"left"];
    [self broadcast:@"up"];
    [self broadcast:@"down"];
    [self broadcast:@"stop"];
    
    // disable for free version
    [self broadcast:@"led on"];
    [self broadcast:@"led off"];
    [self broadcast:@"light on"];
    [self broadcast:@"light off"];
    [self broadcast:@"photo"];
    [self broadcast:@"say"];
    
    [self.Romo3.LEDs turnOff];
    
    [asyncSocket readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    int dataLength = [data length];
    int processedDataLength = 0;
    
    while (processedDataLength < dataLength) {
        UInt8 dataBytes[1024];
        
        [data getBytes:dataBytes range:NSMakeRange(processedDataLength, 4)];
        NSData *lengthData = [NSData dataWithBytes:dataBytes length:4];
        int length = CFSwapInt32BigToHost(*(int*)([lengthData bytes]));

        [data getBytes:dataBytes range:NSMakeRange(processedDataLength + 4, length)];
        NSData *messageData = [NSData dataWithBytes:dataBytes length:length];
        NSString *message = [[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding];
        NSLog(@"message: %@", message);

        [self processMessage:message];
        processedDataLength += (length + 4);
    }

    [asyncSocket readDataWithTimeout:-1 tag:0];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    [self showMessage:@"Disconnected."];
    NSLog(@"socketDidDisconnect:%p withError: %@", sock, err);
    if (autoConnecting) {
        if (lastNumberOfIPAddress < 255) {
            hostAddress = [NSString stringWithFormat:@"%@%d", ipRange, lastNumberOfIPAddress];
            [self connectToScratch];
            lastNumberOfIPAddress++;
        }
    } else {
        if (retryCount < MAX_RETRY) {
            NSLog(@"retry %d", retryCount);
            [self performSelector:@selector(connectToScratch) withObject:nil afterDelay:5.0f];
            retryCount++;
        }
    }
}

- (void)connectToScratch {
    NSLog(@"Connecting... %@:%d", hostAddress, PORT);
    [self showMessage: [NSString stringWithFormat:@"Connecting... %@:%d", hostAddress, PORT]];
    NSError *error = nil;
    if (![asyncSocket connectToHost:hostAddress onPort:PORT withTimeout: 0.2 error:&error])
    {
        [self showMessage:error.localizedDescription];
        NSLog(@"Connection Error: %@", error);
    }
}

- (void)processMessage:(NSString *)message
{
    if ([message hasPrefix:@"broadcast"]) {
        NSString *action = [message substringWithRange:NSMakeRange(11, [message length] - 12)];
        if ([action isEqualToString:@"forward"]) {
            [self forward];
        } else if ([action isEqualToString:@"backward"]) {
            [self backward];
        } else if ([action isEqualToString:@"right"]) {
            [self right];
        } else if ([action isEqualToString:@"left"]) {
            [self left];
        } else if ([action isEqualToString:@"up"]) {
            [self up];
        } else if ([action isEqualToString:@"down"]) {
            [self down];
        } else if ([action isEqualToString:@"stop"]) {
            [self stop];
        } else if ([action isEqualToString:@"led on"]) {
            [self led:YES];
        } else if ([action isEqualToString:@"led off"]) {
            [self led:NO];
        } else if ([action isEqualToString:@"light on"]) {
            [self light:YES];
        } else if ([action isEqualToString:@"light off"]) {
            [self light:NO];
        } else if ([action isEqualToString:@"photo"]) {
            [self photo];
        } else if ([action isEqualToString:@"say"]) {
            [self say];
        }
    } else if ([message hasPrefix:@"sensor-update"]) {
        NSString *pairs = [message substringWithRange:NSMakeRange(14, [message length] - 14)];
        NSArray *array = [pairs componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

        for (int i = 0; i < [array count] - 1; i+=2) {
            NSString *varName = array[i];
            NSString *newValue = array[i+1];
            
            int intNewValue;

            if ([varName isEqualToString:@"\"degrees\""]) {
                intNewValue = [newValue intValue];
                if (intNewValue > 360) {
                    intNewValue = 360;
                } else if (intNewValue < 0) {
                    intNewValue = 0;
                }
                degrees = intNewValue;
                _degreesLabel.text = [NSString stringWithFormat:@"degrees: %d", intNewValue];
            } else if([varName isEqualToString:@"\"steps\""]) {
                intNewValue = [newValue intValue];
                if (intNewValue > 100) {
                    intNewValue = 100;
                } else if (intNewValue < -100) {
                    intNewValue = -100;
                }
                steps = intNewValue;
                _stepsLabel.text = [NSString stringWithFormat:@"steps: %d", intNewValue];
            } else if([varName isEqualToString:@"\"speed\""]) {
                intNewValue = [newValue intValue];
                if (intNewValue > 100) {
                    intNewValue = 100;
                } else if (intNewValue < -100) {
                    intNewValue = -100;
                }
                speed = intNewValue;
                _speedLabel.text = [NSString stringWithFormat:@"speed: %d", intNewValue];
            } else if([varName isEqualToString:@"\"speech\""]) {
                speech = newValue;
                _speechLabel.text = [NSString stringWithFormat:@"speech: %@", newValue];
            }
        }
    }
    [NSThread sleepForTimeInterval:0.1f];
}

- (void)dealloc
{
    [asyncSocket setDelegate:nil delegateQueue:NULL];
    [asyncSocket disconnect];

    [self stopMonitoringAudio];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark AVSpeechSynthesizerDelegate Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didStartSpeechUtterance:(AVSpeechUtterance *)utterance
{
    NSLog(@"didStartSpeech");
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance
{
    [self resumeMonitoringAudio];
    NSLog(@"didCancelSpeech");
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance
{
    [self resumeMonitoringAudio];
    NSLog(@"didFinishSpeech");
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark RMCore Delegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)robotDidConnect:(RMCoreRobot *)robot
{
    // Currently the only kind of robot is Romo3, so this is just future-proofing
    if ([robot isKindOfClass:[RMCoreRobotRomo3 class]]) {
        self.Romo3 = (RMCoreRobotRomo3 *)robot;
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    if (robot == self.Romo3) {
        self.Romo3 = nil;
    }
}

@end
