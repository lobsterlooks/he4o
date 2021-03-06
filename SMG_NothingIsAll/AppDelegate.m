//
//  AppDelegate.m
//  SMG_NothingIsAll
//
//  Created by 贾  on 2017/4/7.
//  Copyright © 2017年 XiaoGang. All rights reserved.
//

#import "AppDelegate.h"
#import "MainPage.h"
#import "AINet.h"
#import "NSObject+Extension.h"
#import "AIKVPointer.h"
#import "NVDelegate_He.h"
#import "HeLogView.h"

@interface AppDelegate ()

@property (strong, nonatomic) UILabel *tipLogLab;
@property (strong, nonatomic) UIButton *openHeLogBtn;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    //1. Path
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSLog(@"%@",paths[0]);
    
    //2. 初始化UI
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];
    MainPage *page = [[MainPage alloc] init];
    UINavigationController *naviC = [[UINavigationController alloc] initWithRootViewController:page];
    [self.window setRootViewController:naviC];
    [self.window makeKeyAndVisible];
    
    //3. heLogView打开按钮
    self.openHeLogBtn = [[UIButton alloc] initWithFrame:CGRectMake(ScreenWidth - 82, StateBarHeight, 40, 20)];
    [self.openHeLogBtn.titleLabel setFont:[UIFont systemFontOfSize:15]];
    [self.openHeLogBtn setTitleColor:UIColorWithRGBHex(0x0000EE) forState:UIControlStateNormal];
    [self.openHeLogBtn setBackgroundColor:UIColorWithRGBHex(0xEEFFEE)];
    [self.openHeLogBtn setTitle:@"LOG" forState:UIControlStateNormal];
    [self.openHeLogBtn addTarget:self action:@selector(openHeLogBtnOnClick:) forControlEvents:UIControlEventTouchUpInside];
    [self.window addSubview:self.openHeLogBtn];
    
    //4. 神经网络可视化
    self.nvView = [[NVView alloc] initWithDelegate:[NVDelegate_He new]];
    [self.nvView setAlpha:0.9f];
    [self.window addSubview:self.nvView];
    
    //5. heLogView
    self.heLogView = [[HeLogView alloc] init];
    [self.window addSubview:self.heLogView];
    
    //6. tipLogLab
    self.tipLogLab = [[UILabel alloc] initWithFrame:CGRectMake(0, ScreenHeight - 11, ScreenWidth, 11)];
    [self.tipLogLab setFont:[UIFont boldSystemFontOfSize:11]];
    [self.tipLogLab setTextColor:[UIColor redColor]];
    [self.window addSubview:self.tipLogLab];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {}

- (void)applicationDidEnterBackground:(UIApplication *)application {}

- (void)applicationWillEnterForeground:(UIApplication *)application {}

- (void)applicationDidBecomeActive:(UIApplication *)application {}

- (void)applicationWillTerminate:(UIApplication *)application {}

//MARK:===============================================================
//MARK:                     < method >
//MARK:===============================================================
-(UIViewController*) getTopDisplayViewController{
    UINavigationController *navC = (UINavigationController*)[self.window rootViewController];    
    NSArray *controllers = navC.viewControllers;
    UIViewController *controller = [controllers lastObject];
    return controller;
}

-(void) setTipLog:(NSString*)tipLog{
    [self.tipLogLab setText:STRTOOK(tipLog)];
}

//MARK:===============================================================
//MARK:                     < privateMethod >
//MARK:===============================================================
-(void) openHeLogBtnOnClick:(id)btn{
    [self.heLogView open];
}

@end
