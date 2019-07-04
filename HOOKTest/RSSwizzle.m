//
//  RSSwizzle.m
//  RSSwizzleTests
//
//  Created by Yan Rabovik on 05.09.13.
//
//

#import "RSSwizzle.h"
#import <objc/runtime.h>
#import <libkern/OSAtomic.h>

#if !__has_feature(objc_arc)
#error This code needs ARC. Use compiler option -fobjc-arc
#endif

#pragma mark - Block Helpers
#if !defined(NS_BLOCK_ASSERTIONS)

// See http://clang.llvm.org/docs/Block-ABI-Apple.html#high-level
struct Block_literal_1 {
    void *isa; // initialized to &_NSConcreteStackBlock or &_NSConcreteGlobalBlock
    int flags;
    int reserved;
    void (*invoke)(void *, ...);
    struct Block_descriptor_1 {
        unsigned long int reserved;         // NULL
        unsigned long int size;         // sizeof(struct Block_literal_1)
        // optional helper functions
        void (*copy_helper)(void *dst, void *src);     // IFF (1<<25)
        void (*dispose_helper)(void *src);             // IFF (1<<25)
        // required ABI.2010.3.16
        const char *signature;                         // IFF (1<<30)
    } *descriptor;
    // imported variables
};

enum {
    BLOCK_HAS_COPY_DISPOSE =  (1 << 25),
    BLOCK_HAS_CTOR =          (1 << 26), // helpers have C++ code
    BLOCK_IS_GLOBAL =         (1 << 28),
    BLOCK_HAS_STRET =         (1 << 29), // IFF BLOCK_HAS_SIGNATURE
    BLOCK_HAS_SIGNATURE =     (1 << 30),
};
typedef int BlockFlags;

static const char *blockGetType(id block){
    struct Block_literal_1 *blockRef = (__bridge struct Block_literal_1 *)block;
    BlockFlags flags = blockRef->flags;
    
    if (flags & BLOCK_HAS_SIGNATURE) {
        void *signatureLocation = blockRef->descriptor;
        signatureLocation += sizeof(unsigned long int);
        signatureLocation += sizeof(unsigned long int);
        
        if (flags & BLOCK_HAS_COPY_DISPOSE) {
            signatureLocation += sizeof(void(*)(void *dst, void *src));
            signatureLocation += sizeof(void (*)(void *src));
        }
        
        const char *signature = (*(const char **)signatureLocation);
        return signature;
    }
    
    return NULL;
}

static BOOL blockIsCompatibleWithMethodType(id block, const char *methodType){
    
    const char *blockType = blockGetType(block);
    
    NSMethodSignature *blockSignature;
    
    if (0 == strncmp(blockType, (const char *)"@\"", 2)) {
        // Block return type includes class name for id types
        // while methodType does not include.
        // Stripping out return class name.
        char *quotePtr = strchr(blockType+2, '"');
        if (NULL != quotePtr) {
            ++quotePtr;
            char filteredType[strlen(quotePtr) + 2];
            memset(filteredType, 0, sizeof(filteredType));
            *filteredType = '@';
            strncpy(filteredType + 1, quotePtr, sizeof(filteredType) - 2);
            
            blockSignature = [NSMethodSignature signatureWithObjCTypes:filteredType];
        }else{
            return NO;
        }
    }else{
        blockSignature = [NSMethodSignature signatureWithObjCTypes:blockType];
    }
    
    NSMethodSignature *methodSignature =
        [NSMethodSignature signatureWithObjCTypes:methodType];
    
    if (!blockSignature || !methodSignature) {
        return NO;
    }
    
    if (blockSignature.numberOfArguments != methodSignature.numberOfArguments){
        return NO;
    }
    
    if (strcmp(blockSignature.methodReturnType, methodSignature.methodReturnType) != 0) {
        return NO;
    }
    
    for (int i=0; i<methodSignature.numberOfArguments; ++i){
        if (i == 0){
            // self in method, block in block
            if (strcmp([methodSignature getArgumentTypeAtIndex:i], "@") != 0) {
                return NO;
            }
            if (strcmp([blockSignature getArgumentTypeAtIndex:i], "@?") != 0) {
                return NO;
            }
        }else if(i == 1){
            // SEL in method, self in block
            if (strcmp([methodSignature getArgumentTypeAtIndex:i], ":") != 0) {
                return NO;
            }
            if (strncmp([blockSignature getArgumentTypeAtIndex:i], "@", 1) != 0) {
                return NO;
            }
        }else {
            const char *blockSignatureArg = [blockSignature getArgumentTypeAtIndex:i];
            
            if (strncmp(blockSignatureArg, "@?", 2) == 0) {
                // Handle function pointer / block arguments
                blockSignatureArg = "@?";
            }
            else if (strncmp(blockSignatureArg, "@", 1) == 0) {
                blockSignatureArg = "@";
            }
            
            if (strcmp(blockSignatureArg,
                       [methodSignature getArgumentTypeAtIndex:i]) != 0)
            {
                return NO;
            }
        }
    }
    
    return YES;
}
//用于返回block的签名，然后下面定义了一个规范的block并获取这
static BOOL blockIsAnImpFactoryBlock(id block){
    const char *blockType = blockGetType(block);
    //blockGetType()用于返回block的签名，然后下面定义了一个规范的block并获取这个block的签名，然后比较两个签名是否一致，一致则表明入参时的block符合规范。
    RSSwizzleImpFactoryBlock dummyFactory = ^id(RSSwizzleInfo *swizzleInfo){
        return nil;
    };
    const char *factoryType = blockGetType(dummyFactory);
    return 0 == strcmp(factoryType, blockType);
}

