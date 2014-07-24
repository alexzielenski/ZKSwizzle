//
//  ZKTests.m
//  ZKSwizzle
//
//  Created by Alexander S Zielenski on 7/24/14.
//  Copyright (c) 2014 Alexander S Zielenski. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "ZKSwizzle.h"

@interface ZKOriginalClass : NSObject
+ (NSString *)classMethod;
+ (NSString *)description;
- (NSString *)instanceMethod;
- (NSString *)description;
@end

@implementation ZKOriginalClass

+ (BOOL)isSubclassOfClass:(Class)aClass { return YES; }
+ (NSString *)classMethod { return @"original"; }
+ (NSString *)description { return @"original"; }
- (NSString *)instanceMethod { return @"original"; }
- (NSString *)description { return @"original"; }

@end

@interface ZKSwizzleClass : ZKOriginalClass @end
@implementation ZKSwizzleClass

+ (BOOL)isSubclassOfClass:(Class)aClass {
    return (BOOL)ZKOrig();
}

- (NSString *)className {
    return [ZKOrig() stringByAppendingString:@"_replaced"];
}

+ (NSString *)classMethod {
    return @"replaced";
}

+ (NSString *)description {
    return ZKSuper();
}

- (NSString *)instanceMethod {
    return @"replaced";
}

- (NSString *)description {
    return ZKSuper();
}

@end

@interface ZKTests : XCTestCase
@end

@implementation ZKTests

- (void)setUp {
    [super setUp];
    [ZKSwizzle swizzleClass:[ZKSwizzleClass class]];
}

- (void)testExample {
    ZKOriginalClass *instance = [[ ZKOriginalClass alloc] init];
    XCTAssertEqualObjects([ ZKOriginalClass classMethod], @"replaced", @"replacing class methods");
    XCTAssertEqualObjects([instance instanceMethod], @"replaced", @"replacing instance methods");
    XCTAssertNotEqualObjects([ ZKOriginalClass description], @"original", @"calling super on class");
    XCTAssertNotEqualObjects([instance description], @"original", @"calling super on instance");
    XCTAssertEqual([ ZKOriginalClass isSubclassOfClass:[NSString class]], YES, @"calling super imp on class");
    XCTAssertEqualObjects([instance className], @"ZKOriginalClass_replaced", @"calling original imp on instance");
}

@end
