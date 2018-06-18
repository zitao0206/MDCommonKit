//
//  NVObject.h
//  Nova
//
//  Created by Yimin Tu on 12-6-1.
//  Copyright (c) 2012年 dianping.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NVObjectEditor;

/**
 
 NVObject是一个Key-Value表
 
 */
@interface NVObject : NSObject <NSCoding>

- (id)initWithData:(NSData *)data start:(NSUInteger)start length:(NSUInteger)len;
- (id)initWithData:(NSData *)data;
- (id)initWithBytes:(const void *)bytes length:(NSUInteger)len;
- (id)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)len freeWhenDone:(BOOL)fwd;
- (id)initWithClassHash:(NSInteger)hash;
- (id)initWithClassName:(NSString *)className;

+ (id)objectWithData:(NSData *)data start:(NSUInteger)start length:(NSUInteger)len;
+ (id)objectWithData:(NSData *)data;
+ (id)objectWithBytes:(const void *)bytes length:(NSUInteger)len;
+ (id)objectWithBytesNoCopy:(void *)bytes length:(NSUInteger)len freeWhenDone:(BOOL)fwd;
+ (id)objectWithClassHash:(NSInteger)hash;
+ (id)objectWithClassName:(NSString *)className;
+ (id)object;

+ (NSArray *)arrayWithData:(NSData *)data start:(NSUInteger)start length:(NSUInteger)len;
+ (NSArray *)arrayWithData:(NSData *)data;
+ (NSArray *)arrayWithBytes:(const void *)bytes length:(NSUInteger)len;
+ (NSArray *)arrayWithBytesNoCopy:(void *)bytes length:(NSUInteger)len freeWhenDone:(BOOL)fwd;

/**
 计算ClassName或者FieldName所对应的16位哈希码
 */
+ (NSInteger)hash:(NSString *)name;

/**
 判断对象的类型
 */
- (BOOL)isClassHash:(NSInteger)hash;
- (BOOL)isClassName:(NSString *)className;

/**
 检查对象是否包含Field
 */
- (BOOL)hasHash:(NSInteger)hash;
- (BOOL)hasKey:(NSString *)name;

- (BOOL)booleanForHash:(NSInteger)hash;
- (BOOL)booleanForKey:(NSString *)name;

- (NSInteger)integerForHash:(NSInteger)hash;
- (NSInteger)integerForKey:(NSString *)name;

- (NSString *)stringForHash:(NSInteger)hash;
- (NSString *)stringForKey:(NSString *)name;

- (int64_t)longForHash:(NSInteger)hash;
- (int64_t)longForKey:(NSString *)name;

- (double)doubleForHash:(NSInteger)hash;
- (double)doubleForKey:(NSString *)name;

// seconds since 1970 UTC
- (NSTimeInterval)timeForHash:(NSInteger)hash;
- (NSTimeInterval)timeForKey:(NSString *)name;

- (NVObject *)objectForHash:(NSInteger)hash;
- (NVObject *)objectForKey:(NSString *)name;

// return NVObject array
- (NSArray *)arrayForHash:(NSInteger)hash;
- (NSArray *)arrayForKey:(NSString *)name;

// return NSNumber array
- (NSArray *)integerArrayForHash:(NSInteger)hash;
- (NSArray *)integerArrayForKey:(NSString *)name;

// return NSString array
- (NSArray *)stringArrayForHash:(NSInteger)hash;
- (NSArray *)stringArrayForKey:(NSString *)name;

// return NSDate array
- (NSArray *)timeArrayForHash:(NSInteger)hash;
- (NSArray *)timeArrayForKey:(NSString *)name;

// return NVObject, NSString, NSNumber, NSDate or NSNull array
- (NSArray *)anyArrayForHash:(NSInteger)hash;
- (NSArray *)anyArrayForKey:(NSString *)name;

/**
 把对象转化成元数据
 */
- (NSData *)dump;

/**
 创建一个编辑器
 */
- (NVObjectEditor *)edit;

/**
 打印当前类的描述代码（包括依赖关系）
 API_URL 服务已暂停维护，需要打印请稳步至扩展方法（NVObject+Description.m）
 */
//- (NSString *)_code;
/**
 打印所有类的描述代码（包括依赖关系）
 API_URL 服务已暂停维护，需要打印请稳步至扩展方法（NVObject+Description.m）
 */
//+ (NSString *)_code;

@end


/**
 
 NVObject的对象编辑器
 
 由于NVObject为不可变类型，所以编辑器只能生成对象，不会改变原有的NVObject
 
 */
@interface NVObjectEditor : NSObject

/**
 基于一个NVObject进行修改
 */
- (id)initWithObject:(NVObject *)obj;

- (NVObjectEditor *)setBoolean:(BOOL)val forHash:(NSInteger)hash;
- (NVObjectEditor *)setBoolean:(BOOL)val forKey:(NSString *)name;

- (NVObjectEditor *)setInteger:(NSInteger)val forHash:(NSInteger)hash;
- (NVObjectEditor *)setInteger:(NSInteger)val forKey:(NSString *)name;

- (NVObjectEditor *)setString:(NSString *)val forHash:(NSInteger)hash;
- (NVObjectEditor *)setString:(NSString *)val forKey:(NSString *)name;

- (NVObjectEditor *)setLong:(int64_t)val forHash:(NSInteger)hash;
- (NVObjectEditor *)setLong:(int64_t)val forKey:(NSString *)name;

- (NVObjectEditor *)setDouble:(double)val forHash:(NSInteger)hash;
- (NVObjectEditor *)setDouble:(double)val forKey:(NSString *)name;

- (NVObjectEditor *)setTime:(NSTimeInterval)val forHash:(NSInteger)hash;
- (NVObjectEditor *)setTime:(NSTimeInterval)val forKey:(NSString *)name;

- (NVObjectEditor *)setObject:(NVObject *)val forHash:(NSInteger)hash;
- (NVObjectEditor *)setObject:(NVObject *)val forKey:(NSString *)name;

- (NVObjectEditor *)setArray:(NSArray *)val forHash:(NSInteger)hash;
- (NVObjectEditor *)setArray:(NSArray *)val forKey:(NSString *)name;

- (NVObjectEditor *)setIntegerArray:(NSArray *)val forHash:(NSInteger)hash;
- (NVObjectEditor *)setIntegerArray:(NSArray *)val forKey:(NSString *)name;

- (NVObjectEditor *)setStringArray:(NSArray *)val forHash:(NSInteger)hash;
- (NVObjectEditor *)setStringArray:(NSArray *)val forKey:(NSString *)name;

// set NSDate array
- (NVObjectEditor *)setTimeArray:(NSArray *)val forHash:(NSInteger)hash;
- (NVObjectEditor *)setTimeArray:(NSArray *)val forKey:(NSString *)name;

- (NVObjectEditor *)removeForHash:(NSInteger)hash;
- (NVObjectEditor *)removeForKey:(NSString *)name;

/**
 生成修改后的新对象
 */
- (NVObject *)generate;

@end