#endif // NS_BLOCK_ASSERTIONS


#pragma mark - Swizzling

#pragma mark └ RSSwizzleInfo
typedef IMP (^RSSWizzleImpProvider)(void);

@interface RSSwizzleInfo()
@property (nonatomic,copy) RSSWizzleImpProvider impProviderBlock;
@property (nonatomic, readwrite) SEL selector;
@end

@implementation RSSwizzleInfo

-(RSSwizzleOriginalIMP)getOriginalImplementation{
    NSAssert(_impProviderBlock,nil);
    // Casting IMP to RSSwizzleOriginalIMP to force user casting.将IMP强制转换为RSSwizzleOriginalIMP以强制用户转换。
    //void (*RSSwizzleOriginalIMP)(void /* id, SEL, ... */ );
    return (RSSwizzleOriginalIMP)_impProviderBlock();
}

@end


#pragma mark └ RSSwizzle
@implementation RSSwizzle

static void swizzle(Class classToSwizzle,
                    SEL selector,
                    RSSwizzleImpFactoryBlock factoryBlock)
{
    //返回一个指定的特定类的实例方法。
    Method method = class_getInstanceMethod(classToSwizzle, selector);
    
    NSCAssert(NULL != method,
              @"Selector %@ not found in %@ methods of class %@.",
              NSStringFromSelector(selector),
              class_isMetaClass(classToSwizzle) ? @"class" : @"instance",
              classToSwizzle);
    
    NSCAssert(blockIsAnImpFactoryBlock(factoryBlock),
             @"Wrong type of implementation factory block.");
    
    //惯例是解锁为零，锁定为非零。
    __block OSSpinLock lock = OS_SPINLOCK_INIT;
    // To keep things thread-safe, we fill in the originalIMP later,
    // with the result of the class_replaceMethod call below.为了保证线程安全，我们稍后再填写originalIMP，
    //下面是class_replaceMethod调用的结果。
    __block IMP originalIMP = NULL;

    // This block will be called by the client to get original implementation and call it.客户端将调用此块以获得原始实现并调用它。
    RSSWizzleImpProvider originalImpProvider = ^IMP{
        // It's possible that another thread can call the method between the call to
        // class_replaceMethod and its return value being set.
        // So to be sure originalIMP has the right value, we need a lock.
        OSSpinLockLock(&lock);
        IMP imp = originalIMP;
        OSSpinLockUnlock(&lock);
        
        if (NULL == imp){
            // If the class does not implement the method
            // we need to find an implementation in one of the superclasses.如果类没有实现该方法
            //我们需要在其中一个超类中找到一个实现。
            Class superclass = class_getSuperclass(classToSwizzle);
            //获取父类s/获取类的实例方方法
            //根据Method获取IMP  imp 就是方法实现的地址
            imp = method_getImplementation(class_getInstanceMethod(superclass,selector));
        }
        return imp;
    };
    
    RSSwizzleInfo *swizzleInfo = [RSSwizzleInfo new];
    swizzleInfo.selector = selector;
    //方法 imp 的实现
    swizzleInfo.impProviderBlock = originalImpProvider;
    
    // We ask the client for the new implementation block.
    // We pass swizzleInfo as an argument to factory block, so the client can
    // call original implementation from the new implementation.我们要求客户端提供新的实现块。
    //我们将swizzleInfo作为参数传递给工厂块，这样客户端就可以
    //从新实现调用原始实现。
    /*
     ^void (__unsafe_unretained id self,BOOL animated)
     {
     ((__typeof(originalImplementation_))[swizzleInfo
     getOriginalImplementation])(self, selector_, animated);
     NSLog(@"view will appear");
     }
     */
    //返回 newIMPBlock 就是RSSWReplacement里面部分
    id newIMPBlock = factoryBlock(swizzleInfo);
    
    const char *methodType = method_getTypeEncoding(method);
    //从工厂返回的块与方法类型不兼容。blockIsCompatibleWithMethodType()函数中就是判断block的签名是否与selector的签名匹配
    NSCAssert(blockIsCompatibleWithMethodType(newIMPBlock,methodType),
             @"Block returned from factory is not compatible with method type.");
    //根据代码块获取IMP,其实就是代码块与IMP关联
    IMP newIMP = imp_implementationWithBlock(newIMPBlock);
    
    // Atomically replace the original method with our new implementation.
    // This will ensure that if someone else's code on another thread is messing
    // with the class' method list too, we always have a valid method at all times.
    //
    // If the class does not implement the method itself then
    // class_replaceMethod returns NULL and superclasses's implementation will be used.
    //
    // We need a lock to be sure that originalIMP has the right value in the
    // originalImpProvider block above.原子地用我们的新实现替换原来的方法。
    //这将确保如果另一个线程上的其他人的代码混乱
    //对于类的方法列表，我们总是在任何时候都有一个有效的方法。
    //
    //如果类本身没有实现方法
    // class_replaceMethod返回NULL，将使用超类的实现。
    //
    //我们需要一个锁来确保originalIMP在
    //上面的originalImpProvider块。
    OSSpinLockLock(&lock);
    //替代方法的实现
    //将原始selector的IMP替换成这个block的IMP,如果该类中没有实现这个Selector方法，则返回值为nil；否则返回原始的IMP
    //函数  newIMP 用selector  替换
    /*
     替换给定类的方法的实现。
     class_replaceMethod(Class _Nullable cls, SEL _Nonnull name, IMP _Nonnull imp,
     const char * _Nullable types)
     @param cls 要修改的类。
     SEL _Nonnull name  一个选择器，它标识要替换其实现的方法。
     IMP _Nonnull imp 为cls标识的类的名称标识的方法提供新的实现。  
     types 描述方法参数类型的字符数组。
     *因为函数必须包含至少两个参数- self和_cmd，第二个和第三个字符
     *必须是“@:”(第一个字符是返回类型)。
     返回 之前的类方法的实现
     
     这个函数有两种不同的行为方式:
     * -如果\e name标识的方法还不存在，则添加它，就像调用了\c class_addMethod一样。
     * \e类型指定的类型编码如下所示。
     * -如果由\e名称标识的方法确实存在，则将其\c IMP替换为调用\c method_setImplementation。
     *忽略\e类型指定的类型编码。
     */
    //替换成新实现方法,返回以前实现的方法,
    originalIMP = class_replaceMethod(classToSwizzle, selector, newIMP, methodType);
    OSSpinLockUnlock(&lock);
}

