//
//  Output.m
//  SMG_NothingIsAll
//
//  Created by 贾  on 2017/4/27.
//  Copyright © 2017年 XiaoGang. All rights reserved.
//

#import "Output.h"
#import "AINetUtils.h"
#import "NSObject+Extension.h"
#import "AIKVPointer.h"
#import "AIAlgNodeBase.h"
#import "OutputUtils.h"
#import "OutputModel.h"
#import "AINetIndex.h"

@implementation Output

+(BOOL) output_FromTC:(AIKVPointer*)algNode_p {
    //1. 数据
    AIAlgNodeBase *algNode = [SMGUtils searchNode:algNode_p];
    if (!ISOK(algNode, AIAlgNodeBase.class)) {
        return false;
    }
    
    //2. 循环微信息组
    NSMutableArray *valids = [[NSMutableArray alloc] init];
    NSArray *mic_ps = [SMGUtils convertValuePs2MicroValuePs:algNode.content_ps];
    for (AIKVPointer *value_p in mic_ps) {
        
        //3. 取dataSource & algsType
        //TODOTOMORROW: 此处取得dataSource = @" ",所以,导致"吃"输出失败,,,,,,,,
        NSString *identify = value_p.algsType;
        if (!value_p.isOut) {
            identify = [OutputUtils convertOutType2dataSource:value_p.algsType];
            WLog(@"调试下,何时会输出isOut=false的内容");
        }
        
        //4. 检查可输出"某数据类型"并收集
        if ([AINetUtils checkCanOutput:identify]) {
            OutputModel *model = [[OutputModel alloc] init];
            model.identify = identify;
            model.data = NUMTOOK([AINetIndex getData:value_p]);
            [theNV setNodeData:value_p appendLightStr:@"o4"];
            [valids addObject:model];
        }
    }
    
    //5. 执行输出
    if (ARRISOK(valids)) {
        [self output_General:valids logBlock:^{
            //6. 将输出入网
            [theTC commitOutputLog:valids];
        }];
        return true;
    }
    
    return false;
}

+(void) output_FromReactor:(NSString*)identify datas:(NSArray*)datas{
    //1. 转为outModel
    NSMutableArray *models = [[NSMutableArray alloc] init];
    for (NSNumber *data in ARRTOOK(datas)) {
        OutputModel *model = [[OutputModel alloc] init];
        model.identify = STRTOOK(identify);
        model.data = NUMTOOK(data);
        [models addObject:model];
    }
    
    //2. 传递到output执行
    if (ARRISOK(models)) {
        [Output output_General:models logBlock:^{
            //3. 将输出入网
            [theTC commitOutputLog:models];
        }];
    }
}

+(void) output_FromMood:(AIMoodType)type{
    if (type == AIMoodType_Anxious) {
        //1. 生成outputModel
        OutputModel *model = [[OutputModel alloc] init];
        model.identify = ANXIOUS_RDS;
        model.data = @(1);
        
        //2. 输出
        [self output_General:@[model] logBlock:^{
            //3. 将输出mood提交给tc
            [AIInput commitIMV:MVType_Anxious from:10 to:3];
        }];
    }else if(type == AIMoodType_Satisfy){
        [[NSNotificationCenter defaultCenter] postNotificationName:kOutputObserver object:@{kOOIdentify:SATISFY_RDS}];
    }
}

//MARK:===============================================================
//MARK:                     < privateMethod >
//MARK:===============================================================

/**
 *  MARK:--------------------actions输出--------------------
 *  @desc 含: 反射被动输出 和 TC主动输出
 *  @param outputModels : OutputModel数组;
 *  如: 吸吮,抓握
 *  注: 先天,被动
 */
+(void) output_General:(NSArray*)outputModels logBlock:(void(^)())logBlock{
    //1. 广播执行输出前;
    for (OutputModel *model in ARRTOOK(outputModels)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kOutputObserver object:@{kOOIdentify:STRTOOK(model.identify),kOOParam:NUMTOOK(model.data),kOOType:@(OutputObserverType_Front)}];
    }
    
    //2. 将输出入网
    logBlock();
    
    //3. 广播执行输出后;
    for (OutputModel *model in ARRTOOK(outputModels)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kOutputObserver object:@{kOOIdentify:STRTOOK(model.identify),kOOParam:NUMTOOK(model.data),kOOType:@(OutputObserverType_Back)}];
    }
}

@end
