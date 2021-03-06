//
//  TOAlgScheme.m
//  SMG_NothingIsAll
//
//  Created by jia on 2019/4/19.
//  Copyright © 2019年 XiaoGang. All rights reserved.
//

#import "TOAlgScheme.h"
#import "ThinkingUtils.h"
#import "AIKVPointer.h"
#import "AIAbsAlgNode.h"
#import "AINetAbsFoNode.h"
#import "AIPort.h"
#import "AINetIndex.h"
#import "AIShortMatchModel.h"
#import "AINetIndexUtils.h"
#import "AINetUtils.h"
#import "AIAlgNode.h"
//temp
#import "NVHeUtil.h"
#import "TOUtils.h"

@interface TOAlgScheme()

@property (strong, nonatomic) AIShortMatchModel *shortMatchModel;

@end

@implementation TOAlgScheme

-(void)setData:(AIShortMatchModel *)shortMatchModel{
    self.shortMatchModel = shortMatchModel;
}

//MARK:===============================================================
//MARK:                     < FO & ALG >
//MARK:===============================================================

/**
 *  MARK:--------------------对一个rangeOrder进行行为化;--------------------
 *  @desc 一些记录:
 *      1. 191105总结下,此处有多少处,使用短时,长时,在前面插入瞬时;
 *      2. 191105针对概念嵌套的代码,先去掉;
 *      3. 191107考虑将foScheme也搬过来,优先使用matchFo做第一解决方案;
 *  @TODO_TEST_HERE: 测试下阈值-3,是否合理;
 */
-(void) convert2Out_Fo:(NSArray*)curAlg_ps curFo:(AIFoNodeBase*)curFo success:(void(^)(NSArray *acts))success failure:(void(^)())failure {
    //1. 数据准备
    NSLog(@"STEPKEY============================== 行为化 START ==================== \nSTEPKEY时序:%@->%@\nSTEPKEY需要:[%@]",Fo2FStr(curFo),Mvp2Str(curFo.cmvNode_p),Pits2FStr(curAlg_ps));
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (!ARRISOK(curAlg_ps) || curFo == nil) {
        failure();
        WLog(@"fo行为化失败,参数无效");
    }
    if (![self.delegate toAlgScheme_EnergyValid]) {
        failure();
        WLog(@"思维活跃度耗尽,无法决策行为化");
    }
    
    //2. 依次单个概念行为化
    for (AIKVPointer *curAlg_p in curAlg_ps) {
        __block BOOL successed = false;
        [self convert2Out_Alg:curAlg_p curFo:curFo type:ATHav success:^(NSArray *actions) {
            //3. 行为化成功,则收集;
            successed = true;
            [result addObjectsFromArray:actions];
        } failure:^{
            WLog(@"行为化失败");
        } checkScore:^BOOL(AIAlgNodeBase *mAlg) {
            if (mAlg) {
                //5. MC反思: 用curAlg_ps + matchAlg组成rethinkAlg_ps
                NSMutableArray *rethinkAlg_ps = [[NSMutableArray alloc] initWithArray:curFo.content_ps];
                NSInteger replaceIndex = [rethinkAlg_ps indexOfObject:curAlg_p];
                [rethinkAlg_ps replaceObjectAtIndex:replaceIndex withObject:mAlg.pointer];
                
                //6. MC反思: 回归tir反思,重新识别理性预测时序,预测价值; (预测到鸡蛋变脏,或者cpu损坏) (理性预测影响评价即理性评价)
                AIShortMatchModel *mModel = [self.delegate toAlgScheme_LSPRethink:mAlg rtFoContent_ps:rethinkAlg_ps];
                
                //7. MC反思: 对mModel进行评价;
                AIKVPointer *mMv_p = mModel.matchFo.cmvNode_p;
                CGFloat mcScore = [ThinkingUtils getScoreForce:mMv_p ratio:mModel.matchFoValue];
                
                //8. 对原fo进行评价
                AIKVPointer *cMv_p = curFo.cmvNode_p;
                CGFloat curScore = [ThinkingUtils getScoreForce:cMv_p ratio:1.0f];
                
                //9. 写评价时所需要,"设定的"的计算算法;
                
                //10. 如果mv同区,只要为负则失败;
                if (mMv_p && cMv_p) {
                    if ([mMv_p.algsType isEqualToString:cMv_p.algsType] && [mMv_p.dataSource isEqualToString:cMv_p.dataSource] && mcScore < 0) {
                        return false;
                    }
                }
                
                //11. 如果不同区,对mcScore和curScore返回评价值进行类比 (如宁饿死不吃屎);
                CGFloat validDelta = -3;//阈值为-3;
                return curScore + mcScore > validDelta;
            }
            //11. 默认返回可行;
            return true;
        }];
        
        //4. 有一个失败,则整个rangeOrder失败;)
        if (!successed) {
            [theNV setNodeData:curAlg_p lightStr:@"行为化失败"];
            failure();
            return;
        }
        [theNV setNodeData:curAlg_p lightStr:@"行为化成功"];
    }
    
    //5. 成功回调,每成功一次fo,消耗1格活跃值;
    [self.delegate toAlgScheme_updateEnergy:-1];
    NSLog(@"----> 输出行为:[%@]",[NVHeUtil getLightStr4Ps:result]);
    success(result);
}


