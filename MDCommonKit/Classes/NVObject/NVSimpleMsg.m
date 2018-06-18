//
//  NVSimpleMsg.m
//  Core
//
//  Created by Yimin Tu on 12-6-7.
//  Copyright (c) 2012年 dianping.com. All rights reserved.
//

#import "NVSimpleMsg.h"

@implementation NVSimpleMsg

@synthesize statusCode;
@synthesize title;
@synthesize content;
@synthesize flag;
@synthesize data;

- (id)init {
    return [self initWithTitle:nil content:nil flag:0];
}
- (id)initWithNVObject:(NVObject *)obj {
    return [self initWithStatusCode:[obj integerForHash:0x8d]
                              title:[obj stringForHash:0x36e9]
                            content:[obj stringForHash:0x57b6]
                               flag:[obj integerForHash:0x73ad]
                               data:[obj stringForHash:0x63ea]];
}
- (id)initWithTitle:(NSString *)t content:(NSString *)c flag:(NSInteger)f {
    return [self initWithStatusCode:0 title:t content:c flag:f data:nil];
}
- (id)initWithStatusCode:(NSInteger)sc title:(NSString *)t content:(NSString *)c flag:(NSInteger)f data:(NSString *)d {
    if(self = [super init]) {
        statusCode = sc;
        title = t;
        content = c;
        flag = f;
        data = d;
    }
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"(%@) %@ - %@ %@", @(statusCode), title, content, data ? data : @""];
}

@end
