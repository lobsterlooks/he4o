//
//  AIAlgNodeManager.m
//  SMG_NothingIsAll
//
//  Created by jia on 2018/12/14.
//  Copyright © 2018年 XiaoGang. All rights reserved.
//

#import "AIAlgNodeManager.h"
#import "AIAlgNode.h"
#import "AIAbsAlgNode.h"
#import "AIPort.h"
#import "AIKVPointer.h"
#import "AINetUtils.h"
#import "NSString+Extension.h"
#import "AINetIndexUtils.h"

@implementation AIAlgNodeManager

+(AIAlgNode*) createAlgNode:(NSArray*)algsArr isOut:(BOOL)isOut isMem:(BOOL)isMem{
    NSString *dataSource = [self getDataSource:algsArr];
    return [self createAlgNode:algsArr dataSource:dataSource isOut:isOut isMem:isMem];
}
+(AIAlgNode*) createAlgNode:(NSArray*)algsArr dataSource:(NSString*)dataSource isOut:(BOOL)isOut isMem:(BOOL)isMem{
    //1. 数据
    algsArr = ARRTOOK(algsArr);
    
    //2. 构建具象节点 (优先用本地已有,否则new)
    AIAlgNode *conNode = [[AIAlgNode alloc] init];
    conNode.pointer = [SMGUtils createPointerForAlg:kPN_ALG_NODE dataSource:dataSource isOut:isOut isMem:isMem];
    
    //3. 指定value_ps
    conNode.content_ps = [[NSMutableArray alloc] initWithArray:[SMGUtils sortPointers:algsArr]];
 
    //4. value.refPorts (更新引用序列)
    [AINetUtils insertRefPorts_AllAlgNode:conNode.pointer content_ps:conNode.content_ps difStrong:1];
    
    //5. 存储
    [SMGUtils insertNode:conNode];
    [theApp.heLogView addLog:STRFORMAT(@"构建具象概念:%@,存储于:%d,内容数:%lu",conNode.pointer.identifier,conNode.pointer.isMem,(unsigned long)conNode.content_ps.count)];
    return conNode;
}

/**
 *  MARK:--------------------构建抽象概念--------------------
 *  @问题记录:
 *    1. 思考下,conAlgs中去重,能不能将md5匹配的conAlg做为absAlg的问题?
 *      a. 不能: (参考: 思考计划2/191126更新表)
 *      b. 能: (则导致会形成坚果是坚果的多层抽象)
 *      c. 结论: 能,问题转移到n17p19
 */