/**
 *  MARK:--------------------单个概念的行为化--------------------
 *  第1级: 直接判定curAlg_p为输出则收集;
 *  第2级: MC匹配行为化
 *  第3级: LongNet长短时网络行为化
 *  @param type : ATHav或ATNone
 *  @param curAlg_p : 三个来源: 1.Fo的元素A;  2.Range的元素A; 3.Alg的嵌套A;
 */
-(void) convert2Out_Alg:(AIKVPointer*)curAlg_p curFo:(AIFoNodeBase*)curFo type:(AnalogyType)type success:(void(^)(NSArray *actions))success failure:(void(^)())failure checkScore:(BOOL(^)(AIAlgNodeBase *mAlg))checkScore{
    //1. 数据准备;
    if (!curAlg_p) {
        failure();
    }
    if (type != ATHav && type != ATNone) {
        WLog(@"SingleAlg_行为化类参数type错误");
        failure();
    }
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    //2. 本身即是isOut时,直接行为化返回;
    if (curAlg_p.isOut) {
        [result addObject:curAlg_p];
        NSLog(@"-> isOut为TRUE: %@",[NVHeUtil getLightStr:curAlg_p]);
        success(result);
        return;
    }else{
        AIAlgNodeBase *curAlg = [SMGUtils searchNode:curAlg_p];
        if (self.shortMatchModel && curAlg) {
            //3. 单ATHav时,直接从瞬时做MC匹配行为化;
            __block BOOL successed = false;
            if (type == ATHav) {
                [self convert2Out_Short_MC_V3:curAlg curFo:curFo complete:^(NSArray *acts, BOOL v3Success) {
                    if (v3Success) {
                        [result addObjectsFromArray:acts];
                        successed = true;
                        NSLog(@"--> MC_行为化成功: 长度:%lu 行为:[%@]",(unsigned long)acts.count,[NVHeUtil getLightStr4Ps:acts]);
                        success(result);
                    }else{
                        WLog(@"MC_行为化失败");
                    }
                }];
            }
            
            //4. mc行为化失败,则联想长时行为化;
            if (!successed) {
                [self convert2Out_Long_NET:type at:curAlg_p.algsType ds:curAlg_p.dataSource success:^(AIFoNodeBase *havFo, NSArray *actions) {
                    //4. hnAlg行为化成功;
                    [result addObjectsFromArray:actions];
                    NSLog(@"---> HN_行为化成功: 长度:%lu 行为:[%@]",(unsigned long)actions.count,[NVHeUtil getLightStr4Ps:actions]);
                    success(result);
                    successed = true;
                } failure:^{
                    //20191120: _sub方法废弃; 第3级: 对curAlg的(subAlg&subValue)分别判定; (目前仅支持a2+v1各一个)
                    //NSArray *subResult = ARRTOOK([self convert2Out_Single_Sub:curAlg_p]);
                    //[result addObjectsFromArray:subResult];
                    //8. 未联想到hnAlg,失败;
                    WLog(@"长时_行为化失败");
                }];
            }
            if (successed) return;
        }
    }
    failure();
}


//MARK:===============================================================
//MARK:                     < ShortMC & LongNET >
//MARK:===============================================================

/**
 *  MARK:--------------------"相对概念"的行为化--------------------
 *  1. 先根据havAlg取到havFo;
 *  2. 再判断havFo中的rangeOrder的行为化;
 *  3. 思考: 是否做alg局部匹配,递归取3个左右,逐个取并取其ATHav (并类比缺失部分,循环); (191120废弃,不做)
 *  @param success : 行为化成功则返回(havFo + 行为序列); (havFo notnull, actions notnull)
 */
-(void) convert2Out_Long_NET:(AnalogyType)type at:(NSString*)at ds:(NSString*)ds success:(void(^)(AIFoNodeBase *havFo,NSArray *actions))success failure:(void(^)())failure {
    //1. 数据准备
    AIAlgNodeBase *hnAlg = [ThinkingUtils dataOut_GetAlgNodeWithInnerType:type algsType:at dataSource:ds];
    if (!hnAlg) {
        //2. 未联想到hnAlg,失败;
        failure();
        return;
    }
    
    //2. 找引用"相对概念"的内存中"相对时序",并行为化; (注: 一般不存在内存相对概念,此处代码应该不会执行);
    NSArray *memRefPorts = [SMGUtils searchObjectForPointer:hnAlg.pointer fileName:kFNMemRefPorts time:cRTMemPort];
    __block BOOL successed = false;
    [self convert2Out_RelativeFo_ps:[SMGUtils convertPointersFromPorts:memRefPorts] success:^(AIFoNodeBase *havFo, NSArray *actions) {
        successed = true;
        success(havFo,actions);
    } failure:^{
        WLog(@"相对概念,行为化失败");
    }];
    
    //3. 根据havAlg联想时序,并找出新的解决方案,与新的行为化的概念,与新的条件概念;
    if (!successed) {
        NSArray *hdRefPorts = ARR_SUB(hnAlg.refPorts, 0, cHavNoneAssFoCount);
        [self convert2Out_RelativeFo_ps:[SMGUtils convertPointersFromPorts:hdRefPorts] success:^(AIFoNodeBase *havFo, NSArray *actions) {
            successed = true;
            success(havFo,actions);
        } failure:^{
            WLog(@"相对概念,行为化失败");
        }];
        
        //4. 行为化失败;
        if (!successed) {
            failure();
        }
    }
}


