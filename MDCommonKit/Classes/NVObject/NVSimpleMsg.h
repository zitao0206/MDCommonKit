//
//  NVSimpleMsg.h
//  Core
//
//  Created by Yimin Tu on 12-6-7.
//  Copyright (c) 2012年 dianping.com. All rights reserved.
//

#import "NVObject.h"

@interface NVSimpleMsg : NSObject

@property (nonatomic, readonly) NSInteger statusCode;
@property (strong, nonatomic, readonly) NSString *title;
@property (strong, nonatomic, readonly) NSString *content;
@property (nonatomic, readonly) NSInteger flag;
@property (strong, nonatomic, readonly) NSString *data;

- (id)initWithNVObject:(NVObject *)obj;
- (id)initWithTitle:(NSString *)title content:(NSString *)content flag:(NSInteger)flag;
- (id)initWithStatusCode:(NSInteger)statusCode title:(NSString *)title content:(NSString *)content flag:(NSInteger)flag data:(NSString *)data;

@end