+(AIAbsAlgNode*) createAbsAlgNode:(NSArray*)value_ps conAlgs:(NSArray*)conAlgs dataSource:(NSString*)dataSource isMem:(BOOL)isMem{
    if (!dataSource) {
        dataSource = [self getDataSource:value_ps];
    }
    if (ARRISOK(value_ps) && ARRISOK(conAlgs)) {
        //1. 数据准备
        value_ps = ARRTOOK(value_ps);
        NSArray *sortSames = ARRTOOK([SMGUtils sortPointers:value_ps]);
        NSString *samesStr = [SMGUtils convertPointers2String:sortSames];
        NSString *samesMd5 = STRTOOK([NSString md5:samesStr]);
        NSMutableArray *validConAlgs = [[NSMutableArray alloc] initWithArray:conAlgs];
        AIAbsAlgNode *findAbsNode = nil;
        
        //2. 判断具象节点中,已有一个抽象sames节点,则不需要再构建新的;
        for (AIAbsAlgNode *checkNode in conAlgs) {
            //a. checkNode是抽象节点时;
            if (ISOK(checkNode, AIAbsAlgNode.class)) {
                
                //b. 并且md5与orderSames相同时,即发现checkNode本身就是抽象节点;
                NSString *checkMd5 = STRTOOK([NSString md5:[SMGUtils convertPointers2String:[SMGUtils sortPointers:checkNode.content_ps]]]);
                if ([samesMd5 isEqualToString:checkMd5]) {
                    
                    //c. 则把conAlgs去掉checkNode;
                    [validConAlgs removeObject:checkNode];
                    
                    //d. 找到findAbsNode
                    findAbsNode = checkNode;
                }
            }
        }
        
        //2. 判断具象节点的absPorts中,是否已有一个"sames"节点,有则无需构建新的;
        for (AIAlgNodeBase *conNode in conAlgs) {
            NSArray *absPorts_All = [AINetUtils absPorts_All:conNode];
            for (AIPort *absPort in absPorts_All) {
                //1> 遍历找抽象是否已存在;
                if ([samesMd5 isEqualToString:absPort.header]) {
                    AIAbsAlgNode *absNode = [SMGUtils searchNode:absPort.target_p];
                    //2> 已存在,则转移到硬盘网络;
                    if (absNode.pointer.isMem) {
                        absNode = [AINetUtils move2HdNodeFromMemNode_Alg:absNode];
                    }
                    //3> findAbsNode成功;
                    findAbsNode = absNode;
                    if (!ISOK(absNode, AIAbsAlgNode.class) ) {
                        WLog(@"发现非抽象类型的抽象节点错误,,,请检查出现此情况的原因;");
                    }
                    if (findAbsNode.content_ps.count != value_ps.count) {
                        NSLog(@"");//精训第6步A10长度为0的问题断点;
                    }
                    break;
                }
            }
        }
        
        //3. 无则创建
        BOOL absIsNew = false;
        if (!findAbsNode) {
            absIsNew = true;
            findAbsNode = [[AIAbsAlgNode alloc] init];
            BOOL isOut = [AINetUtils checkAllOfOut:sortSames];
            findAbsNode.pointer = [SMGUtils createPointerForAlg:kPN_ALG_ABS_NODE dataSource:dataSource isOut:isOut isMem:isMem];
            findAbsNode.content_ps = [[NSMutableArray alloc] initWithArray:sortSames];
        }
        
        ////4. 概念的嵌套 (190816取消概念嵌套,参见n16p17-bug16)
        //for (AIAlgNode *item in conAlgs) {
        //    ///1. 可替换时,逐个进行替换; (比如cLess/cGreater时,就不可替换)
        //    if ([SMGUtils containsSub_ps:value_ps parent_ps:item.content_ps]) {
        //        NSMutableArray *newValue_ps = [SMGUtils removeSub_ps:value_ps parent_ps:[[NSMutableArray alloc] initWithArray:item.content_ps]];
        //        [newValue_ps addObject:findAbsNode.pointer];
        //        item.content_ps = [SMGUtils sortPointers:newValue_ps];
        //    }
        //}
        
        //4. value.refPorts (更新/加强微信息的引用序列)
        NSInteger difStrong = 1;//absIsNew ? validConAlgs.count : 1;//20200106改回1,自由竞争无论是抽象还是具象;世上没有两片一样的树叶,所以对于抽象来说,本来就是讨便宜,易联想匹配的;
        [AINetUtils insertRefPorts_AllAlgNode:findAbsNode.pointer content_ps:findAbsNode.content_ps difStrong:difStrong];
        
        //5. 关联 & 存储
        [AINetUtils relateAlgAbs:findAbsNode conNodes:validConAlgs];
        [theApp.heLogView addLog:STRFORMAT(@"构建抽象概念:%@,存储于:%d,内容数:%lu",findAbsNode.pointer.identifier,findAbsNode.pointer.isMem,(unsigned long)findAbsNode.content_ps.count)];
        
        return findAbsNode;
    }
    return nil;
}

/**
 *  MARK:--------------------构建抽象概念_防重--------------------
 */