//MARK:===============================================================
//MARK:             < RelativeValue & RelativeFo >
//MARK:===============================================================
/**
 *  MARK:--------------------对单稀疏码的变化进行行为化--------------------
 *  @desc 伪代码:
 *  1. 根据type和value_p找ATLess/ATGreater
 *      2. 找不到,failure;
 *      3. 找到,判断range是否导致条件C转移;
 *          4. 未转移: success
 *          5. 转移: C条件->递归到convert2Out_Single_Alg();
 *  @param at & ds : 用作查找"大/小"的标识;
 */
-(void) convert2Out_RelativeValue:(NSString*)at ds:(NSString*)ds type:(AnalogyType)type vSuccess:(void(^)(AIFoNodeBase *glFo,NSArray *acts))vSuccess vFailure:(void(^)())vFailure {
    //1. 数据检查
    if ((type != ATGreater && type != ATLess)) {
        WLog(@"value_行为化类参数type|value_p错误");
        vFailure();
        return;
    }
    
    //2. 根据type和value_p找ATLess/ATGreater
    NSLog(@"----> RelativeValue Start at:%@ ds:%@ type:%ld",at,ds,(long)type);
    AIAlgNodeBase *glAlg = [ThinkingUtils dataOut_GetAlgNodeWithInnerType:type algsType:at dataSource:ds];
    if (!glAlg) {
        vFailure();
        return;
    }
    
    //3. 根据havAlg联想时序,并找出新的解决方案,与新的行为化的概念,与新的条件概念;
    __block BOOL successed = false;
    NSArray *hdRefPorts = ARR_SUB(glAlg.refPorts, 0, cHavNoneAssFoCount);
    [self convert2Out_RelativeFo_ps:[SMGUtils convertPointersFromPorts:hdRefPorts] success:^(AIFoNodeBase *glFo, NSArray *actions) {
        successed = true;
        vSuccess(glFo,actions);
    } failure:^{
        WLog(@"相对概念,行为化失败");
    }];
    
    //4. 行为化失败;
    if (!successed) vFailure();
}


/**
 *  MARK:--------------------"相对时序"的行为化--------------------
 *  @param relativeFo_ps    : 相对时序地址;
 *  @param success          : 回调传回: 相对时序 & 行为化结果;
 *  @param failure          : 只要有一条行为化成功则success(),否则failure();
 *  注:
 *      1. 参数: 由方法调用者保证传入的是"相对时序"而不是普通时序
 *      2. 流程: 取出相对时序,并取rangeOrder,行为化并返回
 */
-(void) convert2Out_RelativeFo_ps:(NSArray*)relativeFo_ps success:(void(^)(AIFoNodeBase *havFo,NSArray *actions))success failure:(void(^)())failure {
    //1. 数据准备
    relativeFo_ps = ARRTOOK(relativeFo_ps);
    
    //2. 逐个尝试行为化
    NSLog(@"----> RelativeFo_ps Start 目标:%@",[NVHeUtil getLightStr4Ps:relativeFo_ps]);
    for (AIPointer *relativeFo_p in relativeFo_ps) {
        AIFoNodeBase *relativeFo = [SMGUtils searchNode:relativeFo_p];
        
        //3. 取出havFo除第一个和最后一个之外的中间rangeOrder
        NSLog(@"---> RelativeFo Item 内容:%@",[NVHeUtil getLightStr4Ps:relativeFo.content_ps]);
        __block BOOL successed = false;
        if (relativeFo != nil && relativeFo.content_ps.count >= 1) {
            NSArray *foRangeOrder = ARR_SUB(relativeFo.content_ps, 0, relativeFo.content_ps.count - 1);
            
            //4. 未转移,不需要行为化;
            if (!ARRISOK(foRangeOrder)) {
                successed = true;
                success(relativeFo,nil);
            }else{
                
                //5. 转移,则进行行为化 (递归到总方法);
                [self convert2Out_Fo:foRangeOrder curFo:relativeFo success:^(NSArray *acts) {
                    successed = true;
                    success(relativeFo,acts);
                } failure:^{
                    failure();
                    WLog(@"相对时序行为化失败");
                }];
            }
        }
        
        //6. 成功一个item即可;
        if (successed) {
            return;
        }
    }
    failure();
}

@end


