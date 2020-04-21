//
//  TOUtils.m
//  SMG_NothingIsAll
//
//  Created by jia on 2020/4/2.
//  Copyright © 2020年 XiaoGang. All rights reserved.
//

#import "TOUtils.h"
#import "AIAlgNodeBase.h"
#import "NVHeUtil.h"
#import "AINetUtils.h"

@implementation TOUtils

+(void) findConAlg_StableMV:(AIAlgNodeBase*)curAlg curFo:(AIFoNodeBase*)curFo itemBlock:(BOOL(^)(AIAlgNodeBase* validAlg))itemBlock{
    //1. 取概念和时序的具象端口;
    if (!itemBlock) return;
    NSArray *conAlg_ps = [SMGUtils convertPointersFromPorts:[AINetUtils conPorts_All:curAlg]];
    NSArray *conFo_ps = [SMGUtils convertPointersFromPorts:[AINetUtils conPorts_All:curFo]];
    
    //2. 筛选具象概念,将合格的回调返回;
    for (AIKVPointer *conAlg_p in conAlg_ps) {
        //a. 根据具象概念,取被哪些时序引用了;
        AIAlgNodeBase *conAlg = [SMGUtils searchNode:conAlg_p];
        NSArray *conAlgRef_ps = [SMGUtils convertPointersFromPorts:[AINetUtils refPorts_All4Alg:conAlg]];
        
        //b. 被引用的时序是curFo的具象时序,则有效;
        NSArray *validRef_ps = [SMGUtils filterSame_ps:conAlgRef_ps parent_ps:conFo_ps];
        if (validRef_ps.count > 0) {
            BOOL goOn = itemBlock(conAlg);
            if (!goOn) return;
        }
    }
}

+(BOOL) mIsC:(AIAlgNodeBase*)m c:(AIAlgNodeBase*)c{
    if (m && c) {
        //1. 判断本级相等;
        BOOL equ0 = [m.pointer isEqual:c.pointer];
        if (equ0) return true;
        
        //2. 判断一级抽象;
        NSArray *mAbs = [SMGUtils convertPointersFromPorts:[AINetUtils absPorts_All_Normal:m]];
        BOOL equ1 = [mAbs containsObject:c.pointer];
        if (equ1) return true;
        
        //3. 判断二级抽象;
        NSArray *cCon = [SMGUtils convertPointersFromPorts:[AINetUtils conPorts_All:c]];
        BOOL equ2 = [SMGUtils filterSame_ps:mAbs parent_ps:cCon].count > 0;
        if (equ2) return true;
    }
    return false;
}

+(NSArray*) getAlgAllPlusAllValue_ps:(AIAlgNodeBase*)alg{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (alg) {
        NSArray *plus_ps = [SMGUtils convertPointersFromPorts:[AINetUtils absPorts_All:alg type:AnalogyType_DiffPlus]];
        NSArray *plusAlgs = [SMGUtils searchNodes:plus_ps];
        for (AIAlgNodeBase *item in plusAlgs) [result addObjectsFromArray:item.content_ps];
    }
    return result;
}

@end
