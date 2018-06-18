//
//  NSArray+functional.h
//  MDProject
//
//  Created by lizitao on 17/3/12.
//  Copyright © 2017年 lizitao. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^DPEnumerateBlock)(NSInteger index, id obj);
typedef id (^DPTransformBlock)(id obj);
typedef BOOL (^DPValidationBlock)(id obj);
typedef id (^DPAccumulationBlock)(id sum, id obj);

@interface NSArray (functional1)

/**
 *  enumerate each object in array with index
 *  @warning if index is not needed, prefer forin loop; consider map select reduce first
 *  @param block side effect logic
 */
- (void)DP_eachWithIndex:(DPEnumerateBlock)block;

/**
 *  functional map method
 *
 *  @param block specify mapping relation
 *
 *  @return mapped array
 */
- (NSArray *)DP_map:(DPTransformBlock)block;

/**
 *  function select method
 *
 *  @param block logic to specify which to select
 *
 *  @return new array with selectecd objects
 */
- (NSArray *)DP_select:(DPValidationBlock)block;

/**
 *  functional reject, similar with select
 *
 *  @param block specify which to reject
 *
 *  @return new array with filterd objects
 */
- (NSArray *)DP_reject:(DPValidationBlock)block;

/**
 *  functional reduce method
 *
 *  @param initial sum base
 *  @param block   add logic
 *
 *  @return sum
 */
- (id)DP_reduce:(id)initial withBlock:(DPAccumulationBlock)block;

/**
 *  take first n objects as array, if n > array length, return self
 *
 *  @param n number to take
 *
 *  @return array
 */
- (instancetype)DP_take:(NSUInteger)n;

/**
 *  find the object match condition in array
 *
 *  @param block condition
 *
 *  @return matched object or nil
 */
- (id)DP_find:(DPValidationBlock)block;

/**
 *  check whether all objects in array match condition
 *
 *  @param block condition logic
 *
 *  @return a
 */
- (BOOL)DP_allObjectsMatched:(DPValidationBlock)block;



/**
 *  check whether any object in array match condition
 *
 *  @param block condition logic
 *
 *  @return a
 */
- (BOOL)DP_anyObjectMatched:(DPValidationBlock)block;

/**
 *  join array of string to a string
 *
 *  @param seperator a
 *
 *  @return string
 */
- (NSString *)DP_join:(NSString *)seperator;

/**
 *  return the first matched object in array
 *
 *  @param block match logic
 *
 *  @return the first matched object, if not found, return nil
 */
- (id)DP_match:(DPValidationBlock)block;

/**
 *  check whether array contain matched object
 *
 *  @param block match logic
 *
 *  @return bool
 */
- (BOOL)DP_existObjectMatch:(DPValidationBlock)block;

/**
 *  check whether all objects in array match the validation
 *
 *  @param block validation
 *
 *  @return bool
 */
- (BOOL)DP_allObjectMatch:(DPValidationBlock)block;


- (NSArray *)DP_groupBy:(DPTransformBlock)block;

- (NSArray *)DP_zip:(NSArray *)array;

- (NSString *)DP_insertIntoPlaceHolderString:(NSString *)placeHolder;

@end