/**
 *  MARK:--------------------MC行为化--------------------
 *  @desc 结构说明:
 *      主: _MC_V2
 *          1: _MC_Alg
 *          2: 二级:_MC_Value
 *              2.1: _MC_Value_Multi
 *              2.2: _MC_Value_Single
 */
@implementation TOAlgScheme (MC)

/**
 *  MARK:--------------------MC匹配行为化--------------------
 *  ********** v1 **********
 *  @desc 伪代码:
 *  1. MC匹配时,判断是否可LSP里氏替换;
 *      2. 可替换,success
 *      3. 不可替换,changeM2C,判断条件为value_p.ATLess / value_p.ATGreater / alg_p.ATHav / alg_p.ATNone;
 *          4. alg_p则递归到convert2Out_Single_Alg();
 *          5. value_p则递归到convert2Out_Single_Value();
 *  @desc
 *      1. MC匹配,仅针对cHav做行为化;
 *      2. MC匹配,是对瞬时记忆中的matchAlg做匹配行为化;
 *      3. 当MC匹配转移change条件时,递归到single_Alg或single_Value进行行为化;
 *
 *  @desc
 *      1. xx年xx月xx日: matchAlg优先,都是通过抽具象关联来判断的,而不是直接对比其内容;
 *      2. 20200204: ms&cs抵消的条件,由ms.content_ps.count=cs.content_ps.count == 1改为,两者不同稀疏码长度为1;(参考18075)
 *
 *  @todo
 *      TODO_TEST_HERE: 在alg抽象匹配时,核实下将absAlg去重,为了避免绝对匹配重复导致的联想不以ATHav
 *
 *  ********** v2 **********
 *  @desc
 *      1. 运行方式: 分为GLHN四种处理方式; (Greater,Less,Hav,None)
 *      2. 主要改进: 对MC类比得到ms&cs&mcs并各进行精确的评价和行为化;
 *
 *  @desc 理性决策:
 *      1. 进行理性MC,并返回到checkScore进行理性预测评价;
 *      2. GLH为理性,因为必须满足,(其中H随后看是否需要进行评价下,比如苹果不甜,也照样能吃);
 *
 *  @实例: 用几个例子,来跑此处代码,看mAlg应该如何得来?如烤蘑菇的例子,坚果去皮的例子,cpu煎蛋的例子;
 */
-(void) convert2Out_Short_MC_V2:(AIAlgNodeBase*)curAlg curFo:(AIFoNodeBase*)curFo mcSuccess:(void(^)(NSArray *acts))mcSuccess mcFailure:(void(^)())mcFailure checkScore:(BOOL(^)(AIAlgNodeBase *mAlg))checkScore{
    //1. 数据准备
    __block BOOL failured = false;
    NSMutableArray *allActs = [[NSMutableArray alloc] init];
    NSLog(@"==========================MC START==========================");
    
    //3. 进行MC_Alg行为化;
    [self convert2Out_MC_Alg:curAlg curFo:curFo mcSuccess:^(NSArray *acts) {
        [allActs addObjectsFromArray:acts];
    } mcFailure:^{
        failured = true;
        mcFailure();
    } checkScore:checkScore];
    
    //4. 进行MC_Value行为化;
    if (!failured) {
        [self convert2Out_MC_Value_V2:curAlg curFo:curFo checkScore:checkScore complete:^(NSArray *acts, BOOL success) {
            NSLog(@"====> MC_Value complete:%d acts:(%@)",success,Pits2FStr(acts));
            [allActs addObjectsFromArray:acts];
            failured = !success;
        }];
    }
    
    //5. 完成
    if (failured) {
        mcFailure();
    }else{
        mcSuccess(allActs);
    }
}

/**
 *  MARK:--------------------MC_V3--------------------
 *  @desc 参考:n19p10;
 *      1. 废弃重组RTAlg和RTFo;
 *  @desc 算法步骤:
 *      1. 反思评价-满足C,条件如下:
 *          a. 取C中的mv+;
 *          b. 到CFo中,判断是否也包含此mv+,包含才有效;
 *          c. 再到M中判断,是否不包含此mv+ (M缺失同区不同值的mv+) ,不包含才需满足;
 *          d. 对C此值进行满足 (如C中含距0,而M中为距50);
 *      2. 反思评价-修正M,条件如下:
 *          a. 关键修正: 取M的同区mv- ,从C中找其同区稀疏码,并进行value行为化 (如M距50,C距0);
 *          b. 次要修正: 取M的不同区mv-,从CFo的conPorts中,找同区不同值,(比如找到CFo具象中,吃热食物,M中为冷食物,吃了肚子疼,行为化加热);
 *          c. 再次要修正: 取M.normalAbsPorts中不同区mv-,从....(略去,与上条b中一致);
 */
