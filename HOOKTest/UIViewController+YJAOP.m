//
//  UIViewController+YJAOP.m
//  YunJiBuyer
//
//  Created by YJMAC on 16/8/18.
//  Copyright © 2016年 浙江集商优选电子商务有限公司. All rights reserved.
//

#import "UIViewController+YJAOP.h"

#import <objc/runtime.h>


#import "RSSwizzle.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach-o/ldsyms.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <mach-o/nlist.h>
#include <string.h>
#import <objc/message.h>
@implementation UIViewController (YJAOP)

+ (void)load
{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
//        swizzleMethod([self class], @selector(viewDidAppear:), @selector(swizzled_viewDidAppear:));
//        swizzleMethod([self class], @selector(viewDidDisappear:), @selector(swizzled_viewDidDisappear:));
        swizzleMethod([self class], @selector(viewWillAppear:), @selector(swizzled_viewWillAppear:));
    });
//    RSSwizzleInstanceMethod([self class], @selector(viewDidAppear:), RSSWReturnType(void), RSSWArguments(BOOL animated), RSSWReplacement({
//
//        NSLog(@"swizzled_viewDidAppear");
//        RSSWCallOriginal(animated);
//
//    }), RSSwizzleModeAlways, NULL);
//    RSSwizzleInstanceMethod([self class], @selector(viewDidDisappear:), RSSWReturnType(void), RSSWArguments(BOOL animated), RSSWReplacement({
////        UIViewController *vc = self;
////        [vc swizzled_viewDidDisappear:animated];
//        NSLog(@"swizzled_viewDidDisappear");
//        RSSWCallOriginal(animated);
//
//    }), RSSwizzleModeAlways, NULL);

//    RSSwizzleInstanceMethod([self class], @selector(viewWillAppear:), RSSWReturnType(void), RSSWArguments(BOOL animated), RSSWReplacement({
//
//         NSLog(@"swizzled_viewWillAppear");
//         RSSWCallOriginal(animated);
//
//    }), RSSwizzleModeAlways, NULL);
}
+ (void)toHookViewWillAppear:(Class)class {
    SEL originalSelector = @selector(viewWillAppear:);
    SEL swizzledSelector = [self swizzledSelectorForSelector:originalSelector];
    
    void (^swizzleBlock)(UIViewController *vc,BOOL animated) = ^(UIViewController *viewController, BOOL animated) {
        ((void(*)(id, SEL, BOOL))objc_msgSend)(viewController, swizzledSelector, animated);
        
    };
    [self replaceImplementationOfKnownSelector:originalSelector onClass:class withBlock:swizzleBlock swizzledSelector:swizzledSelector];
    
}
+ (void)toHookViewDidAppear:(Class)class {
    SEL originalSelector = @selector(viewDidAppear:);
    SEL swizzledSelector = [self swizzledSelectorForSelector:originalSelector];
    
    void (^swizzleBlock)(UIViewController *vc,BOOL animated) = ^(UIViewController *viewController, BOOL animated) {
        
        ((void(*)(id, SEL, BOOL))objc_msgSend)(viewController, swizzledSelector, animated);
        
    };
    [self replaceImplementationOfKnownSelector:originalSelector onClass:class withBlock:swizzleBlock swizzledSelector:swizzledSelector];
    
}
    
+ (void)toHookViewWillDisappear:(Class)class {
    SEL originalSelector = @selector(viewWillDisappear:);
    SEL swizzledSelector = [self swizzledSelectorForSelector:originalSelector];
    void (^swizzleBlock)(UIViewController *vc,BOOL animated) = ^(UIViewController *viewController, BOOL animated) {
        
        ((void(*)(id, SEL, BOOL))objc_msgSend)(viewController, swizzledSelector, animated);
    };
    [self replaceImplementationOfKnownSelector:originalSelector onClass:class withBlock:swizzleBlock swizzledSelector:swizzledSelector];
}
    
