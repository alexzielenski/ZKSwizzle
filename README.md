ZKSwizzle
=========

Streamlined way to swizzle Objective-C instance and class methods. `ZKSwizzle` makes swizzling instance and class methods of an Objective-C class as declarative as possible. You define a new class and implement all the methods you want to swizzle/add and then call `[ZKSwizzle swizzleClass: forClass:]` and any calls to the target class will be instead routed to your own.

ZKSwizzle also provides macros for calling the original implementation if need be and for calling the implementation of the superclass of the swizzled class. Enough talk, let's get crackin':


```objc
@interface OriginalObject : NSObject
@end
		
// Define a class which we will swizzle
@implementation OriginalObject
+ (BOOL)isSubclassOfClass:(Class)aClass { return YES; }
+ (NSString *)classMethod { return @"original"; }
+ (NSString *)description { return @"original"; }
- (NSString *)instanceMethod { return @"original"; }
- (NSString *)description { return @"original"; }
@end
		
// All methods on this class which are present on the class that
// it is swizzled to (including superclasses) are called instead of their
// original implementation. The original implementaion can be accessed with the 
// ZKOrig(...) macro and the implementation of the superclass of the class which
// it was swizzled to can be access with the ZKSuper(...) macro
@interface ReplacementObject : NSObject
// Returns YES
+ (BOOL)isSubclassOfClass:(Class)aClass { return (BOOL)ZKOrig(); }

// Returns "original_replaced"
- (NSString *)className { return [ZKOrig() stringByAppendingString:@"_replaced"]; }

// Returns "replaced" when called on the OriginalObject class
+ (NSString *)classMethod { return @"replaced"; }

// Returns the default description implemented by NSObject
+ (NSString *)description { return ZKSuper(); }

// Returns "replaced" when called on an instance of OriginalObject
- (NSString *)instanceMethod { return @"replaced"; }
	
// Returns the default description implemented by NSObject
- (NSString *)description { return ZKSuper(); }
	
// This method is added to instances of OriginalObject and can be called
// like any normal function on OriginalObject
- (void)addedMethod { NSLog(@"this method was added to OriginalObject"); }
@end
```

	
Call this somewhere to initialize the swizzling:
```objc
// ZKSwizzle(SOURCE, DST) is a macro shorthand for calling +swizzleClass:forClass: on ZKSwizzle
ZKSwizzle(ReplacementObject, OriginalObject);
```

ZKSwizzle also has macros in place for hooking instance variables:
```objc
// gets the value of _myIvar on self
int myIvar = ZKHookIvar(self, int, "_myIvar");
	
// gets the pointer to _myIvar on self so you can reassign it
int *myIvar = &ZKHookIvar(self, int, "_myIvar");
// set the value of myIvar on the object
*myIvar = 3;
```

# "Swizzling the right way"

Some say that using `method_exchangeImplementations` causes problems with the original implementation being passed a replaced `_cmd` such as `old_description` which would be the new selector for the original implementation of a swizzled `description`. ZKSwizzle solves this problem with `ZKOrig(...)` which passes the correct selector to the original implementation and thus avoids this problem.

#License

ZKSwizzle is available on the permissive [MIT License](http://opensource.org/licenses/mit-license.php)