-(void) convert2Out_Short_MC_V3:(AIAlgNodeBase*)cAlg curFo:(AIFoNodeBase*)cFo complete:(void(^)(NSArray *acts,BOOL success))complete {
    //1. 结果数据准备
    NSMutableArray *acts = [[NSMutableArray alloc] init];
    
    //2. mIsC有效性判断 (MC无法加工,则直接转移);
    AIAlgNodeBase *mAlg = self.shortMatchModel.matchAlg;
    NSLog(@"STEPKEY==========================MC V3 START==========================\nSTEPKEYM:%@\nSTEPKEYC:%@",Alg2FStr(mAlg),Alg2FStr(cAlg));
    if (![TOUtils mIsC_2:mAlg.pointer c:cAlg.pointer]) {
        NSLog(@"STEPKEY===> mNotC");
        return;
    }
    
    //3. 算法数据准备
    //a. 供有效性判断1使用 (因为下层吃热食物,吃冷M会肚子疼,所以需要两层);
    NSArray *cf_P2s = [TOUtils collectAbsPs:cFo type:ATPlus conLayer:1 absLayer:0];
    //b. 供有效性判断2使用 (只需要满足Cmv+,但在M没有同区mv+的部分);
    NSArray *m_P1s = [TOUtils collectAbsPs:mAlg type:ATPlus conLayer:0 absLayer:0];
    NSArray *m_P1_vps = [TOUtils convertValuesFromAlg_ps:m_P1s];
    //c. 供有效性判断3使用 (C要求甜,M为食物,M具象有不甜的豆浆,豆浆可加糖,所以取两层);
    NSArray *m_S2s = [TOUtils collectAbsPs:mAlg type:ATSub conLayer:1 absLayer:0];
    //d. C的mv+处理 (要向具象一层,发现更多需要避免的错误,和满足的C,比如面前的冷面可吃,但要具象想一下我们只能吃热的);
    NSArray *c_P2s = [TOUtils collectAbsPs:cAlg type:ATPlus conLayer:1 absLayer:0];
    //e. 收集可满足和未满足的;
    NSMutableDictionary *cCanOut = [[NSMutableDictionary alloc] init];
    //f. 计算用于评价的价值分;
    CGFloat cScore = [ThinkingUtils getScoreForce:cFo.cmvNode_p ratio:1.0f];
    CGFloat badScore = 0;
    
    //4. 逐个判断收集;
    for (AIKVPointer *c_P2 in c_P2s) {
        //a. 有效性判断1: 到CFo中,判断是否也包含此mv+,包含才有效 (C甜,也正是要吃甜的);
        AIAlgNodeBase *cP2_Alg = [SMGUtils searchNode:c_P2];
        NSArray *cP2_RefAll_ps = [SMGUtils convertPointersFromPorts:[AINetUtils refPorts_All4Alg:cP2_Alg]];
        NSArray *cP2_RefOK_ps = [SMGUtils filterSame_ps:cP2_RefAll_ps parent_ps:cf_P2s];
        if (cP2_RefOK_ps.count == 0) continue;//无需处理;
        
        //b. 有效性判断2: C-M (C甜,M不能甜);
        NSArray *cP_At_mP = [SMGUtils filterSameIdentifier_ps:m_P1_vps b_ps:cP2_Alg.content_ps].allValues;
        NSArray *cP_Rm_mP = [SMGUtils removeSub_ps:cP_At_mP parent_ps:cP2_Alg.content_ps];
        
        //c. 有效性判断3: 再到M_S2s中找M负价值的,同区不同值的值,对C稀疏码进行满足 (如C中含距0,而M中为距50);
        NSDictionary *itemCanOut = [SMGUtils filterSameIdentifier_DiffId_ps:m_S2s b_ps:cP_Rm_mP];
        NSArray *itemCantOut = [SMGUtils removeSub_ps:itemCanOut.allValues parent_ps:cP_Rm_mP];
        NSLog(@"STEPKEY--->C需满足:%@ 可满足:%@ 未满足:%@",Pits2FStr(cP_Rm_mP),Pits2FStr(cCanOut.allValues),Pits2FStr(itemCantOut));
        
        //d. 收集可满足和未满足;
        [cCanOut setDictionary:itemCanOut];
        
        //5. 评价未满足带来的影响,是否要中断行为化 (忍无可忍,则行为化失败);
        AIKVPointer *cP2_RefOK_p = ARR_INDEX(cP2_RefOK_ps, 0);
        AIFoNodeBase *cP2_RefFo = [SMGUtils searchNode:cP2_RefOK_p];
        badScore += [ThinkingUtils getScoreForce:cP2_RefFo.cmvNode_p ratio:(float)itemCantOut.count / cP_Rm_mP.count];
        if (badScore + cScore <= 0) {
            complete(acts,false);
            return;
        }
    }
    
    //6. 进行行为化;
    __block BOOL failure = false;
    for (NSData *key in cCanOut) {
        //a. 对比大小
        AIKVPointer *mValue_p = DATA2OBJ(key);
        AIKVPointer *cValue_p = [cCanOut objectForKey:key];
        AnalogyType type = [ThinkingUtils compare:mValue_p valueB_p:cValue_p];
        //b. 行为化
        NSLog(@"------MC_V3行为化:%@ -> %@",[NVHeUtil getLightStr:mValue_p],[NVHeUtil getLightStr:cValue_p]);
        [self convert2Out_RelativeValue:cValue_p.algsType ds:cValue_p.dataSource type:type vSuccess:^(AIFoNodeBase *glFo, NSArray *itemActs) {
            [acts addObjectsFromArray:itemActs];
        } vFailure:^{
            failure = true;
        }];
        if (failure) break;
    }
    complete(acts,!failure);
}

