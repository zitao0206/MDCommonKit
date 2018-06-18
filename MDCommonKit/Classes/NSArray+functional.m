//
//  NSArray+functional.m
//  MDProject
//
//  Created by lizitao on 17/3/12.
//  Copyright © 2017年 lizitao. All rights reserved.
//

#import "NSArray+functional.h"

@implementation NSArray (functional1)

- (void)DP_eachWithIndex:(DPEnumerateBlock)block {
    NSInteger index = 0;
    for (id obj in self) {
        block(index, obj);
        index++;
    }
}

- (NSArray *)DP_map:(DPTransformBlock)block{
    NSParameterAssert(block != nil);
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:self.count];
    for (id obj in self) {
        [ret addObject:block(obj)];
    }
    return ret;
}

- (NSArray *)DP_select:(DPValidationBlock)block{
    NSParameterAssert(block != nil);
	return [self objectsAtIndexes:[self indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return block(obj);
	}]];
}

- (NSArray *)DP_reject:(DPValidationBlock)block{
    NSParameterAssert(block != nil);
	
	return [self objectsAtIndexes:[self indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
		return !block(obj);
	}]];
}

- (id)DP_reduce:(id)initial withBlock:(DPAccumulationBlock)block {
	NSParameterAssert(block != nil);
	id result = initial;
    
    for (id obj in self) {
        result = block(result, obj);
    }
	return result;
}

- (instancetype)DP_take:(NSUInteger)n {
    if ([self count] <= n) return self;
    return [self subarrayWithRange:NSMakeRange(0, n)];
}

- (id)DP_find:(DPValidationBlock)block {
    for (id obj in self) {
        if (block(obj)) {
            return obj;
        }
    }
    return nil;
}

- (id)DP_match:(DPValidationBlock)block {
    for (id object in self) {
        if (block(object)) {
            return object;
        }
    }
    return nil;
}

- (BOOL)DP_allObjectsMatched:(DPValidationBlock)block {
    for (id obj in self) {
        if (!block(obj)) {
            return NO;
        }
    }
    return YES;
}

- (BOOL)DP_anyObjectMatched:(DPValidationBlock)block {
    for (id obj in self) {
        if (block(obj)) {
            return YES;
        }
    }
    return NO;
}

- (NSString *)DP_join:(NSString *)seperator {
    NSMutableString *string = [NSMutableString string];
    [self DP_eachWithIndex:^(NSInteger index, id obj) {
        if (index != 0) {
            [string appendString:seperator];
        }
        [string appendString:obj];
    }];
    return string;
    
}

- (BOOL)DP_existObjectMatch:(DPValidationBlock)block {
    return [self DP_match:block] != nil;
}

- (BOOL)DP_allObjectMatch:(DPValidationBlock)block {
    return [self DP_match:^BOOL(id obj) {
        return !block(obj);
    }] == nil;
}

- (NSArray *)DP_groupBy:(DPTransformBlock)block {
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    for (id obj in self) {
        NSString *key = block(obj);
        if (dic[key] == nil) {
            dic[key] = [NSMutableArray array];
        }
        [dic[key] addObject:obj];
    }
    return [dic allValues];
}

- (NSArray *)DP_zip:(NSArray *)array {
    NSMutableArray *result = [NSMutableArray array];
    [self DP_eachWithIndex:^(NSInteger index, id obj) {
        [result addObject:obj];
        if (index >= array.count) return;
        [result addObject:array[index]];
    }];
    return result;
}

- (NSString *)DP_insertIntoPlaceHolderString:(NSString *)placeHolder {
    NSArray *components = [placeHolder componentsSeparatedByString:@"%%"];
    if ([components count] < 2) return placeHolder;
    return [[components DP_zip:self] DP_join:@""];
}

@end
