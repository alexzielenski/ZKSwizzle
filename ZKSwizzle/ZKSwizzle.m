//
//  ZKSwizzle.m
//  ZKSwizzle
//
//  Created by Alexander S Zielenski on 7/24/14.
//  Copyright (c) 2014 Alexander S Zielenski. All rights reserved.
//

#import "ZKSwizzle.h"

#define kOPOrigPrefix @"_old"

void *ZKIvarPointer(id self, const char *name) {
    Ivar ivar = class_getInstanceVariable(object_getClass(self), name);
    return ivar == NULL ? NULL : (__bridge void *)self + ivar_getOffset(ivar);
}

ZKIMP ZKOriginalImplementation(id object, SEL sel) {
    Class cls = object_getClass(object);
    if (cls == NULL)
        return NULL;
    
    SEL oldSel = NSSelectorFromString([kOPOrigPrefix stringByAppendingString: NSStringFromSelector(sel)]);
    // works for class methods and instance methods because we call object_getClass
    // which gives us a metaclass if the object is a Class which a Class is an instace of
    Method method = class_getInstanceMethod(cls, oldSel);
    if (method == NULL)
        return NULL;
    
    return (ZKIMP)method_getImplementation(method);
}

ZKIMP ZKSuperImplementation(id object, SEL sel) {
    Class cls = object_getClass(object);
    if (cls == NULL)
        return NULL;
    if (class_isMetaClass(cls))
        cls = object;
    
    cls = class_getSuperclass(cls);
    
    // This is a root class, it has no super class
    if (cls == NULL) {
        return NULL;
    }
    
    Method method = class_getInstanceMethod(cls, sel);
    if (method == NULL)
        return NULL;
    
    return (ZKIMP)method_getImplementation(method);
}

BOOL enumerateMethods(Class, Class);

@implementation ZKSwizzle

+ (BOOL)swizzleClass:(Class)source {
    return [self swizzleClass:source forClass:[source superclass]];
}

+ (BOOL)swizzleClass:(Class)source forClass:(Class)destination {
    BOOL success = enumerateMethods(destination, source);
    // The above method only gets instance variables. Do the same method for the metaclass of the class
    success     &= enumerateMethods(object_getClass(destination), object_getClass(source));
    
    return success;
}
@end

BOOL enumerateMethods(Class destination, Class source) {
    unsigned int methodCount;
    Method *methodList = class_copyMethodList(source, &methodCount);
    BOOL success = NO;
    
    for (int i = 0; i < methodCount; i++) {
        Method method = methodList[i];
        SEL selector  = method_getName(method);
        NSString *methodName = NSStringFromSelector(selector);
        
        
        // We only swizzle methods that are implemented
        if (class_respondsToSelector(destination, selector)) {
            // Since the prefix is valid, get the name of the method to swizzle on the destination class by removing the prefix
            SEL destinationSelector = NSSelectorFromString([kOPOrigPrefix stringByAppendingString:methodName]);
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
            // Add the implementation of the replaced method at the prefixed selector
            class_addMethod(destination, destinationSelector, method_getImplementation(method), method_getTypeEncoding(method));
            
            // Retrieve the two new methods at their respective paths
            Method m1 = class_getInstanceMethod(destination, selector);
            Method m2 = class_getInstanceMethod(destination, destinationSelector);
            
            method_exchangeImplementations(m1, m2);
            
            success &= YES;
            
        } else {
            // Add any extra methods to the class but don't swizzle them
            class_addMethod(destination, selector, method_getImplementation(method), method_getTypeEncoding(method));
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