-(void) convert2Out_MC_Alg:(AIAlgNodeBase*)curAlg curFo:(AIFoNodeBase*)curFo mcSuccess:(void(^)(NSArray *acts))mcSuccess mcFailure:(void(^)())mcFailure checkScore:(BOOL(^)(AIAlgNodeBase *mAlg))checkScore{
    //1. 数据准备
    __block BOOL failured = false;
    AIAlgNodeBase *matchAlg = self.shortMatchModel.matchAlg;
    NSMutableArray *allActs = [[NSMutableArray alloc] init];
    NSMutableArray *alreadyGLs = [[NSMutableArray alloc] init];
    if (matchAlg && curAlg) {
        //1. 取出mcs & ms & cs;
        NSArray *mAbs_ps = [SMGUtils convertPointersFromPorts:[AINetUtils absPorts_All:matchAlg]];
        NSArray *cAbs_ps = [SMGUtils convertPointersFromPorts:[AINetUtils absPorts_All:curAlg]];
        NSArray *ms = ARRTOOK([SMGUtils removeSub_ps:cAbs_ps parent_ps:mAbs_ps]);
        NSArray *cs = ARRTOOK([SMGUtils removeSub_ps:mAbs_ps parent_ps:cAbs_ps]);
        NSArray *mcs = ARRTOOK([SMGUtils filterSame_ps:mAbs_ps parent_ps:cAbs_ps]);
        NSLog(@"===========MC_ALG START=========\nM:%@\nC:%@\nmcs:%@\nms:%@\ncs:%@",Alg2FStr(matchAlg),Alg2FStr(curAlg),Pits2FStr(mcs),Pits2FStr(ms),Pits2FStr(cs));
        
        //1. MC匹配之: LSP里氏判断,M是否是C
        BOOL cIsAbs = ISOK(curAlg, AIAbsAlgNode.class);
        NSArray *cConPorts = cIsAbs ? ((AIAbsAlgNode*)curAlg).conPorts : nil;
        BOOL mIsC = [SMGUtils containsSub_p:matchAlg.pointer parentPorts:cConPorts];
        
        //2. 数据准备: (mcs无效且m不抽象自C时 = 则不匹配)
        if (!ARRISOK(mcs) && !mIsC) {
            return;
        }
        NSArray *msAlgs = [SMGUtils searchNodes:ms];
        
        //2. 当mNotS时,进行cs处理
        if (!mIsC) {
            NSArray *csAlgs = [SMGUtils searchNodes:cs];
            
            //3. MC抵消GL处理之: 判断长度为1;
            for (AIAlgNodeBase *csAlg in csAlgs) {
                for (AIAlgNodeBase *msAlg in msAlgs) {
                    
                    //3. ms&cs仅有1条不同稀疏码;
                    NSArray *csSubMs = [SMGUtils removeSub_ps:msAlg.content_ps parent_ps:csAlg.content_ps];
                    NSArray *msSubCs = [SMGUtils removeSub_ps:csAlg.content_ps parent_ps:msAlg.content_ps];
                    if (csSubMs.count == 1 && msSubCs.count == 1) {
                        //4. MC抵消GL处理之: 判断标识相同
                        AIKVPointer *csValue_p = ARR_INDEX(csSubMs, 0);
                        AIKVPointer *msValue_p = ARR_INDEX(msSubCs, 0);
                        if ([csValue_p.identifier isEqualToString:msValue_p.identifier]) {
                            //5. MC抵消GL处理之: 转移到_Value()
                            NSNumber *csValue = NUMTOOK([AINetIndex getData:csValue_p]);
                            NSNumber *msValue = NUMTOOK([AINetIndex getData:msValue_p]);
                            AnalogyType type = ATDefault;
                            if (csValue > msValue) {//需增大
                                type = ATGreater;
                            }else if(csValue < msValue){//需减小
                                type = ATLess;
                            }else{}//再者一样,不处理;
                            if (!failured && type != ATDefault) {
                                [self convert2Out_RelativeValue:msValue_p.algsType ds:msValue_p.dataSource type:type vSuccess:^(AIFoNodeBase *glFo, NSArray *acts) {
                                    [allActs addObjectsFromArray:acts];
                                } vFailure:^{
                                    failured = true;
                                }];
                            }
                            
                            //6. MC抵消GL处理之: 标记已处理;
                            [alreadyGLs addObject:csAlg];
                            [alreadyGLs addObject:msAlg];
                            break;
                        }
                    }
                }
                
                //7. MC未抵消H处理之: 满足csAlg;
                for (AIAlgNodeBase *csAlg in csAlgs) {
                    if (![alreadyGLs containsObject:csAlg] && !failured) {
                        [self convert2Out_Alg:csAlg.pointer curFo:curFo type:ATHav success:^(NSArray *acts) {
                            [allActs addObjectsFromArray:acts];
                        } failure:^{
                            failured = true;
                        } checkScore:checkScore];
                    }
                }
            }
        }
        
        //8. MC未抵消N处理之: 修正msAlg;
        for (AIAlgNodeBase *msAlg in msAlgs) {
            if (![alreadyGLs containsObject:msAlg] && !failured) {
                
                //9. 对msAlg进行评价,看是否需要修正;
                BOOL scoreSuccess = checkScore(msAlg);
                if (!scoreSuccess) {
                    [self convert2Out_Alg:msAlg.pointer curFo:curFo type:ATNone success:^(NSArray *acts) {
                        [allActs addObjectsFromArray:acts];
                    } failure:^{
                        failured = true;
                    } checkScore:checkScore];
                }
            }
        }
    }
    
    //10. 结果
    if (failured) {
        NSLog(@"====>MC_ALG Failure");
        mcFailure();
    }else{
        NSLog(@"====>MC_ALG Success:%@",Pits2FStr(allActs));
        mcSuccess(allActs);
    }
}

