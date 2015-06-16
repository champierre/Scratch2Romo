//
//  AppDelegate.h
//  scratch2romo
//
//  Created by Ishihara Junya on 2014/11/26.
//  Copyright (c) 2014年 Tsukurusha. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) CLLocationManager* locationManager;
@property (retain, nonatomic) ViewController *viewController;

@property CLLocationDirection heading;

@end

