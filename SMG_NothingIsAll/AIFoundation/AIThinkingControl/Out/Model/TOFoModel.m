//
//  TOFoModel.m
//  SMG_NothingIsAll
//
//  Created by jia on 2019/1/30.
//  Copyright © 2019年 XiaoGang. All rights reserved.
//

#import "TOFoModel.h"

@implementation TOFoModel

-(NSMutableArray *)actions{
    if (!_actions) _actions = [[NSMutableArray alloc] init];
    return _actions;
}

@end