/**
 *  MARK:--------------------对MC中,特有的稀疏码进行行为化;--------------------
 *  @desc : 参考n18205:组合方案;
 *  @caller : 由MC方法调用;
 *  @param complete : 完成时调用
 *  @version
 *      2020.04.04 : 支持更全面查找的同区不同值 (渗透到具象中,参考:18206);
 *      2020.04.05 : 更新至v2(参考18207); 1. 将mcs&cs&ms的逻辑删掉,改用C和M的直接类比;   2. 将RTAlg的拼接改为用same_ps;
 *      2020.04.17 : MC_Value操作M对象由MatchAlg改为ProtoAlg;
 *      2020.04.18 : Same_ps为空时return,因为(远距果...)与(吃)对比,没有可比性;
 *      2020.04.19 : 更新至v3(参考n19p9); 1.仅针对反向反馈类比的成果ATPlus和ATSub进行使用; 2.由向右取ATPlus/ATSub替代重组RTAlg和Fo评价;(中止,转MC_V3开发,参考n19p10);
 */
-(void) convert2Out_MC_Value_V2:(AIAlgNodeBase*)cAlg curFo:(AIFoNodeBase*)curFo checkScore:(BOOL(^)(AIAlgNodeBase *rtAlg))checkScore complete:(void(^)(NSArray *acts,BOOL success))complete{
    //1. 数据准备;
    NSMutableArray *acts = [[NSMutableArray alloc] init];
    AIAlgNodeBase *pAlg = [SMGUtils searchNode:self.shortMatchModel.protoAlg_p];
    if (!pAlg || !cAlg || !complete || !checkScore || !curFo) {
        complete(acts,true);
        return;
    }
    __block BOOL success = true;//默认为成功,只有成功,才会一直运行下去;
    
    //2. 取M特有的稀疏码 和 Same_ps;
    NSArray *mUnique_ps = [SMGUtils removeSub_ps:cAlg.content_ps parent_ps:pAlg.content_ps];
    NSArray *same_ps = [SMGUtils filterSame_ps:pAlg.content_ps parent_ps:cAlg.content_ps];
    NSLog(@"===========MC_VALUE START=========\nP:%@\nC:%@\n需满足:%@\n一致的:%@",Alg2FStr(pAlg),Alg2FStr(cAlg),Pits2FStr(mUnique_ps),Pits2FStr(same_ps));
    
    //2. 无共同点时,无可比性;
    if (same_ps.count == 0) {
        complete(acts,true);
        return;
    }
    
    //4. 找同区不同值_直接从CUnique找 (1个自身cAlg);
    NSMutableDictionary *alreadyDic = [[NSMutableDictionary alloc] init]; //收集已找到的映射
    NSDictionary *findByCur = DICTOOK([SMGUtils filterSameIdentifier_DiffId_ps:mUnique_ps b_ps:cAlg.content_ps]);
    [alreadyDic setDictionary:findByCur];
    NSLog(@"==============> 需处理自身:%lu条,共:%lu条",(unsigned long)findByCur.count,mUnique_ps.count);
    
    //5. 将findByCur行为化;
    [self convert2Out_MC_Value_Multi:findByCur same_ps:same_ps complete:^(NSArray *mActs, BOOL mSuccess) {
        [acts addObjectsFromArray:mActs];
        success = mSuccess;
    } checkScore:checkScore];
    
    //6. 找同区不同值_再从价值确切的具象概念找 (n个具象Alg);
    if (alreadyDic.count < mUnique_ps.count && success) {
        [TOUtils findConAlg_StableMV:cAlg curFo:curFo itemBlock:^BOOL(AIAlgNodeBase *validAlg) {
            if (validAlg) {
                //a. 从conAlg中找映射;
                NSArray *needFind_ps = [SMGUtils removeSub_ps:DATAS2OBJS(alreadyDic.allKeys) parent_ps:mUnique_ps];
                NSDictionary *findByCon = DICTOOK([SMGUtils filterSameIdentifier_DiffId_ps:needFind_ps b_ps:validAlg.content_ps]);
                //b. 找几条收集几条;
                [alreadyDic setDictionary:findByCon];
                NSLog(@"==============> 需处理具象:%lu条,共:%lu条",(unsigned long)findByCon.count,mUnique_ps.count);
                
                //c. 将findByCon行为化;
                [self convert2Out_MC_Value_Multi:findByCon same_ps:same_ps complete:^(NSArray *mActs, BOOL mSuccess) {
                    [acts addObjectsFromArray:mActs];
                    success = mSuccess;
                } checkScore:checkScore];
            }
            //c. 未行为化失败 且 未找完,则继续;
            return mUnique_ps.count > alreadyDic.count && success;
        }];
    }
    
    //6. 执行返回;
    complete(acts,success);
}

