//
//  ViewController.h
//  scratch2romo
//
//  Created by Ishihara Junya on 2014/11/26.
//  Copyright (c) 2014年 Tsukurusha. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <RMCore/RMCore.h>
#import <RMCharacter/RMCharacter.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMotion/CoreMotion.h>

@class GCDAsyncSocket;

@interface ViewController : UIViewController <RMCoreDelegate, AVSpeechSynthesizerDelegate>
{
    GCDAsyncSocket *asyncSocket;
    int degrees;
    int steps;
    int speed;
    int expression;
    int emotion;
    AudioQueueRef queue;
    NSTimer *timer;
    CMMotionManager *motionManager;
    NSString *speech;
    AVSpeechSynthesizer *synthesizer;
    int lastNumberOfIPAddress;
    int retryCount;
    NSString *hostAddress;
    NSString *ipRange;
    BOOL autoConnecting;
    BOOL faceAppeared;
}

@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIButton *helpButton;
@property (weak, nonatomic) IBOutlet UITextField *hostAddressTextField;
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;

@property (weak, nonatomic) IBOutlet UILabel *expressionLabel;
@property (weak, nonatomic) IBOutlet UILabel *emotionLabel;
@property (weak, nonatomic) IBOutlet UILabel *stepsLabel;
@property (weak, nonatomic) IBOutlet UILabel *degreesLabel;
@property (weak, nonatomic) IBOutlet UILabel *speedLabel;
@property (weak, nonatomic) IBOutlet UILabel *headingLabel;
@property (weak, nonatomic) IBOutlet UILabel *audioLabel;
@property (weak, nonatomic) IBOutlet UILabel *axLabel;
@property (weak, nonatomic) IBOutlet UILabel *ayLabel;
@property (weak, nonatomic) IBOutlet UILabel *azLabel;
@property (weak, nonatomic) IBOutlet UILabel *proximityLabel;
@property (weak, nonatomic) IBOutlet UILabel *speechLabel;

@property (nonatomic, strong) RMCoreRobotRomo3 *Romo3;
@property (nonatomic, strong) RMCharacter *RomoCharacter;
@property (strong, nonatomic) AVCaptureDeviceInput *videoInput;
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) AVCaptureSession *session;

- (void)change;
- (void)up;
- (void)down;
- (void)stop;
- (void)forward;
- (void)backward;
- (void)right;
- (void)left;
- (void)photo;
- (void)light:(bool)on;
- (void)say;

- (void)connectToScratch;
- (void)setupAVCapture;

- (void)startMonitoringAudio;
- (void)stopMonitoringAudio;
- (void)pauseMonitoringAudio;
- (void)resumeMonitoringAudio;

- (void)updateHeading;

@end

