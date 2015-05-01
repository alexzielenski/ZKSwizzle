//
//  ZKSwizzle.m
//  ZKSwizzle
//
//  Created by Alexander S Zielenski on 7/24/14.
//  Copyright (c) 2014 Alexander S Zielenski. All rights reserved.
//

#import "ZKSwizzle.h"
void *ZKIvarPointer(id self, const char *name) {
    Ivar ivar = class_getInstanceVariable(object_getClass(self), name);
    return ivar == NULL ? NULL : (__bridge void *)self + ivar_getOffset(ivar);
}

// takes __PRETTY_FUNCTION__ for info which gives the name of the swizzle source class
/*

 We add the original implementation onto the swizzle class
 On ZKOrig, we use __PRETTY_FUNCTION__ to get the name of the swizzle class
 Then we get the implementation of that selector on the swizzle class
 Then we call it directly, passing in the correct selector and self
 
 */
ZKIMP ZKOriginalImplementation(id self, SEL sel, const char *info) {
    if (sel == NULL)
        return NULL;

    NSString *sig = @(info);
    NSRange bracket = [sig rangeOfString:@"["];
    if (bracket.location != NSNotFound || bracket.length != 1) {
        NSLog(@"Couldn't find swizzle class for info: %s", info);
        return NULL;
    }
    sig = [sig substringFromIndex:bracket.location + bracket.length];
    
    NSRange brk = [sig rangeOfString:@" "];
    sig = [sig substringToIndex:brk.location];

    Class cls = objc_getClass(sig.UTF8String);
    Class dest = object_getClass(self);
    if (cls == NULL || dest == NULL)
        return NULL;

    // works for class methods and instance methods because we call object_getClass
    // which gives us a metaclass if the object is a Class which a Class is an instace of
    Method method = class_isMetaClass(dest) ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
    if (method == NULL) {
        NSLog(@"null method for %@ on %@", sig, NSStringFromSelector(sel));
        return NULL;
    }
    
    return (ZKIMP)method_getImplementation(method);
}

ZKIMP ZKSuperImplementation(id object, SEL sel) {
    Class cls = object_getClass(object);
    if (cls == NULL)
        return NULL;

    BOOL classMethod = NO;
    if (class_isMetaClass(cls)) {
        cls = object;
        classMethod = YES;
    }
    
    cls = class_getSuperclass(cls);
    
    // This is a root class, it has no super class
    if (cls == NULL) {
        return NULL;
    }
    
    Method method = classMethod ?  class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
    if (method == NULL)
        return NULL;
    
    return (ZKIMP)method_getImplementation(method);
}

static BOOL enumerateMethods(Class, Class);

@implementation ZKSwizzle

+ (BOOL)swizzleClass:(Class)source {
    return [self swizzleClass:source forClass:[source superclass]];
}

+ (BOOL)swizzleClass:(Class)source forClass:(Class)destination {
    BOOL success = enumerateMethods(destination, source);
    // The above method only gets instance methods. Do the same method for the metaclass of the class
    success     &= enumerateMethods(object_getClass(destination), object_getClass(source));
    
    return success;
}
@end

static BOOL enumerateMethods(Class destination, Class source) {
    unsigned int methodCount;
    Method *methodList = class_copyMethodList(source, &methodCount);
    BOOL success = NO;
    
    for (int i = 0; i < methodCount; i++) {
        Method method = methodList[i];
        SEL selector  = method_getName(method);
        NSString *methodName = NSStringFromSelector(selector);

        // We only swizzle methods that are implemented
        if (class_respondsToSelector(destination, selector)) {
            Method originalMethod = class_getInstanceMethod(destination, selector);

            const char *originalType = method_getTypeEncoding(originalMethod);
            const char *newType = method_getTypeEncoding(method);
            if (strcmp(originalType, newType) != 0) {
                NSLog(@"ZKSwizzle: incompatible type encoding for %@. (expected %s, got %s)", methodName, originalType, newType);
                // Incompatible type encoding
                success = NO;
                continue;
            }
            
            // We are re-adding the destination selector because it could be on a superclass and not on the class itself. This method could fail
            class_addMethod(destination, selector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
            
            method_exchangeImplementations(class_getInstanceMethod(destination, selector), method);
            
            success &= YES;
        } else {
            // Add any extra methods to the class but don't swizzle them
            success &= class_addMethod(destination, selector, method_getImplementation(method), method_getTypeEncoding(method));
        }
    }
    
    unsigned int propertyCount;
    objc_property_t *propertyList = class_copyPropertyList(source, &propertyCount);
    for (int i = 0; i < propertyCount; i++) {
        objc_property_t property = propertyList[i];
        const char *name = property_getName(property);
        unsigned int attributeCount;
        objc_property_attribute_t *attributes = property_copyAttributeList(property, &attributeCount);
        
        if (class_getProperty(destination, name) == NULL) {
            class_addProperty(destination, name, attributes, attributeCount);
        } else {
            class_replaceProperty(destination, name, attributes, attributeCount);
        }
        
        free(attributes);
    }
    
    free(propertyList);
    free(methodList);
    return success;
}
