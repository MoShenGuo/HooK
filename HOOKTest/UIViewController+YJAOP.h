//
//  UIViewController+YJAOP.h
//  YunJiBuyer
//
//  Created by YJMAC on 16/8/18.
//  Copyright © 2016年 浙江集商优选电子商务有限公司. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void (^ViewControllerWillAppearMethodBlock)(UIViewController *viewController, BOOL animated);

@interface UIViewController (YJAOP)

@property (nonatomic, copy) ViewControllerWillAppearMethodBlock viewControllerWillAppearMethodBlock;

/**
 隐藏导航栏
 以后如果页面使用自定义导航栏 需要隐藏系统导航栏只需在对应页面ViewDidLoad中设置这个属性值为YES 默认是NO
 */
@property (nonatomic,assign)BOOL hideNavBar;

@end


//@interface UINavigationController (navHidden)

//@end

