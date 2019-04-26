//
//  TOFoModel.h
//  SMG_NothingIsAll
//
//  Created by jia on 2019/1/30.
//  Copyright © 2019年 XiaoGang. All rights reserved.
//

#import "TOModelBase.h"

/**
 *  MARK:--------------------决策中的时序模型--------------------
 *  1. content_p : 存AIFoNodeBase_p
 *  2. 再通过algScheme联想把具象可执行的具体任务存到memOrder;
 *  3. 其间,如果有执行失败,无效等祖母节点,存到except_ps不应期;
 */
@interface TOFoModel : TOModelBase

//@property (strong, nonatomic) NSMutableArray *memOrder; //当前要执行的内存时序 (最终要转换为行为化后的outOrder)

@end