/**
 *  MARK:--------------------MC_Value多条行为化方法--------------------
 *  @desc 主要功能为: 将findByDic循环进行行为化;
 */
-(void) convert2Out_MC_Value_Multi:(NSDictionary*)findDic same_ps:(NSArray*)same_ps complete:(void (^)(NSArray *mActs,BOOL mSuccess))complete checkScore:(BOOL(^)(AIAlgNodeBase *rtAlg))checkScore{
    //1. 数据准备
    findDic = DICTOOK(findDic);
    NSMutableArray *acts = [[NSMutableArray alloc] init];
    if (!complete) {
        complete(acts,false);
        return;
    }
    
    //2.  逐个行为化;
    for (NSData *key in findDic.allKeys) {
        //a. 取值;
        AIKVPointer *mValue_p = DATA2OBJ(key);
        AIKVPointer *cValue_p = [findDic objectForKey:key];
        __block BOOL success = true;
        //b. 行为化;
        [self convert2Out_MC_Value_Single:mValue_p cValue_p:cValue_p same_ps:same_ps complete:^(NSArray *sActs, BOOL sSuccess) {
            success = sSuccess;
            [acts addObjectsFromArray:sActs];
        } checkScore:checkScore];
        //c. 一条失败,则全失败;
        if (!success) {
            complete(acts,false);
            return;
        }
    }
    
    //3. 全成功,返回;
    complete(acts,true);
}

/**
 *  MARK:--------------------MC_Value单条行为化方法--------------------
 *  @desc 主要功能为: 将protoAlg - old + new = rtAlg,然后反思rtAlg,如果需要则取new->old的行为化;
 */
-(void) convert2Out_MC_Value_Single:(AIKVPointer *)mValue_p cValue_p:(AIKVPointer *)cValue_p same_ps:(NSArray*)same_ps complete:(void (^)(NSArray *sActs,BOOL sSuccess))complete checkScore:(BOOL(^)(AIAlgNodeBase *rtAlg))checkScore{
    //1. 数据检查
    NSMutableArray *acts = [[NSMutableArray alloc] init];
    if (!mValue_p || !cValue_p) {
        complete(nil,false);
        return;
    }
    NSLog(@"=======单稀疏码: <%@->%@>",Pit2FStr(mValue_p),Pit2FStr(cValue_p));
    
    //2. 重组rtAlg
    NSMutableArray *creativity_ps = [[NSMutableArray alloc] initWithArray:same_ps];
    [creativity_ps addObject:mValue_p];
    AIAbsAlgNode *rtAlg = [theNet createAbsAlg_NoRepeat:creativity_ps conAlgs:nil isMem:true isOut:false];
    
    //3. 反思 & 评价
    AIAlgNodeBase *matchAlg = [self.delegate toAlgScheme_MatchRTAlg:rtAlg mUniqueV_p:mValue_p];
    BOOL scoreSuccess = checkScore(matchAlg);
    NSLog_Mode(2,@"===>RTAlg:%@ \n=>识别:%@ \n=>评价:%d",Alg2FStr(rtAlg),Alg2FStr(matchAlg),scoreSuccess);
    if (scoreSuccess) {
        complete(nil,true);
        return;
    }
    
    //4. 行为化 (GL处理: 转移到_Value);
    AnalogyType type = [ThinkingUtils getInnerType:mValue_p backValue_p:cValue_p];
    if (type != ATDefault) {
        __block BOOL success = false;
        [self convert2Out_RelativeValue:mValue_p.algsType ds:mValue_p.dataSource type:type vSuccess:^(AIFoNodeBase *glFo, NSArray *subActs) {
            [acts addObjectsFromArray:subActs];
            success = true;
        } vFailure:^{}];
        
        //5. 成功;
        if (success) {
            complete(acts,true);
            return;
        }
    }
    complete(nil,false);
}

@end


//MARK:===============================================================
//MARK:                     < SP行为化 >
//MARK:===============================================================
@implementation TOAlgScheme (SP)

@end