+(AIAbsAlgNode*)createAbsAlg_NoRepeat:(NSArray*)value_ps conAlgs:(NSArray*)conAlgs ds:(NSString*)ds isMem:(BOOL)isMem{
    //1. 数据检查
    value_ps = ARRTOOK(value_ps);
    NSArray *sort_ps = [SMGUtils sortPointers:value_ps];
    
    //2. 去重找本地 (仅抽象);
    AIAbsAlgNode *localAlg = [AINetIndexUtils getAbsoluteMatching_General:value_ps sort_ps:sort_ps except_ps:nil getRefPortsBlock:^NSArray *(AIKVPointer *item_p) {
        NSArray *refPorts = [AINetUtils refPorts_All4Value:item_p];
        NSMutableArray *result = [[NSMutableArray alloc] init];
        for (AIPort *refPort in refPorts) {
            if ([kPN_ALG_ABS_NODE isEqualToString:refPort.target_p.folderName]) {
                [result addObject:refPort];
            }
        }
        return result;
    }];
    
    //3. 有则加强;
    if (ISOK(localAlg, AIAbsAlgNode.class)) {
        [AINetUtils relateAlgAbs:localAlg conNodes:conAlgs];
        //4. 向硬盘转移
        if (!isMem) localAlg = [AINetUtils move2HdNodeFromMemNode_Alg:localAlg];
        return localAlg;
    }else{
        //4. 无则构建
        return [self createAbsAlgNode:value_ps conAlgs:conAlgs dataSource:ds isMem:isMem];
    }
}

//MARK:===============================================================
//MARK:                     < privateMethod >
//MARK:===============================================================

//从稀疏码组中,提取概念节点的dataSource;
+(NSString*) getDataSource:(NSArray*)value_ps{
    //1. 数据准备
    value_ps = ARRTOOK(value_ps);
    NSString *dataSource = DefaultDataSource;
    
    //2. 假如全一样,提出来;
    for (NSInteger i = 0; i < value_ps.count; i++) {
        AIKVPointer *value_p = ARR_INDEX(value_ps, i);
        if (i == 0) {
            dataSource = value_p.algsType;
        }else if([dataSource isEqualToString:value_p.algsType]){
            dataSource = DefaultDataSource;
        }
    }
    return dataSource;
}

@end

/**
 *  MARK:--------------------查找网络中即有具象节点--------------------
 *  注: 性能优化:如果在查找过程中,共同具象节点有上百个,而又因数量等不符合,则会有卡在IO上的可能;所以此处届时可考虑使用二分法索引等来优化;
 */
//+(AIAlgNode*) findLocalConNode:(NSArray*)absNodes{
//    //1.  数据准备
//    absNodes = ARRTOOK(absNodes);
//    AIAlgNode *result = nil;
//
//    //2. 筛选出conPort最短的absNode;
//    AIAbsAlgNode *minNode = nil;
//    for (AIAbsAlgNode *absNode in absNodes) {
//        if (minNode == nil || minNode.conPorts.count > absNode.conPorts.count) {
//            minNode = absNode;
//        }
//    }
//
//    //3. 正向查找出absAlgNodes的共同关联的具象节点;
//    if (minNode) {
//        ///1. 循环查最小absNode的"具象路由";
//        for (AIPort *checkPort in minNode.conPorts) {
//            AIPointer *checkPointer = checkPort.target_p;
//
//            ///2. 检查是否 同时存在所有其它absNode的"具象路由"中;
//            BOOL checkSuccess = true;
//            for (AIAbsAlgNode *item in absNodes) {
//                if (![item isEqual:minNode]) {
//                    NSArray *con_ps = [SMGUtils convertPointersFromPorts:item.conPorts];
//                    if (![SMGUtils containsSub_p:checkPointer parent_ps:con_ps]) {
//                        checkSuccess = false;
//                        break;
//                    }
//                }
//            }
//
//            ///3. 反过来检查 "找到的具象节点" 是否也指向 "这些抽象节点";
//            if (checkSuccess) {
//                BOOL singleSuccess = true;
//                AIAlgNode *single = [SMGUtils searchObjectForPointer:checkPointer fileName:kFNNode time:cRTNode];
//                if (ISOK(single, AIAlgNode.class) && single.absPorts.count == absNodes.count) {
//                    NSArray *single_ps = [SMGUtils convertPointersFromPorts:single.absPorts];
//                    for (AIAbsAlgNode *absNode in absNodes) {
//                        if (![SMGUtils containsSub_p:absNode.pointer parent_ps:single_ps]) {
//                            singleSuccess = false;
//                            break;
//                        }
//                    }
//                }
//
//                ///4. 正反搜索都匹配,则重复使用;
//                if (singleSuccess) {
//                    result = single;
//                    break;
//                }
//            }
//        }
//    }
//    return result;
//}
