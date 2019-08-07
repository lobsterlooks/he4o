//
//  BirdView.m
//  SMG_NothingIsAll
//
//  Created by jiaxiaogang on 2018/11/7.
//  Copyright © 2018年 XiaoGang. All rights reserved.
//

#import "BirdView.h"
#import "MASConstraint.h"
#import "View+MASAdditions.h"
#import "FoodView.h"
#import "AIReactorControl.h"

@interface BirdView ()

@property (strong,nonatomic) IBOutlet UIView *containerView;

@end

@implementation BirdView

-(id) init {
    self = [super init];
    if(self != nil){
        [self initView];
        [self initDisplay];
    }
    return self;
}

-(void) initView{
    //self
    [self setBackgroundColor:[UIColor clearColor]];
    [self setFrame:CGRectMake(100, 100, 30, 30)];
    
    //containerView
    [[NSBundle mainBundle] loadNibNamed:NSStringFromClass(self.class) owner:self options:nil];
    [self addSubview:self.containerView];
    [self.containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.mas_equalTo(self);
        make.trailing.mas_equalTo(self);
        make.top.mas_equalTo(self);
        make.bottom.mas_equalTo(self);
    }];
}

-(void) initDisplay{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outputObserver:) name:kOutputObserver object:nil];
}

//MARK:===============================================================
//MARK:                     < method >
//MARK:===============================================================

-(void) fly:(CGFloat)value{
    value = MAX(MIN(1, value), 0);
    value = value * 2 - 1;
    CGFloat angle = value * M_PI;
    //以右为0度,逆时针为负,顺时针为正;
    //对边Y,邻边X
    NSLog(@"fly >> y:%f x:%f angle:%f",sin(angle),cos(angle),value * 180);
    [self setX:self.x + (cos(angle) * 10.0f)];
    [self setY:self.y + (sin(angle) * 10.0f)];
}

-(void) see:(UIView*)view{
    if (self.delegate && [self.delegate respondsToSelector:@selector(birdView_GetSeeRect)]) {
        //1. 将视觉范围下,的视觉信息输入大脑;
        CGRect rect = [self.delegate birdView_GetSeeRect];
        [AIInput commitView:self targetView:view rect:rect];
    }
}

-(void) touchMouth{
    [AIReactorControl commitReactor:EAT_RDS];
}

-(void) touchWing{
    //1. 飞前视觉
    [self see:[self.delegate birdView_GetPageView]];
    
    //2. 反射飞行
    float random = (arc4random() % 8) / 8.0f;
    [AIReactorControl commitReactor:FLY_RDS datas:@[@(random)]];
}

-(void) dropUp{
    
}

-(void) dropDown{
    
}

-(void) dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void) eat:(CGFloat)value{
    if (self.delegate && [self.delegate respondsToSelector:@selector(birdView_GetFoodOnMouth)]) {
        //1. 嘴附近的食物
        UIView *pageView = [self.delegate birdView_GetPageView];
        FoodView *foodView = [self.delegate birdView_GetFoodOnMouth];
        if (!foodView) return;
        
        //2. 视觉输入
        [self see:pageView];
        
        //3. 吃掉 (让he以吸吮反射的方式,去主动吃;并将out入网,以抽象出"吃"的节点;参考n15p6-QT1)
        [foodView removeFromSuperview];
        [self see:pageView];
        
        //4. 产生HungerMindValue; (0-10)
        [AIInput commitIMV:MVType_Hunger from:1.0f to:9.0f];
    }
}

//MARK:===============================================================
//MARK:                     < outputObserver >
//MARK:===============================================================
-(void) outputObserver:(NSNotification*)notification{
    if (notification) {
        //1. 取数据
        NSDictionary *obj = DICTOOK(notification.object);
        NSString *rds = STRTOOK([obj objectForKey:@"rds"]);
        NSNumber *paramNum = NUMTOOK([obj objectForKey:@"paramNum"]);
        
        //2. 吸吮反射
        if ([EAT_RDS isEqualToString:rds]) {
            [self eat:[paramNum floatValue]];
        }else if([FLY_RDS isEqualToString:rds]){
            //3. 扇翅膀反射
            [self fly:[paramNum floatValue]];
            
            //3. 飞后视觉
            [self see:[self.delegate birdView_GetPageView]];
        }else if([ANXIOUS_RDS isEqualToString:rds]){
            //4. 飞前视觉
            //[self see:[self.delegate birdView_GetPageView]];
            //4. 小鸟焦急时_扇翅膀;
            //CGFloat data = (arc4random() % 8) / 8.0f;
            //[AIReactorControl commitReactor:FLY_RDS datas:@[@(data)]];
            
            //4. 190731由飞改为叫;
            [theApp setTipLog:@"叽叽喳喳叫一叫"];
        }
    }
}

@end