+ (void)toHookViewDidDisappear:(Class)class {
    
    SEL originalSelector = @selector(viewDidDisappear:);
    SEL swizzledSelector = [self swizzledSelectorForSelector:originalSelector];
    //方法实现
    void (^swizzleBlock)(UIViewController *vc,BOOL animated) = ^(UIViewController *viewController, BOOL animated) {
        
        ((void(*)(id, SEL, BOOL))objc_msgSend)(viewController, swizzledSelector, animated);
        
    };
    [self replaceImplementationOfKnownSelector:originalSelector onClass:class withBlock:swizzleBlock swizzledSelector:swizzledSelector];
}
    
    
+ (BOOL)replaceImplementationOfKnownSelector:(SEL)originalSelector onClass:(Class)class withBlock:(id)block swizzledSelector:(SEL)swizzledSelector {
    //返回一个指定的特定类的实例方法。
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    if (!originalMethod) {
        return NO;
    }
#ifdef __IPHONE_6_0
    //创建一个指向函数的指针,调用方法被调用时指定的块。
    IMP implementation = imp_implementationWithBlock((id)block);
#else
    IMP implementation = imp_implementationWithBlock((__bridge void *)block);
#endif
    //方法交换应该保证唯一性和原子性,唯一性：应该尽可能在＋load方法中实现，这样可以保证方法一定会调用且不会出现异常。
    // 原子性：使用dispatch_once来执行方法交换，这样可以保证只运行一次。
    //给类添加一个方法  向具有给定名称和实现的类添加新方法。
    //swizzledSelector 指定要添加的方法的名称的选择器。
    //implementation 一个函数，它是新方法的实现。该函数必须包含至少两个参数- self和_cmd。
    //描述方法参数类型的字符数组
    class_addMethod(class, swizzledSelector, implementation, method_getTypeEncoding(originalMethod));
    //class_getInstanceMethod     得到类的实例方法,
    //class_getClassMethod          得到类的类方法
    //获取类的实例方法
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    /*
     class_addMethod:动态给类添加一个方法
     cls：被添加方法的类
     name：可以理解为方法名，这个貌似随便起名，比如我们这里叫sayHello2
     imp：实现这个方法的函数
     types：一个定义该函数返回值类型和参数类型的字符串，这个具体会在后面讲
     
     //获取通过SEL获取一个方法class_getInstanceMethod
     
     //获取一个方法的实现 method_getImplementation
     //获取一个OC实现的编码类型method_getTypeEncoding
     //給方法添加实现class_addMethod
     //用一个方法的实现替换另一个方法的实现class_replaceMethod
     //交换两个方法的实现 method_exchangeImplementations
     
     class_addMethod:如果发现方法已经存在，会失败返回，也可以用来做检查用,我们这里是为了避免源方法没有实现的情况;如果方法没有存在,我们则先尝试添加被替换的方法的实现
     1.如果返回成功:则说明被替换方法没有存在.也就是被替换的方法没有被实现,我们需要先把这个方法实现,然后再执行我们想要的效果,用我们自定义的方法去替换被替换的方法. 这里使用到的是class_replaceMethod这个方法. class_replaceMethod本身会尝试调用class_addMethod和method_setImplementation，所以直接调用class_replaceMethod就可以了)
     
     2.如果返回失败:则说明被替换方法已经存在.直接将两个方法的实现交换即
     
     */
    //先尝试給源方法添加实现，这里是为了避免源方法没有实现的情况
    BOOL didAddMethod = class_addMethod(class,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    if (didAddMethod) {//添加成功：将源方法的实现替换到交换方法的实现,  函数  originalMethod 用swizzledSelector  替换
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    }
    else {
        //添加失败：说明源方法已经有实现，直接将两个方法的实现交换即可
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
    return YES;
}
    
+ (long long)currentTime {
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970] * 1000;
    long long dTime = [[NSNumber numberWithDouble:time] longLongValue];
    return dTime;//[[NSDate date] timeIntervalSince1970] * 1000;
}
    
+ (SEL)swizzledSelectorForSelector:(SEL)selector {
    // 保证 selector 为唯一的，不然会死循环
    return NSSelectorFromString([NSString stringWithFormat:@"MA_Swizzle_%x_%llu_%@", arc4random(), [self currentTime], NSStringFromSelector(selector)]);
}
- (void)swizzled_viewWillAppear:(BOOL)animated {
//    NSString *className = NSStringFromClass([self class]);
//    if ([className isEqualToString:@"YJ_New_AccountViewController"] || [className isEqualToString:@"YJHeadlineShowAwardViewController"]|| [className isEqualToString:@"YJHeadlineContentDetailViewController"]|| [className isEqualToString:@"YJFoundMessageVC"]|| [className isEqualToString:@"YJHeadlineViewController"]) {
//        NSLog(@"className001=%@",className);
//    }
    NSLog(@"swizzled_viewWillAppear");
    //执行系统原来的方法
    [self swizzled_viewWillAppear:animated];
    
}
    - (void)swizzleInstanceMethod:(Class)classToSwizzle selector:(SEL)selector {
//    [RSSwizzle swizzleInstanceMethod:selector inClass:[classToSwizzle class] newImpFactory:^id(RSSwizzleInfo *swizzleInfo) {
//        //RSSWReturnType(void) ===> void
//        //_RSSWWrapArg(RSSWArguments(BOOL animated)) ===> DEL, BOOL animated
//        // _RSSWDel3Arg(__unsafe_unretained id,SEL,_RSSWWrapArg(RSSWArguments(BOOL animated))) ===> __unsafe_unretained id,SEL,BOOL animated
//        /*
//         _RSSWWrapArg(RSSWArguments(BOOL animated)) ===> DEL, BOOL animated
//         void(*originalImplementation_)(__unsafe_unretained id,SEL,BOOL animated)
//         */
//        RSSWReturnType(void) (*originalImplementation_)(_RSSWDel3Arg(__unsafe_unretained id,    SEL,_RSSWWrapArg(RSSWArguments(BOOL animated))));
//        SEL selector_ = selector;
//        //_RSSWDel2Arg(__unsafe_unretained id self,_RSSWWrapArg(RSSWArguments(BOOL animated))) ===> _RSSWDel2Arg(__unsafe_unretained id self,DEL, BOOL animated) ===> __unsafe_unretained id self, BOOL animated
//        /*
//         #define RSSWReplacement(code...) code
//         RSSWReplacement({
//
//         RSSWCallOriginal(animated);
//
//         NSLog(@"view will appear");
//         })--->{
//
//         RSSWCallOriginal(animated);
//
//         NSLog(@"view will appear");
//         }
//         #define _RSSWCallOriginal(arguments...) \
//         ((__typeof(originalImplementation_))[swizzleInfo \
//         getOriginalImplementation])(self, \
//         selector_, \
//         ##arguments)
//
//         ^void(__unsafe_unretained id self, BOOL animated){
//
//         }
//
//         */
//        return ^RSSWReturnType(void) (_RSSWDel2Arg(__unsafe_unretained id self,
//                                                   _RSSWWrapArg(RSSWArguments(BOOL animated))))
//        {
//            _RSSWWrapArg(RSSWReplacement({
//
//                RSSWCallOriginal(animated);
//
//                NSLog(@"view will appear");
//            }))
//        };
//
//        return nil;
//    } mode:RSSwizzleModeAlways key:NULL];
        
        [RSSwizzle swizzleInstanceMethod:@selector(viewWillAppear:) inClass:[UIViewController class] newImpFactory:^id(RSSwizzleInfo *swizzleInfo) {
            
            //定义一个函数指针
            void (*originalImplementation_)( id,SEL,BOOL animated);
            SEL selector_ = @selector(viewWillAppear:);
            return ^void (__unsafe_unretained id self,BOOL animated)
            {
                /*
               ((__typeof(originalImplementation_)) void (*RSSwizzleOriginalIMP)(void ))(self, selector_, animated)
                 */
//                ((__typeof(originalImplementation_))[swizzleInfo
//                                                    getOriginalImplementation]);
//                 ((__typeof(originalImplementation_)) void(*RSSwizzleOriginalIMP)(void ))(self, selector_, animated)
               //类型,调用了获取 imp(自己类的 实现,或者从父类找),强转这个originalImplementation_类型,调用了 imp 方法出来
                ((__typeof(originalImplementation_))[swizzleInfo
                                                     getOriginalImplementation])(self, selector_, animated);
                NSLog(@"view will appear");
            };
        } mode:0 key:NULL];
}



- (void)swizzled_viewDidAppear:(BOOL)animated {
    
//    [self swizzled_viewDidAppear:animated];
//
//    //设置tabBar上的自控件
//    [self setupTabBarSubViews];
    
}

- (void)swizzled_viewDidDisappear:(BOOL)animated {
//    [self swizzled_viewDidDisappear:animated];
    
}

void swizzleMethod(Class class, SEL originalSelector, SEL swizzledSelector)
{
//  NSString * className = NSStringFromClass(class);
//     NSLog(@"------className-=%@",className);
//    if ([className isEqualToString:@"YJ_New_AccountViewController"] || [className isEqualToString:@"YJHeadlineShowAwardViewController"]|| [className isEqualToString:@"YJHeadlineContentDetailViewController"]|| [className isEqualToString:@"YJFoundMessageVC"]|| [className isEqualToString:@"YJHeadlineViewController"]) {
//        NSLog(@"className001=%@",className);
//    }
    // the method might not exist in the class, but in its superclass
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    if (swizzledMethod == NULL) {
        NSLog(@"-------");
    }
    IMP swizzledMethodIMP = method_getImplementation(swizzledMethod);
    IMP originalMethodIMP = method_getImplementation(originalMethod);
    // class_addMethod will fail if original method already exists
    BOOL didAddMethod = class_addMethod(class, originalSelector, swizzledMethodIMP, method_getTypeEncoding(swizzledMethod));
    
  
    // the method doesn’t exist and we just added one
    IMP originalIMP = NULL;
    if (didAddMethod) {
      originalIMP =  class_replaceMethod(class, swizzledSelector,originalMethodIMP, method_getTypeEncoding(originalMethod));
    }
    else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

- (BOOL)hideNavBar {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setHideNavBar:(BOOL)hideNavBar {
   
    objc_setAssociatedObject(self, @selector(hideNavBar), @(hideNavBar), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ViewControllerWillAppearMethodBlock)viewControllerWillAppearMethodBlock
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setViewControllerWillAppearMethodBlock:(ViewControllerWillAppearMethodBlock)block
{
    objc_setAssociatedObject(self, @selector(viewControllerWillAppearMethodBlock), block, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

//@implementation UINavigationController (navHidden)
//
//+ (void)load
//{
//    
//    Method originalMethod = class_getInstanceMethod(self, @selector(pushViewController:animated:));
//    Method swizzledMethod = class_getInstanceMethod(self, @selector(yj_pushViewController:animated:));
//    method_exchangeImplementations(originalMethod, swizzledMethod);
//}
//
//- (void)yj_pushViewController:(UIViewController *)viewController animated:(BOOL)animated
//{
//    __weak typeof(self) weakSelf = self;
//    ViewControllerWillAppearMethodBlock block = ^(UIViewController *viewController, BOOL animated) {
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        if (strongSelf) {
//            ///yj_navigationBarHidden 每个 默认值为NO
//            [strongSelf setNavigationBarHidden:viewController.hideNavBar animated:animated];
//            
//            
//        }
//    };
//    /// 给push的对应block 赋值
//    viewController.viewControllerWillAppearMethodBlock = block;
//    /// 获取没push前的VC
//    UIViewController *disappearingViewController = self.viewControllers.lastObject;
//    if (disappearingViewController && !disappearingViewController.viewControllerWillAppearMethodBlock) {
//        /// 并赋值block
//        disappearingViewController.viewControllerWillAppearMethodBlock = block;
//    }
//    
//    [self yj_pushViewController:viewController animated:YES];
//}
//
//
//@end
