//
//  ZKTests.m
//  ZKSwizzle
//
//  Created by Alexander S Zielenski on 7/24/14.
//  Copyright (c) 2014 Alexander S Zielenski. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "ZKSwizzle.h"

id bloxecute(id (^block)()) {
    return block();
}

@interface ZKOriginalClass : NSObject {
    int ivar;
}
+ (NSString *)classMethod;
+ (NSString *)description;
- (NSString *)instanceMethod;
- (NSString *)description;
- (int)ivar;
@end

@interface ZKOriginalClass (meh)
- (NSString *)addedMethod;
@end

@implementation ZKOriginalClass
- (id)init { if ((self = [super init])) { ivar = 1; } return self; }
+ (BOOL)isSubclassOfClass:(Class)aClass { return YES; }
+ (NSString *)classMethod { return @"original"; }
+ (NSString *)description { return @"original"; }
- (NSString *)instanceMethod { return @"original"; }
- (NSString *)description { return @"original"; }
- (int)ivar { return ivar; }
- (NSString *)selectorName { return NSStringFromSelector(_cmd); }
@end

@interface ZKSwizzlerClass : ZKOriginalClass @end
@implementation ZKSwizzlerClass

+ (BOOL)isSubclassOfClass:(Class)aClass {
    return ZKSuper(BOOL, aClass);
}

- (NSString *)className {
    return [ZKOrig(NSString *) stringByAppendingString:@"_replaced"];
}

+ (NSString *)classMethod {
    return @"replaced";
}

+ (NSString *)description {
    return ZKSuper(NSString *);
}

- (NSString *)instanceMethod {
    return @"replaced";
}

- (NSString *)description {
    return ZKSuper(NSString *);
}

- (int)ivar {
    int *hooked = &ZKHookIvar(self, int, "ivar");
    *hooked = 3;
    return ZKOrig(int);
}

- (NSString *)selectorName {
    return bloxecute(^{
        return ZKOrig(NSString *);
    });
}

- (NSString *)addedMethod {
    //    NSLog(@"%@", ZKOrig(NSString *));
    return @"hi";
}

@end

@interface ZKSwizzlerClass2 : ZKOriginalClass

@end
@implementation ZKSwizzlerClass2

- (NSString *)selectorName {
    return [NSString stringWithFormat:@"BREH: %@", ZKOrig(NSString *)];
}

- (NSString *)description {
    return [@"MULTIPLE: " stringByAppendingString: ZKOrig(NSString *)];
}

@end

@interface DummyClass : NSObject
@end

@implementation DummyClass

- (NSString *)description {
    return @"DummyClass";
}

@end

@interface NewClass : DummyClass
@end

@implementation NewClass

- (NSString *)description {
    return ZKSuper(NSString *);
}

@end

@interface GroupClass : NSObject
+ (NSString *)classMethod;
- (NSString *)instanceMethod;
@end

@implementation GroupClass

+ (NSString *)classMethod {
    return @"classMethod";
}

- (NSString *)instanceMethod {
    return @"instanceMethod";
}

@end

// Swizzled Group
ZKSwizzleInterfaceGroup(GroupSwizzle, GroupClass, NSObject, Yosemite)
@implementation GroupSwizzle

+ (NSString *)classMethod {
    return @"swizzled";
}

- (NSString *)instanceMethod {
    return @"swizzled";
}

@end

// Unswizzled Group – unused
ZKSwizzleInterfaceGroup(GroupSwizzle2, GroupClass, NSObject, Mavericks)
@implementation GroupSwizzle2

+ (NSString *)classMethod {
    return @"swizzled2";
}

- (NSString *)instanceMethod {
    return @"swizzled2";
}

@end
#define ctor __attribute__((constructor)) void init()

ctor {
    ZKSwizzleGroup(Yosemite);
}

@interface ZKTests : XCTestCase
@end

@implementation ZKTests

- (void)setUp {
    [super setUp];
}

- (void)testExample {
    _ZKSwizzleClass(ZKClass(ZKSwizzlerClass));
    _ZKSwizzleClass(ZKClass(ZKSwizzlerClass2));
    ZKOriginalClass *instance = [[ ZKOriginalClass alloc] init];
    XCTAssertEqualObjects([ ZKOriginalClass classMethod], @"replaced", @"replacing class methods");
    XCTAssertEqualObjects([instance instanceMethod], @"replaced", @"replacing instance methods");
    XCTAssertNotEqualObjects([ ZKOriginalClass description], @"original", @"calling super on class");
    XCTAssertNotEqualObjects([instance description], @"original", @"calling super on instance");
    XCTAssertEqual([ ZKOriginalClass isSubclassOfClass:[NSString class]], NO, @"calling super imp on class");
//    XCTAssertEqualObjects([instance className], @"ZKOriginalClass_replaced", @"calling original imp on instance");
    XCTAssertEqualObjects([instance selectorName], @"BREH: selectorName", @"_cmd correct on original imps");
    XCTAssertEqual([instance ivar], 3, @"hooking ivars");
    XCTAssertEqual([instance addedMethod], @"hi", @"adding methods");
    XCTAssertEqualObjects([[[NewClass alloc] init] description], @"DummyClass", @"ZKSuper outside of swizzling");
}

- (void)testGroups {
//    ZKSwizzleGroup(Yosemite);
    XCTAssertEqualObjects([[[GroupClass alloc] init] instanceMethod], @"swizzled");
    XCTAssertEqualObjects([GroupClass classMethod], @"swizzled");
}

@end