static NSMutableDictionary *swizzledClassesDictionary(){
    static NSMutableDictionary *swizzledClasses;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzledClasses = [NSMutableDictionary new];
    });
    return swizzledClasses;
}

static NSMutableSet *swizzledClassesForKey(const void *key){
    NSMutableDictionary *classesDictionary = swizzledClassesDictionary();
    NSValue *keyValue = [NSValue valueWithPointer:key];
    NSMutableSet *swizzledClasses = [classesDictionary objectForKey:keyValue];
    if (!swizzledClasses) {
        swizzledClasses = [NSMutableSet new];
        [classesDictionary setObject:swizzledClasses forKey:keyValue];
    }
    return swizzledClasses;
}

+(BOOL)swizzleInstanceMethod:(SEL)selector
                     inClass:(Class)classToSwizzle
               newImpFactory:(RSSwizzleImpFactoryBlock)factoryBlock
                        mode:(RSSwizzleMode)mode
                         key:(const void *)key
{
    NSAssert(!(NULL == key && RSSwizzleModeAlways != mode),
             @"Key may not be NULL if mode is not RSSwizzleModeAlways.");

    @synchronized(swizzledClassesDictionary()){
        if (key){
            NSSet *swizzledClasses = swizzledClassesForKey(key);
            if (mode == RSSwizzleModeOncePerClass) {
                if ([swizzledClasses containsObject:classToSwizzle]){
                    return NO;
                }
            }else if (mode == RSSwizzleModeOncePerClassAndSuperclasses){
                for (Class currentClass = classToSwizzle;
                     nil != currentClass;
                     currentClass = class_getSuperclass(currentClass))
                {
                    if ([swizzledClasses containsObject:currentClass]) {
                        return NO;
                    }
                }
            }
        }
        
        swizzle(classToSwizzle, selector, factoryBlock);
        
        if (key){
            [swizzledClassesForKey(key) addObject:classToSwizzle];
        }
    }
    
    return YES;
}

+(void)swizzleClassMethod:(SEL)selector
                  inClass:(Class)classToSwizzle
            newImpFactory:(RSSwizzleImpFactoryBlock)factoryBlock
{
    [self swizzleInstanceMethod:selector
                        inClass:object_getClass(classToSwizzle)
                  newImpFactory:factoryBlock
                           mode:RSSwizzleModeAlways
                            key:NULL];
}


@end
