//
//  NVObject.m
//  Nova
//
//  Created by Yimin Tu on 12-6-1.
//  Copyright (c) 2012年 dianping.com. All rights reserved.
//

#import "NVObject.h"

//#define API_URL @"http://yimin.dp:88/API.txt"

#define ERR_EOF -1
#define ERR_MALFORMED -2

int32_t __dpobj_hash16(NSString *str) {
	NSInteger len = [str length];
	unichar buffer[len];
	[str getCharacters:buffer range:NSMakeRange(0, len)];
	
	int32_t hash = 0;
	for(NSInteger i = 0; i < len; i++) {
		hash = 31 * hash + buffer[i];
	}
	
	int32_t hash16 = (0xFFFF & hash) ^ ((0xFFFF) & (hash >> 16));
	return hash16;
}

int32_t __dpobj_skipAny(const uint8_t *buffer, size_t length) {
    if(length <= 0)
        return ERR_EOF;
	uint8_t c = *(buffer++);
	switch (c) {
		case 'I':
			return 4 < length ? 5 : ERR_EOF;
		case 'S':
			if(2 < length) {
				uint16_t t = *((uint16_t *)buffer);
				t = (t << 8) | (t >> 8);
				size_t strLen = t;
				return (int32_t)(2 + strLen < length ? 3 + strLen : ERR_EOF);
			} else {
				return ERR_EOF;
			}
		case 'N':
		case 'T':
		case 'F':
			return 1;
		case 'L':
		case 'D':
			return 8 < length ? 9 : ERR_EOF;
		case 'U':
			return 4 < length ? 5 : ERR_EOF;
		case 'O': {
			buffer += 2;
			int32_t offset = 4;
			while(offset <= length) {
				uint8_t b = *(buffer++);
				if(b == 'M') {
					buffer += 2;
					offset += 2;
					if(offset < length) {
						int32_t skips = __dpobj_skipAny(buffer, length - offset);
						if(skips > 0) {
							buffer += skips;
							offset += skips;
						} else {
							return skips;
						}
					} else {
						return ERR_EOF;
					}
				} else if(b == 'Z') {
					return offset;
				} else {
					return ERR_MALFORMED;
				}
				offset++;
			}
			return ERR_EOF;
		}
		case 'A': {
			if(2 < length) {
				uint16_t t = *((uint16_t *)buffer);
				t = (t << 8) | (t >> 8);
                int32_t offset = 3;
				size_t arrLen = t;
				buffer += 2;
				while((arrLen--) > 0) {
                    if(offset >= length) {
                        return ERR_EOF;
                    }
					int32_t skips = __dpobj_skipAny(buffer, length - offset);
					if(skips > 0) {
						buffer += skips;
						offset += skips;
					} else {
						return skips;
					}
				}
				return offset;
			}
			return ERR_EOF;
		}
		default:
			return ERR_MALFORMED;
	}
}

int32_t __dpobj_seekMember(const uint8_t *buffer, size_t length, int32_t hash) {
    if(length < 6)
        return ERR_EOF;
    const uint8_t *cur = buffer;
	const uint8_t *end = buffer + length;
	cur += 3;
	while (cur < end - 2) {
		uint8_t m = *(cur++);
		if(m != 'M') {
			return m == 'Z' ? ERR_EOF : ERR_MALFORMED;
		}
		uint16_t member = *((uint16_t *)cur);
		member = (member << 8) | (member >> 8);
		cur += 2;
		if(member == hash) {
			return (int32_t)(cur - buffer);
		}
		int32_t skips = __dpobj_skipAny(cur, end - cur);
		if(skips > 0) {
			cur += skips;
		} else {
			return skips;
		}
	}
	return ERR_EOF;
}

// only contains a-z | A-Z | 0-9
// uid = ID
// lowerName = LowerName
// return nil if illegal (eg. contains ':' or '_')
NSString *__dpobj_nameFromSelector(SEL aSelector) {
    NSString *name = NSStringFromSelector(aSelector);
    NSInteger len = [name length];
    unichar buf[len];
    [name getCharacters:buf range:NSMakeRange(0, len)];
    unichar *p = buf;
    if(len == 3 && *p == 'u' && *(p+1) == 'i' && *(p+2) == 'd') {
        return @"ID";
    }
    BOOL dirty = NO;
    for(unichar *e = p+len; p < e; ++p) {
        unichar c = *p;
        if(c >= 'A' && c <= 'Z') {
            // totally legal
        } else if(c >= 'a' && c <= 'z') {
            // first character should be upper case
            if(p == buf) {
                c += ('A' - 'a');
                *p = c;
                dirty = YES;
            }
        } else if(c >= '0' && c <= '9') {
            // first character is illegal
            // but we shouldn't worry about it
        } else {
            // other character is illegal
            return nil;
        }
    }
    return dirty ? [NSString stringWithCharacters:buf length:len] : name;
}

NSString *__dpobj_selectorName(NSString *name) {
    if([name isEqualToString:@"ID"]) {
        return @"uid";
    }
    NSInteger len = [name length];
    unichar buf[len];
    [name getCharacters:buf range:NSMakeRange(0, len)];
    unichar c0 = buf[0];
    if(c0 >= 'A' && c0 <= 'Z') {
        buf[0] = c0 - ('A' - 'a');
    }
    return [NSString stringWithCharacters:buf length:len];
}


static BOOL __dpobj_apiLoaded = NO;
static NSDictionary *__dpobj_apiMap = nil;
static BOOL __dpobj_apiVerify = NO;
static NSString *__dpobj_lastKey = nil;

@interface NVObjectFieldDef : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *type;
- (id)initWithName:(NSString *)n type:(NSString *)t;
@end

@interface NVObjectClassDef : NSObject {
    NSDictionary *fieldMap;
}
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *parent;
@property (nonatomic, readonly) NSArray *fields;
- (id)initWithName:(NSString *)n parent:(NSString *)p fields:(NSArray *)f;
- (NSString *)typeForHash:(NSInteger)hash16;
@end


@interface NVObjectForward : NSObject {
    id obj;
}

- (id)initWithObject:(id)o;
- (id)theObject;

@end

@implementation NVObjectForward

- (id)initWithObject:(id)o {
    if(self = [super init]) {
        obj = o;
    }
    return self;
}
- (id)theObject {
    return obj;
}

@end


@interface NVObject () {
    @private
    uint64_t forwardCache;  // high: 0xffffffff00000000L is the selector
                            // low:  0x00000000ffffffffL is the skips
    
    @public
    NSData *data;
    size_t start;
    size_t length;
    const uint8_t *buffer;
}

@end

@implementation NVObject

#pragma mark - Init

- (id)initWithData:(NSData *)d start:(NSUInteger)st length:(NSUInteger)len {
    if(self = [super init]) {
        data = d;
        start = st;
        buffer = (uint8_t *)[d bytes] + st;
        length = len;
    }
    return self;
}

- (id)initWithData:(NSData *)d {
    return [self initWithData:d start:0 length:[d length]];
}

- (id)initWithBytes:(const void *)bytes length:(NSUInteger)len {
    NSData *d = [NSData dataWithBytes:bytes length:len];
    return [self initWithData:d start:0 length:len];
}

- (id)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)len freeWhenDone:(BOOL)fwd {
    NSData *d = [NSData dataWithBytesNoCopy:bytes length:len freeWhenDone:fwd];
    return [self initWithData:d start:0 length:len];
}

- (id)initWithClassHash:(NSInteger)hash {
    uint8_t buf[4];
    buf[0] = 'O';
    buf[1] = (uint8_t)(hash >> 8);
    buf[2] = (uint8_t)hash;
    buf[3] = 'Z';
    return [self initWithBytes:buf length:4];
}

- (id)init {
    return [self initWithData:nil start:0 length:0];
}

- (id)initWithClassName:(NSString *)className {
    return [self initWithClassHash:__dpobj_hash16(className)];
}

+ (id)objectWithData:(NSData *)data start:(NSUInteger)start length:(NSUInteger)len {
    return [[self alloc] initWithData:data start:start length:len];
}
+ (id)objectWithData:(NSData *)data {
    return [[self alloc] initWithData:data];
}
+ (id)objectWithBytes:(const void *)bytes length:(NSUInteger)len {
    return [[self alloc] initWithBytes:bytes length:len];
}
+ (id)objectWithBytesNoCopy:(void *)bytes length:(NSUInteger)len freeWhenDone:(BOOL)fwd {
    return [[self alloc] initWithBytesNoCopy:bytes length:len freeWhenDone:fwd];
}
+ (id)objectWithClassHash:(NSInteger)hash {
    return [[self alloc] initWithClassHash:hash];
}
+ (id)objectWithClassName:(NSString *)className {
    return [[self alloc] initWithClassName:className];
}
+ (id)object {
    return [[self alloc] init];
}

#pragma mark - Array

+ (NSArray *)arrayWithData:(NSData *)data start:(NSUInteger)start length:(NSUInteger)len {
    if(len <= 0)
        return nil;
    NSUInteger skips = start;
    const uint8_t *buffer = [data bytes];
    uint8_t b = buffer[skips];
    if(b == 'A' && 2 < len) {
        size_t n = ((0xFF & buffer[skips+1]) << 8) | (0xFF & buffer[skips+2]);
        if(n == 0)
            return [NSArray array];
        skips += 3;
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:n];
        for(int i = 0; i < n; i++) {
            b = buffer[skips];
            if(b != 'O') {
                return nil;
            }
            int32_t sk = __dpobj_skipAny(buffer + skips, len - skips);
            if(sk > 0) {
                NVObject *obj = [[NVObject alloc] initWithData:data start:start + skips length:sk];
                [arr addObject:obj];
                skips += sk;
            } else {
                return nil;
            }
        }
        return arr;
    } else if(b == 'N') {
        return nil;
    }
    return nil;
}
+ (NSArray *)arrayWithData:(NSData *)data {
    return [self arrayWithData:data start:0 length:[data length]];
}
+ (NSArray *)arrayWithBytes:(const void *)bytes length:(NSUInteger)len {
    NSData *d = [NSData dataWithBytes:bytes length:len];
    return [self arrayWithData:d start:0 length:len];
}
+ (NSArray *)arrayWithBytesNoCopy:(void *)bytes length:(NSUInteger)len freeWhenDone:(BOOL)fwd {
    NSData *d = [NSData dataWithBytesNoCopy:bytes length:len freeWhenDone:fwd];
    return [self arrayWithData:d start:0 length:len];
}

#pragma mark - Hash16

- (BOOL)isClassHash:(NSInteger)hash {
    if(length > 0 && buffer[0] == 'O') {
        NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
        return n == hash;
    }
    return NO;
}
- (BOOL)isClassName:(NSString *)className {
    return [self isClassHash:__dpobj_hash16(className)];
}

- (BOOL)hasHash:(NSInteger)hash {
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    return skips > 0;
}
- (BOOL)hasKey:(NSString *)name {
    return [self hasHash:__dpobj_hash16(name)];
}

#pragma mark - Getters

- (BOOL)booleanForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            if(![type isEqualToString:@"boolean"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not boolean", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0 && skips < length) {
        uint8_t b = buffer[skips];
        if(b == 'T')
            return YES;
    }
    return NO;
}
- (BOOL)booleanForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self booleanForHash:__dpobj_hash16(name)];
}

- (NSInteger)integerForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            if(![type isEqualToString:@"int"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not int", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0 && skips + 4 < length) {
        uint8_t b = buffer[skips];
        if(b == 'I') {
            NSInteger i = ((0xFF & buffer[skips+1]) << 24)
                        | ((0xFF & buffer[skips+2]) << 16)
                        | ((0xFF & buffer[skips+3]) << 8)
                        | ((0xFF & buffer[skips+4]));
            return i;
        }
    }
    return 0;
}
- (NSInteger)integerForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self integerForHash:__dpobj_hash16(name)];
}

- (NSString *)stringForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            if(![type isEqualToString:@"string"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not string", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0 && skips < length) {
        uint8_t b = buffer[skips];
        if(b == 'S' && skips + 2 < length) {
            size_t bufLen = ((0xFF & buffer[skips+1]) << 8) | (0xFF & buffer[skips+2]);
            if(bufLen == 0)
                return @"";
            if(skips + 2 + bufLen < length) {
                NSString *str = [[NSString alloc] initWithBytes:buffer+skips+3 length:bufLen encoding:NSUTF8StringEncoding];
                return str;
            }
        } else if(b == 'N') {
            return nil;
        }
    }
    return nil;
}
- (NSString *)stringForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self stringForHash:__dpobj_hash16(name)];
}

- (int64_t)longForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            if(![type isEqualToString:@"long"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not long", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0 && skips + 8 < length) {
        uint8_t b = buffer[skips];
        if(b == 'L') {
            int64_t l = ((uint64_t)(0xFFL & buffer[skips+1]) << 56)
                      | ((uint64_t)(0xFFL & buffer[skips+2]) << 48)
                      | ((uint64_t)(0xFFL & buffer[skips+3]) << 40)
                      | ((uint64_t)(0xFFL & buffer[skips+4]) << 32)
                      | ((uint64_t)(0xFFL & buffer[skips+5]) << 24)
                      | ((uint64_t)(0xFFL & buffer[skips+6]) << 16)
                      | ((uint64_t)(0xFFL & buffer[skips+7]) << 8)
                      | ((uint64_t)(0xFFL & buffer[skips+8]));
            return l;
        }
    }
    return 0L;
}
- (int64_t)longForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self longForHash:__dpobj_hash16(name)];
}

- (double)doubleForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            if(![type isEqualToString:@"double"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not double", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0 && skips + 8 < length) {
        uint8_t b = buffer[skips];
        if(b == 'D') {
            int64_t l = ((uint64_t)(0xFFL & buffer[skips+1]) << 56)
                      | ((uint64_t)(0xFFL & buffer[skips+2]) << 48)
                      | ((uint64_t)(0xFFL & buffer[skips+3]) << 40)
                      | ((uint64_t)(0xFFL & buffer[skips+4]) << 32)
                      | ((uint64_t)(0xFFL & buffer[skips+5]) << 24)
                      | ((uint64_t)(0xFFL & buffer[skips+6]) << 16)
                      | ((uint64_t)(0xFFL & buffer[skips+7]) << 8)
                      | ((uint64_t)(0xFFL & buffer[skips+8]));
            double d = *((double *)&l);
            return d;
        }
    }
    return .0;
}
- (double)doubleForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self doubleForHash:__dpobj_hash16(name)];
}

- (NSTimeInterval)timeForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            if(![type isEqualToString:@"time"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not time", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0 && skips + 4 < length) {
        uint8_t b = buffer[skips];
        if(b == 'U') {
            NSInteger i = ((0xFF & buffer[skips+1]) << 24)
                        | ((0xFF & buffer[skips+2]) << 16)
                        | ((0xFF & buffer[skips+3]) << 8)
                        | ((0xFF & buffer[skips+4]));
            return i;
        }
    }
    return 0;
}
- (NSTimeInterval)timeForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self timeForHash:__dpobj_hash16(name)];
}

- (NVObject *)objectForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            // TODO: check THE object type
            if([type hasSuffix:@"[]"]
               || [type isEqualToString:@"int"]
               || [type isEqualToString:@"string"]
               || [type isEqualToString:@"boolean"]
               || [type isEqualToString:@"double"]
               || [type isEqualToString:@"long"]
               || [type isEqualToString:@"time"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not object", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0) {
        uint8_t b = buffer[skips];
        if(b == 'O' && skips + 2 < length) {
            return [[NVObject alloc] initWithData:data start:start + skips length:length - skips];
        } else if(b == 'N') {
            return nil;
        }
    }
    return nil;
}
- (NVObject *)objectForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self objectForHash:__dpobj_hash16(name)];
}

- (NSArray *)arrayForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            if(![type hasSuffix:@"[]"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not array", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0) {
        uint8_t b = buffer[skips];
        if(b == 'A' && skips + 2 < length) {
            size_t n = ((0xFF & buffer[skips+1]) << 8) | (0xFF & buffer[skips+2]);
            if(n == 0)
                return [NSArray array];
            skips += 3;
            NSMutableArray *arr = [NSMutableArray arrayWithCapacity:n];
            for(int i = 0; i < n; i++) {
                b = skips < length ? buffer[skips] : 0;
                if(b != 'O') {
                    return nil;
                }
                int32_t sk = __dpobj_skipAny(buffer + skips, length - skips);
                if(sk > 0) {
                    NVObject *obj = [[NVObject alloc] initWithData:data start:start + skips length:sk];
                    [arr addObject:obj];
                    skips += sk;
                } else {
                    return nil;
                }
            }
            return arr;
        } else if(b == 'N') {
            return nil;
        }
    }
    return nil;
}
- (NSArray *)arrayForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self arrayForHash:__dpobj_hash16(name)];
}

- (NSArray *)integerArrayForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            if(![type hasSuffix:@"[]"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not array", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0) {
        uint8_t b = buffer[skips];
        if(b == 'A' && skips + 2 < length) {
            size_t n = ((0xFF & buffer[skips+1]) << 8) | (0xFF & buffer[skips+2]);
            if(n == 0)
                return [NSArray array];
            skips += 3;
            NSMutableArray *arr = [NSMutableArray arrayWithCapacity:n];
            for(int i = 0; i < n; i++) {
                if(skips + 4 < length && buffer[skips] == 'I') {
                    NSInteger k = ((0xFF & buffer[skips+1]) << 24)
                                | ((0xFF & buffer[skips+2]) << 16)
                                | ((0xFF & buffer[skips+3]) << 8)
                                | ((0xFF & buffer[skips+4]));
                    skips += 5;
                    NSNumber *m = [NSNumber numberWithInteger:k];
                    [arr addObject:m];
                } else {
                    return nil;
                }
            }
            return arr;
        } else if(b == 'N') {
            return nil;
        }
    }
    return nil;
}
- (NSArray *)integerArrayForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self integerArrayForHash:__dpobj_hash16(name)];
}

- (NSArray *)stringArrayForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            if(![type hasSuffix:@"[]"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not array", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0) {
        uint8_t b = buffer[skips];
        if(b == 'A' && skips + 2 < length) {
            size_t n = ((0xFF & buffer[skips+1]) << 8) | (0xFF & buffer[skips+2]);
            if(n == 0)
                return [NSArray array];
            skips += 3;
            NSMutableArray *arr = [NSMutableArray arrayWithCapacity:n];
            for(int i = 0; i < n; i++) {
                if(skips + 2 < length && buffer[skips] == 'S') {
                    size_t bufLen = ((0xFF & buffer[skips+1]) << 8) | (0xFF & buffer[skips+2]);
                    skips += 3;
                    NSString *str = @"";
                    if(bufLen > 0) {
                        if(skips + bufLen <= length) {
                            str = [[NSString alloc] initWithBytes:buffer+skips length:bufLen encoding:NSUTF8StringEncoding];
                            skips += bufLen;
                        } else {
                            return nil;
                        }
                    }
                    [arr addObject:str];
                } else {
                    return nil;
                }
            }
            return arr;
        } else if(b == 'N') {
            return nil;
        }
    }
    return nil;
}
- (NSArray *)stringArrayForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self stringArrayForHash:__dpobj_hash16(name)];
}

- (NSArray *)timeArrayForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            if(![type hasSuffix:@"[]"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not array", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0) {
        uint8_t b = buffer[skips];
        if(b == 'A' && skips + 2 < length) {
            size_t n = ((0xFF & buffer[skips+1]) << 8) | (0xFF & buffer[skips+2]);
            if(n == 0)
                return [NSArray array];
            skips += 3;
            NSMutableArray *arr = [NSMutableArray arrayWithCapacity:n];
            for(int i = 0; i < n; i++) {
                if(skips + 4 < length && buffer[skips] == 'U') {
                    NSInteger k = ((0xFF & buffer[skips+1]) << 24)
                                | ((0xFF & buffer[skips+2]) << 16)
                                | ((0xFF & buffer[skips+3]) << 8)
                                | ((0xFF & buffer[skips+4]));
                    skips += 5;
                    NSDate *t = [NSDate dateWithTimeIntervalSince1970:k];
                    [arr addObject:t];
                } else {
                    return nil;
                }
            }
            return arr;
        } else if(b == 'N') {
            return nil;
        }
    }
    return nil;
}
- (NSArray *)timeArrayForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self timeArrayForHash:__dpobj_hash16(name)];
}

- (NSArray *)anyArrayForHash:(NSInteger)hash {
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx is undefined", (long)n] userInfo:nil];
            }
            NSString *guessName = __dpobj_lastKey;
            if(guessName && hash != __dpobj_hash16(guessName)) {
                guessName = nil;
            }
            NSString *type = [cd typeForHash:hash];
            if(!type) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is undefined", cd.name, guessName, (long)hash] userInfo:nil];
            }
            if(![type hasSuffix:@"[]"]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ (0x%lx) is not array", cd.name, guessName, (long)hash] userInfo:nil];
            }
        }
    }
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    if(skips > 0) {
        uint8_t b = buffer[skips];
        if(b == 'A' && skips + 2 < length) {
            size_t n = ((0xFF & buffer[skips+1]) << 8) | (0xFF & buffer[skips+2]);
            if(n == 0)
                return [NSArray array];
            skips += 3;
            NSMutableArray *arr = [NSMutableArray arrayWithCapacity:n];
            for(int i = 0; i < n; i++) {
                if(skips >= length) {
                    return nil;
                }
                b = buffer[skips];
                if(b == 'O') {
                    int32_t sk = __dpobj_skipAny(buffer + skips, length - skips);
                    if(sk > 0) {
                        NVObject *obj = [[NVObject alloc] initWithData:data start:start + skips length:sk];
                        [arr addObject:obj];
                        skips += sk;
                    } else {
                        return nil;
                    }
                } else if(b == 'I' && skips + 4 < length) {
                    NSInteger k = ((0xFF & buffer[skips+1]) << 24)
                    | ((0xFF & buffer[skips+2]) << 16)
                    | ((0xFF & buffer[skips+3]) << 8)
                    | ((0xFF & buffer[skips+4]));
                    skips += 5;
                    NSNumber *m = [NSNumber numberWithInteger:k];
                    [arr addObject:m];
                } else if(b == 'S' && skips + 2 < length) {
                    size_t bufLen = ((0xFF & buffer[skips+1]) << 8) | (0xFF & buffer[skips+2]);
                    skips += 3;
                    NSString *str = @"";
                    if(bufLen > 0) {
                        if(skips + bufLen <= length) {
                            str = [[NSString alloc] initWithBytes:buffer+skips length:bufLen encoding:NSUTF8StringEncoding];
                            skips += bufLen;
                        } else {
                            return nil;
                        }
                    }
                    [arr addObject:str];
                } else if(b == 'L' && skips + 8 < length) {
                    int64_t l = ((uint64_t)(0xFFL & buffer[skips+1]) << 56)
                    | ((uint64_t)(0xFFL & buffer[skips+2]) << 48)
                    | ((uint64_t)(0xFFL & buffer[skips+3]) << 40)
                    | ((uint64_t)(0xFFL & buffer[skips+4]) << 32)
                    | ((uint64_t)(0xFFL & buffer[skips+5]) << 24)
                    | ((uint64_t)(0xFFL & buffer[skips+6]) << 16)
                    | ((uint64_t)(0xFFL & buffer[skips+7]) << 8)
                    | ((uint64_t)(0xFFL & buffer[skips+8]));
                    skips += 9;
                    NSNumber *m = [NSNumber numberWithLongLong:l];
                    [arr addObject:m];
                } else if(b == 'D') {
                    int64_t l = ((uint64_t)(0xFFL & buffer[skips+1]) << 56)
                    | ((uint64_t)(0xFFL & buffer[skips+2]) << 48)
                    | ((uint64_t)(0xFFL & buffer[skips+3]) << 40)
                    | ((uint64_t)(0xFFL & buffer[skips+4]) << 32)
                    | ((uint64_t)(0xFFL & buffer[skips+5]) << 24)
                    | ((uint64_t)(0xFFL & buffer[skips+6]) << 16)
                    | ((uint64_t)(0xFFL & buffer[skips+7]) << 8)
                    | ((uint64_t)(0xFFL & buffer[skips+8]));
                    double d = *((double *)&l);
                    skips += 9;
                    NSNumber *m = [NSNumber numberWithDouble:d];
                    [arr addObject:m];
                } else if(b == 'U' && skips + 4 < length) {
                    NSInteger k = ((0xFF & buffer[skips+1]) << 24)
                    | ((0xFF & buffer[skips+2]) << 16)
                    | ((0xFF & buffer[skips+3]) << 8)
                    | ((0xFF & buffer[skips+4]));
                    skips += 5;
                    NSDate *t = [NSDate dateWithTimeIntervalSince1970:k];
                    [arr addObject:t];
                } else if(b == 'T') {
                    [arr addObject:[NSNumber numberWithBool:YES]];
                } else if(b == 'F') {
                    [arr addObject:[NSNumber numberWithBool:NO]];
                } else if(b == 'N'){
                    [arr addObject:[NSNull null]];
                } else {
                    return nil;
                }
            }
            return arr;
        } else if(b == 'N') {
            return nil;
        }
    }
    return nil;
}
- (NSArray *)anyArrayForKey:(NSString *)name {
    if(__dpobj_apiVerify) {
        __dpobj_lastKey = name;
    }
    return [self anyArrayForHash:__dpobj_hash16(name)];
}


#pragma mark - Forwarding

#define METHOD_SIGNATURE(TYPE) [NSMethodSignature signatureWithObjCTypes:[[NSString stringWithFormat:@"%s@:", @encode(TYPE)] cStringUsingEncoding:NSASCIIStringEncoding]]

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    static NSMethodSignature *msBOOL = nil;
    static NSMethodSignature *msINT = nil;
    static NSMethodSignature *msDOUBLE = nil;
    static NSMethodSignature *msLONG = nil;
    static NSMethodSignature *msTIME = nil;
    static NSMethodSignature *msID = nil;
    
    NSMethodSignature *sig = [super methodSignatureForSelector:aSelector];
    if(sig)
        return sig;
    
    NSString *name = __dpobj_nameFromSelector(aSelector);
    if(!name)
        return nil;
    NSInteger hash = __dpobj_hash16(name);
    int32_t skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    
    // save forward cache anyway
    uint64_t hi = 0xffffffffL & (uint32_t)sel_getName(aSelector);
    hi = hi << 32;
    uint64_t lo = 0xffffffffL & skips;
    forwardCache = hi | lo;
    
    if(skips > 0 && skips < length) {
        uint8_t b = buffer[skips];
        switch (b) {
            case 'I':
                if(!msINT) {
                    msINT = METHOD_SIGNATURE(NSInteger);
                }
                return msINT;
            case 'T':
            case 'F':
                if(!msBOOL) {
                    msBOOL = METHOD_SIGNATURE(BOOL);
                }
                return msBOOL;
            case 'N':
            case 'S':
            case 'O':
            case 'A':
                if(!msID) {
                    msID = METHOD_SIGNATURE(id);
                }
                return msID;
            case 'D':
                if(!msDOUBLE) {
                    msDOUBLE = METHOD_SIGNATURE(double);
                }
                return msDOUBLE;
            case 'L':
                if(!msLONG) {
                    msLONG = METHOD_SIGNATURE(int64_t);
                }
                return msLONG;
            case 'U':
                if(!msTIME) {
                    msTIME = METHOD_SIGNATURE(NSTimeInterval);
                }
                return msTIME;
            default:
                break;
        }
    }
    // default return 0 (64bit)
#if TARGET_IPHONE_SIMULATOR
    // double will return NaN as default in simulator
    // need to fix this issue
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if(aSelector == @selector(latitude) ||
       aSelector == @selector(longitude) ||
       aSelector == @selector(offsetLat) ||
       aSelector == @selector(offsetLng) ||
       aSelector == @selector(lat) ||
       aSelector == @selector(lng)) {
        if(!msDOUBLE) {
            msDOUBLE = METHOD_SIGNATURE(double);
        }
        return msDOUBLE;
    }
    #pragma clang diagnostic pop
#endif
    if(!msLONG) {
        msLONG = METHOD_SIGNATURE(int64_t);
    }
    return msLONG;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    int32_t skips;
    
    SEL aSelector = [anInvocation selector];
    NSString *name = nil;
    uint64_t cache = forwardCache;
    uint64_t hi = 0xffffffffL & (uint32_t)sel_getName(aSelector);
    if(hi == cache >> 32) {
        skips = cache & 0xffffffffL;
    } else {
        name = __dpobj_nameFromSelector(aSelector);
        if(!name) {
            [super forwardInvocation:anInvocation];
            return;
        }
        NSInteger hash = __dpobj_hash16(name);
        skips = __dpobj_seekMember(buffer, length, (int32_t)hash);
    }
    
    if(__dpobj_apiVerify && [__dpobj_apiMap count]) {
        if(length > 0 && buffer[0] == 'O') {
            NSInteger n = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
            NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:n]];
            if(!cd) {
                @throw [NSException exceptionWithName:@"NVObjectClassNotDefined" reason:[NSString stringWithFormat:@"0x%lx not defined", (long)n] userInfo:nil];
            }
            if(!name) {
                name = __dpobj_nameFromSelector(aSelector);
            }
            if(![cd typeForHash:__dpobj_hash16(name)]) {
                @throw [NSException exceptionWithName:@"NVObjectFieldNotDefined" reason:[NSString stringWithFormat:@"%@.%@ not defined", cd.name, name] userInfo:nil];
            }
        }
    }
    
    uint64_t ZERO = 0;
    if(skips > 0 && skips < length) {
        uint8_t b = buffer[skips];
        switch (b) {
            case 'I': {
                if(skips + 4 < length) {
                    NSInteger i = ((0xFF & buffer[skips+1]) << 24)
                    | ((0xFF & buffer[skips+2]) << 16)
                    | ((0xFF & buffer[skips+3]) << 8)
                    | ((0xFF & buffer[skips+4]));
                    [anInvocation setReturnValue:&i];
                    return;
                }
                [anInvocation setReturnValue:&ZERO];
                return;
            }
            case 'T': {
                BOOL b = YES;
                [anInvocation setReturnValue:&b];
                return;
            }
            case 'F': {
                BOOL b = NO;
                [anInvocation setReturnValue:&b];
                return;
            }
            case 'N': {
                [anInvocation setReturnValue:&ZERO];
                return;
            }
            case 'S': {
                if(skips + 2 < length) {
                    size_t bufLen = ((0xFF & buffer[skips+1]) << 8) | (0xFF & buffer[skips+2]);
                    if(bufLen == 0) {
                        NVObjectForward *fwd = [[NVObjectForward alloc] initWithObject:@""];
                        [anInvocation setSelector:@selector(theObject)];
                        [anInvocation invokeWithTarget:fwd];
                        return;
                    }
                    if(skips + 2 + bufLen < length) {
                        NSString *str = [[NSString alloc] initWithBytes:buffer+skips+3 length:bufLen encoding:NSUTF8StringEncoding];
                        NVObjectForward *fwd = [[NVObjectForward alloc] initWithObject:str];
                        [anInvocation setSelector:@selector(theObject)];
                        [anInvocation invokeWithTarget:fwd];
                        return;
                    }
                }
                [anInvocation setReturnValue:&ZERO];
                return;
            }
            case 'O': {
                if(skips + 2 < length) {
                    NVObject *obj = [[NVObject alloc] initWithData:data start:start + skips length:length - skips];
                    NVObjectForward *fwd = [[NVObjectForward alloc] initWithObject:obj];
                    [anInvocation setSelector:@selector(theObject)];
                    [anInvocation invokeWithTarget:fwd];
                    return;
                }
                [anInvocation setReturnValue:&ZERO];
                return;
            }
            case 'A': {
                name = name ? name : __dpobj_nameFromSelector(aSelector);
                NSInteger hash = __dpobj_hash16(name);
                NSArray *anyArray = [self anyArrayForHash:hash];
                if(anyArray) {
                    NVObjectForward *fwd = [[NVObjectForward alloc] initWithObject:anyArray];
                    [anInvocation setSelector:@selector(theObject)];
                    [anInvocation invokeWithTarget:fwd];
                } else {
                    [anInvocation setReturnValue:&ZERO];
                }
                return;
            }
            case 'D': {
                if(skips + 8 < length) {
                    int64_t l = ((uint64_t)(0xFFL & buffer[skips+1]) << 56)
                    | ((uint64_t)(0xFFL & buffer[skips+2]) << 48)
                    | ((uint64_t)(0xFFL & buffer[skips+3]) << 40)
                    | ((uint64_t)(0xFFL & buffer[skips+4]) << 32)
                    | ((uint64_t)(0xFFL & buffer[skips+5]) << 24)
                    | ((uint64_t)(0xFFL & buffer[skips+6]) << 16)
                    | ((uint64_t)(0xFFL & buffer[skips+7]) << 8)
                    | ((uint64_t)(0xFFL & buffer[skips+8]));
                    double d = *((double *)&l);
                    [anInvocation setReturnValue:&d];
                    return;
                }
                [anInvocation setReturnValue:&ZERO];
                return;
            }
            case 'L': {
                if(skips + 8 < length) {
                    int64_t l = ((uint64_t)(0xFFL & buffer[skips+1]) << 56)
                    | ((uint64_t)(0xFFL & buffer[skips+2]) << 48)
                    | ((uint64_t)(0xFFL & buffer[skips+3]) << 40)
                    | ((uint64_t)(0xFFL & buffer[skips+4]) << 32)
                    | ((uint64_t)(0xFFL & buffer[skips+5]) << 24)
                    | ((uint64_t)(0xFFL & buffer[skips+6]) << 16)
                    | ((uint64_t)(0xFFL & buffer[skips+7]) << 8)
                    | ((uint64_t)(0xFFL & buffer[skips+8]));
                    [anInvocation setReturnValue:&l];
                    return;
                }
                [anInvocation setReturnValue:&ZERO];
                return;
            }
            case 'U': {
                if(skips + 4 < length) {
                    NSInteger i = ((0xFF & buffer[skips+1]) << 24)
                    | ((0xFF & buffer[skips+2]) << 16)
                    | ((0xFF & buffer[skips+3]) << 8)
                    | ((0xFF & buffer[skips+4]));
                    NSTimeInterval ti = i;
                    [anInvocation setReturnValue:&ti];
                    return;
                }
                [anInvocation setReturnValue:&ZERO];
                return;
            }
            default:
                break;
        }
    }
    
    // default return 0 (64bit)
    [anInvocation setReturnValue:&ZERO];
}


#pragma mark - Model Print & Check

+ (NSDictionary *)parseApiMap:(NSData *)d {
    NSString *str = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    NSArray *lines = [str componentsSeparatedByString:@"\n"];
    NSMutableArray *classes = [[NSMutableArray alloc] init];
    NSString *className = nil;
    NSString *parentName = nil;
    NSMutableArray *fields = [[NSMutableArray alloc] initWithCapacity:32];
    for(NSString *l in lines) {
        NSArray *words = [l componentsSeparatedByString:@"\t"];
        if([words count] == 0)
            continue;
        NSString *c1 = [words objectAtIndex:0];
        NSString *c2 = [words count] > 1 ? [words objectAtIndex:1] : nil;
        NSString *c3 = [words count] > 2 ? [words objectAtIndex:2] : nil;
        if([c1 length]) {
            if(className) {
                NVObjectClassDef *cd = [[NVObjectClassDef alloc] initWithName:className parent:parentName fields:[fields copy]];
                [classes addObject:cd];
            }
            className = c1;
            parentName = [c2 length] ? c2 : nil;
            [fields removeAllObjects];
        } else if([c2 length]) {
            NVObjectFieldDef *fd = [[NVObjectFieldDef alloc] initWithName:c2 type:c3];
            [fields addObject:fd];
        }
    }
    if(className) {
        NVObjectClassDef *cd = [[NVObjectClassDef alloc] initWithName:className parent:parentName fields:[fields copy]];
        [classes addObject:cd];
    }
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:[classes count]];
    for(NVObjectClassDef *cd in classes) {
        [dict setObject:cd forKey:[[NSNumber alloc] initWithInteger:__dpobj_hash16(cd.name)]];
    }
    
    return [dict copy];
}

+ (BOOL)loadApiFromUrl:(NSString *)url {
    NSURLRequest *req = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:5];
    NSURLResponse *resp = nil;
    NSData *result = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:NULL];
    if([result length] && [resp isKindOfClass:[NSHTTPURLResponse class]] && [(NSHTTPURLResponse *)resp statusCode] == 200) {
        __dpobj_apiMap = [self parseApiMap:result];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *dir = [paths objectAtIndex:0];
        NSString *path = [dir stringByAppendingPathComponent:@"api.txt"];
        [result writeToFile:path atomically:YES];
        return YES;
    } else {
        return NO;
    }
}

+ (BOOL)loadApiFromFile {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *dir = [paths objectAtIndex:0];
    NSString *path = [dir stringByAppendingPathComponent:@"api.txt"];
    NSData *d = [[NSData alloc] initWithContentsOfFile:path];
    if(d) {
        __dpobj_apiMap = [self parseApiMap:d];
        return YES;
    }
    return NO;
}

+ (void)loadApi {
        
//    if([[NVEnvironment defaultEnvironment] isDebug] && ![self loadApiFromUrl:API_URL]) {
//        NVLOG(@"fail to load api map from %@", API_URL);
//        [self loadApiFromFile];
//    }
}

+ (BOOL)appendDepsList:(NSMutableArray *)list name:(NSString *)className map:(NSDictionary *)map {
    NVObjectClassDef *cd = [map objectForKey:[NSNumber numberWithInteger:__dpobj_hash16(className)]];
    if(!cd)
        return NO;
    if([list containsObject:className])
        return YES;
    if([cd.parent length]) {
        if(![self appendDepsList:list name:cd.parent map:map]) {
            NSLog(@"fail to find %@'s parent class %@", className, cd.parent);
            return NO;
        }
    }
    for(NVObjectFieldDef *fd in cd.fields) {
        NSString *type = fd.type;
        if([type hasSuffix:@"[]"] ||
           [type isEqualToString:@"int"] ||
           [type isEqualToString:@"string"] ||
           [type isEqualToString:@"boolean"] ||
           [type isEqualToString:@"double"] ||
           [type isEqualToString:@"long"] ||
           [type isEqualToString:@"time"]) {
            // primary type, ignore
        } else {
            if(![self appendDepsList:list name:type map:map]) {
                NSLog(@"fail to find %@.%@'s field class %@", className, fd.name, type);
                return NO;
            }
        }
    }
    if([list containsObject:className]) {
        NSLog(@"infinite loop in %@'s deps", className);
        return NO;
    }
    [list addObject:className];
    return YES;
}

- (NSString *)_code {
    if(!__dpobj_apiLoaded) {
        [NVObject loadApi];
        __dpobj_apiLoaded = YES;
    }
    if(!__dpobj_apiMap) {
        return nil;
    }
    NSInteger hash = 0;
    if(length > 0 && buffer[0] == 'O') {
        hash = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
    }
    NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:hash]];
    NSMutableArray *arr = [NSMutableArray array];
    if([NVObject appendDepsList:arr name:cd.name map:__dpobj_apiMap]) {
        NSMutableString *buf = [NSMutableString string];
        for(NSString *className in arr) {
            cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:__dpobj_hash16(className)]];
            [buf appendString:[cd description]];
            [buf appendString:@"\n\n"];
        }
        return buf;
    } else {
        return nil;
    }
}

+ (NSString *)_code {
    if(!__dpobj_apiLoaded) {
        [NVObject loadApi];
        __dpobj_apiLoaded = YES;
    }
    if(!__dpobj_apiMap) {
        return nil;
    }
    NSMutableArray *arr = [NSMutableArray array];
    for(NVObjectClassDef *cd in [__dpobj_apiMap allValues]) {
        if(![NVObject appendDepsList:arr name:cd.name map:__dpobj_apiMap])
            return nil;
    }
    NSMutableString *buf = [NSMutableString string];
    for(NSString *className in arr) {
        NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:__dpobj_hash16(className)]];
        [buf appendString:[cd description]];
        [buf appendString:@"\n\n"];
    }
    return buf;
}

// <prefix>Name : Value,\n
- (void)appendField:(NSMutableString *)buf prefix:(NSString *)prefix classDef:(NVObjectClassDef *)cd {
    if([cd.parent length]) {
        NVObjectClassDef *pcd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:__dpobj_hash16(cd.parent)]];
        if(pcd) {
            [self appendField:buf prefix:prefix classDef:pcd];
        }
    }
    for(NVObjectFieldDef *fd in cd.fields) {
        NSString *name = fd.name;
        if(![self hasKey:name])
            continue;
        NSString *type = fd.type;
        if([type hasSuffix:@"[]"]) {
            NSArray *arr = [self anyArrayForKey:name];
            if([arr count]) {
                [buf appendFormat:@"%@%@ : [\n", prefix, name];
                NSString *prefix2 = [NSString stringWithFormat:@"  %@", prefix];
                for(id o in arr) {
                    [buf appendString:prefix2];
                    if([o isKindOfClass:[NVObject class]]) {
                        NVObject *obj = o;
                        [obj appendDescription:buf prefix:prefix2];
                    } else if([o isKindOfClass:[NSString class]]) {
                        NSString *str = o;
                        if([str rangeOfString:@"\""].location == NSNotFound) {
                            [buf appendFormat:@"\"%@\"", str];
                        } else {
                            [buf appendFormat:@"'%@'", str];
                        }
                    } else if([o isKindOfClass:[NSNumber class]]) {
                        NSNumber *n = o;
                        [buf appendFormat:@"%@", @([n integerValue])];
                    } else if([o isKindOfClass:[NSDate class]]) {
                        NSDate *t = o;
                        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
                        [fmt setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                        [buf appendString:[fmt stringFromDate:t]];
                    } else if([o isKindOfClass:[NSNull class]]) {
                        [buf appendString:@"null"];
                    } else {
                        [buf appendString:@"???"];
                    }
                    [buf appendString:@",\n"];
                }
                [buf appendFormat:@"%@],\n", prefix];
            } else if(arr) {
                [buf appendFormat:@"%@%@ : [],\n", prefix, name];
            } else {
                [buf appendFormat:@"%@%@ : null,\n", prefix, name];
            }
        } else if([type isEqualToString:@"int"]) {
            [buf appendFormat:@"%@%@ : %@,\n", prefix, name, @([self integerForKey:name])];
        } else if([type isEqualToString:@"string"]) {
            NSString *str = [self stringForKey:name];
            if(str) {
                if([str rangeOfString:@"\""].location == NSNotFound) {
                    [buf appendFormat:@"%@%@ : \"%@\",\n", prefix, name, str];
                } else {
                    [buf appendFormat:@"%@%@ : '%@',\n", prefix, name, str];
                }
            } else {
                [buf appendFormat:@"%@%@ : null,\n", prefix, name];
            }
        } else if([type isEqualToString:@"boolean"]) {
            [buf appendFormat:@"%@%@ : %@,\n", prefix, name, [self booleanForKey:name] ? @"true" : @"false"];
        } else if([type isEqualToString:@"double"]) {
            [buf appendFormat:@"%@%@ : %f,\n", prefix, name, [self doubleForKey:name]];
        } else if([type isEqualToString:@"long"]) {
            [buf appendFormat:@"%@%@ : %lldL,\n", prefix, name, [self longForKey:name]];
        } else if([type isEqualToString:@"time"]) {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            [fmt setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSDate *t = [[NSDate alloc] initWithTimeIntervalSince1970:[self timeForKey:name]];
            [buf appendFormat:@"%@%@ : %@,\n", prefix, name, [fmt stringFromDate:t]];
        } else {
            NVObject *obj = [self objectForKey:name];
            if(obj) {
                [buf appendFormat:@"%@%@ : ", prefix, name];
                [obj appendDescription:buf prefix:prefix];
                [buf appendString:@",\n"];
            } else {
                [buf appendFormat:@"%@%@ : null,\n", prefix, name];
            }
        }
    }
}

// append prefix but first line
- (void)appendDescription:(NSMutableString *)buf prefix:(NSString *)prefix {
    NSInteger hash = 0;
    if(length > 0 && buffer[0] == 'O') {
        hash = ((0xFF & buffer[1]) << 8) | (0xFF & buffer[2]);
    }
    NVObjectClassDef *cd = [__dpobj_apiMap objectForKey:[NSNumber numberWithInteger:hash]];
    if(cd) {
        [buf appendFormat:@"%@ {\n", cd.name];
        [self appendField:buf prefix:[NSString stringWithFormat:@"  %@", prefix] classDef:cd];
        [buf appendFormat:@"%@}", prefix];
    } else {
        [buf appendFormat:@"%@ {\n}", cd.name];
    }
}

- (NSString *)description {
//    if([[NVEnvironment defaultEnvironment] isDebug]) {
//        if(!__dpobj_apiLoaded) {
//            [NVObject loadApi];
//            __dpobj_apiLoaded = YES;
//        }
//        if(!__dpobj_apiMap) {
//            return [super description];
//        }
//        NSMutableString *str = [[NSMutableString alloc] init];
//        [self appendDescription:str prefix:@""];
//        return str;
//    } else {
        return [super description];
//    }
}

//因为API_URL服务已经不再维持了，所以验证过程将不再生效，不影响现在代码逻辑
void NVInternalSetObjectVerify(BOOL verify) {
    __dpobj_apiVerify = verify;
    if(verify) {
        [NVObject loadApi];
        __dpobj_apiLoaded = YES;
    }
}


#pragma mark - Misc

+ (NSInteger)hash:(NSString *)name {
    return __dpobj_hash16(name);
}

- (NSData *)dump {
    int32_t skips = __dpobj_skipAny(buffer, length);
    if(skips > 0) {
        return [NSData dataWithBytes:buffer length:skips];
    } else {
        return nil;
    }
}

- (NVObjectEditor *)edit {
    return [[NVObjectEditor alloc] initWithObject:self];
}


#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    NSData *d = [decoder decodeObjectForKey:@"data"];
    return [self initWithData:d start:0 length:[d length]];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    NSData *d = [self dump];
    [encoder encodeObject:d forKey:@"data"];
}

@end


#pragma mark -
#pragma mark -

#pragma mark - Editor

@interface NVObjectEditCont : NSObject {
    @public
    NSInteger hash;
    NSInteger type; // TFILDUSOA, R=Remove, B=int[], C=String[], Y=NSDate[]
    NSInteger I;
    int64_t L;
    double D;
    NSTimeInterval U;
    NSString *S;
    NVObject *O;
    NSArray *A; // include B, C, Y
}

- (void)writeTo:(NSMutableData *)data;

- (void)writeObject:(NVObject *)obj to:(NSMutableData *)data;
- (void)writeString:(NSString *)str to:(NSMutableData *)data;

@end

@implementation NVObjectEditCont

- (void)writeTo:(NSMutableData *)data {
    uint8_t buf[9];
    switch (type) {
        case 'I': {
            uint32_t t = (uint32_t)I;
            buf[0] = 'I';
            buf[1] = t >> 24;
            buf[2] = t >> 16;
            buf[3] = t >> 8;
            buf[4] = t;
            [data appendBytes:buf length:5];
            break;
        }
        case 'L': {
            uint64_t t = L;
            buf[0] = 'L';
            buf[1] = t >> 56;
            buf[2] = t >> 48;
            buf[3] = t >> 40;
            buf[4] = t >> 32;
            buf[5] = t >> 24;
            buf[6] = t >> 16;
            buf[7] = t >> 8;
            buf[8] = t;
            [data appendBytes:buf length:9];
            break;
        }
        case 'D': {
            uint64_t t = *((uint64_t *)&D);
            buf[0] = 'D';
            buf[1] = t >> 56;
            buf[2] = t >> 48;
            buf[3] = t >> 40;
            buf[4] = t >> 32;
            buf[5] = t >> 24;
            buf[6] = t >> 16;
            buf[7] = t >> 8;
            buf[8] = t;
            [data appendBytes:buf length:9];
            break;
        }
        case 'T': {
            buf[0] = 'T';
            [data appendBytes:buf length:1];
            break;
        }
        case 'F': {
            buf[0] = 'F';
            [data appendBytes:buf length:1];
            break;
        }
        case 'U': {
            uint32_t t = (uint32_t)U;
            buf[0] = 'U';
            buf[1] = t >> 24;
            buf[2] = t >> 16;
            buf[3] = t >> 8;
            buf[4] = t;
            [data appendBytes:buf length:5];
            break;
        }
        case 'S': {
            [self writeString:S to:data];
            break;
        }
        case 'O': {
            [self writeObject:O to:data];
            break;
        }
        case 'A': {
            if(A) {
                uint32_t t = (uint32_t)[A count];
                if(t > 0xFFFF) {
                    t = 0xFFFF;
                }
                buf[0] = 'A';
                buf[1] = t >> 8;
                buf[2] = t;
                [data appendBytes:buf length:3];
                uint32_t i = 0;
                for(NVObject *obj in A) {
                    if(i++ < t) {
                        [self writeObject:obj to:data];
                    } else {
                        break;
                    }
                }
            } else {
                buf[0] = 'N';
                [data appendBytes:buf length:1];
            }
            break;
        }
        case 'B': {
            if(A) {
                uint32_t t = (uint32_t)[A count];
                if(t > 0xFFFF) {
                    t = 0xFFFF;
                }
                buf[0] = 'A';
                buf[1] = t >> 8;
                buf[2] = t;
                [data appendBytes:buf length:3];
                uint32_t i = 0;
                for(NSNumber *num in A) {
                    if(i++ < t) {
                        uint32_t t = (uint32_t)[num integerValue];
                        buf[0] = 'I';
                        buf[1] = t >> 24;
                        buf[2] = t >> 16;
                        buf[3] = t >> 8;
                        buf[4] = t;
                        [data appendBytes:buf length:5];
                    } else {
                        break;
                    }
                }
            } else {
                buf[0] = 'N';
                [data appendBytes:buf length:1];
            }
            break;
        }
        case 'C': {
            if(A) {
                uint32_t t = (uint32_t)[A count];
                if(t > 0xFFFF) {
                    t = 0xFFFF;
                }
                buf[0] = 'A';
                buf[1] = t >> 8;
                buf[2] = t;
                [data appendBytes:buf length:3];
                uint32_t i = 0;
                for(NSString *str in A) {
                    if(i++ < t) {
                        [self writeString:str to:data];
                    } else {
                        break;
                    }
                }
            } else {
                buf[0] = 'N';
                [data appendBytes:buf length:1];
            }
            break;
        }
        case 'Y': {
            if(A) {
                uint32_t t = (uint32_t)[A count];
                if(t > 0xFFFF) {
                    t = 0xFFFF;
                }
                buf[0] = 'A';
                buf[1] = t >> 8;
                buf[2] = t;
                [data appendBytes:buf length:3];
                uint32_t i = 0;
                for(NSDate *date in A) {
                    if(i++ < t) {
                        uint32_t t = (uint32_t)[date timeIntervalSince1970];
                        buf[0] = 'U';
                        buf[1] = t >> 24;
                        buf[2] = t >> 16;
                        buf[3] = t >> 8;
                        buf[4] = t;
                        [data appendBytes:buf length:5];
                    } else {
                        break;
                    }
                }
            } else {
                buf[0] = 'N';
                [data appendBytes:buf length:1];
            }
            break;
        }
        default:
            break;
    }
}

- (void)writeObject:(NVObject *)obj to:(NSMutableData *)data {
    uint8_t buf[4];
    if(obj) {
        int32_t skips = __dpobj_skipAny(obj->buffer, obj->length);
        if(skips > 0) {
            [data appendBytes:obj->buffer length:skips];
        } else {
            buf[0] = 'O';
            buf[1] = 0;
            buf[2] = 0;
            buf[3] = 'Z';
            [data appendBytes:buf length:4];
        }
    } else {
        buf[0] = 'N';
        [data appendBytes:buf length:1];
    }
}

- (void)writeString:(NSString *)str to:(NSMutableData *)data {
    uint8_t buf[4];
    if(str) {
        NSData *d = [str dataUsingEncoding:NSUTF8StringEncoding];
        uint32_t t = (uint32_t)[d length];
        if(t > 0xFFFF) {
            t = 0xFFFF;
            buf[0] = 'S';
            buf[1] = t >> 8;
            buf[2] = t;
            [data appendBytes:buf length:3];
            [data appendBytes:[d bytes] length:t];
        } else {
            buf[0] = 'S';
            buf[1] = t >> 8;
            buf[2] = t;
            [data appendBytes:buf length:3];
            [data appendData:d];
        }
    } else {
        buf[0] = 'N';
        [data appendBytes:buf length:1];
    }
}

@end

@interface NVObjectEditor () {
    NVObject *base;
    NSMutableArray *ops;
}

@end

@implementation NVObjectEditor

- (id)initWithObject:(NVObject *)obj {
    if(self = [super init]) {
        base = obj;
        ops = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)init {
    return [self initWithObject:nil];
}

- (NVObjectEditor *)setBoolean:(BOOL)val forHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = (val ? 'T' : 'F');
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)setBoolean:(BOOL)val forKey:(NSString *)name {
    return [self setBoolean:val forHash:__dpobj_hash16(name)];
}

- (NVObjectEditor *)setInteger:(NSInteger)val forHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = 'I';
    cont->I = val;
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)setInteger:(NSInteger)val forKey:(NSString *)name {
    return [self setInteger:val forHash:__dpobj_hash16(name)];
}

- (NVObjectEditor *)setString:(NSString *)val forHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = 'S';
    cont->S = val;
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)setString:(NSString *)val forKey:(NSString *)name {
    return [self setString:val forHash:__dpobj_hash16(name)];
}

- (NVObjectEditor *)setLong:(int64_t)val forHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = 'L';
    cont->L = val;
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)setLong:(int64_t)val forKey:(NSString *)name {
    return [self setLong:val forHash:__dpobj_hash16(name)];
}

- (NVObjectEditor *)setDouble:(double)val forHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = 'D';
    cont->D = val;
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)setDouble:(double)val forKey:(NSString *)name {
    return [self setDouble:val forHash:__dpobj_hash16(name)];
}

- (NVObjectEditor *)setTime:(NSTimeInterval)val forHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = 'U';
    cont->U = val;
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)setTime:(NSTimeInterval)val forKey:(NSString *)name {
    return [self setTime:val forHash:__dpobj_hash16(name)];
}

- (NVObjectEditor *)setObject:(NVObject *)val forHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = 'O';
    cont->O = val;
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)setObject:(NVObject *)val forKey:(NSString *)name {
    return [self setObject:val forHash:__dpobj_hash16(name)];
}

- (NVObjectEditor *)setArray:(NSArray *)val forHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = 'A';
    cont->A = val;
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)setArray:(NSArray *)val forKey:(NSString *)name {
    return [self setArray:val forHash:__dpobj_hash16(name)];
}

- (NVObjectEditor *)setIntegerArray:(NSArray *)val forHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = 'B';
    cont->A = val;
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)setIntegerArray:(NSArray *)val forKey:(NSString *)name {
    return [self setIntegerArray:val forHash:__dpobj_hash16(name)];
}

- (NVObjectEditor *)setStringArray:(NSArray *)val forHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = 'C';
    cont->A = val;
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)setStringArray:(NSArray *)val forKey:(NSString *)name {
    return [self setStringArray:val forHash:__dpobj_hash16(name)];
}

- (NVObjectEditor *)setTimeArray:(NSArray *)val forHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = 'Y';
    cont->A = val;
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)setTimeArray:(NSArray *)val forKey:(NSString *)name {
    return [self setTimeArray:val forHash:__dpobj_hash16(name)];
}

- (NVObjectEditor *)removeForHash:(NSInteger)hash {
    NVObjectEditCont *cont = [[NVObjectEditCont alloc] init];
    cont->hash = hash;
    cont->type = 'R';
    [ops addObject:cont];
    return self;
}
- (NVObjectEditor *)removeForKey:(NSString *)name {
    return [self removeForHash:__dpobj_hash16(name)];
}

- (NVObject *)generate {
    NSMutableData *data = [[NSMutableData alloc] init];
    uint8_t buf[4];
    int32_t length = base ? (int32_t)(base->length) : 0;
    const uint8_t *buffer = base ? base->buffer : 0;
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:[ops count]];
    for(NVObjectEditCont *cont in ops) {
        NSNumber *key = [[NSNumber alloc] initWithInteger:cont->hash];
        [dict setObject:cont forKey:key];
    }
    buf[0] = 'O';
    [data appendBytes:buf length:1];
    if(length > 2) {
        [data appendBytes:buffer + 1 length:2];
    } else {
        buf[0] = 0;
        buf[1] = 0;
        [data appendBytes:buf length:2];
    }
    
    int32_t skips = 3;
    while(skips < length) {
        uint8_t b = buffer[skips++];
        if(b == 'M') {
            if(!(skips + 2 < length))
               break;
            NSInteger hash = ((0xFF & buffer[skips]) << 8) | (0xFF & buffer[skips+1]);
            skips += 2;
            NSNumber *key = [NSNumber numberWithInteger:hash];
            NVObjectEditCont *cont = [dict objectForKey:key];
            int32_t sk = __dpobj_skipAny(buffer + skips, length - skips);
            if(cont) {
                if(cont->type != 'R') {
                    buf[0] = 'M';
                    buf[1] = hash >> 8;
                    buf[2] = hash;
                    [data appendBytes:buf length:3];
                    [cont writeTo:data];
                }
                [dict removeObjectForKey:key];
            } else {
                if(sk > 0) {
                    buf[0] = 'M';
                    buf[1] = hash >> 8;
                    buf[2] = hash;
                    [data appendBytes:buf length:3];
                    [data appendBytes:buffer + skips length:sk];
                } else {
                    break;
                }
            }
            if(sk > 0) {
                skips += sk;
            } else {
                break;
            }
        } else {
            break;
        }
    }
    
    for(NVObjectEditCont *ocont in ops) {
        NSNumber *key = [NSNumber numberWithInteger:ocont->hash];
        NVObjectEditCont *cont = [dict objectForKey:key];
        if(cont) {
            if(cont->type != 'R') {
                buf[0] = 'M';
                buf[1] = cont->hash >> 8;
                buf[2] = cont->hash;
                [data appendBytes:buf length:3];
                [cont writeTo:data];
            }
            [dict removeObjectForKey:key];
        }
    }
    
    buf[0] = 'Z';
    [data appendBytes:buf length:1];
    
    if(base) {
        return [[[base class] alloc] initWithData:data];
    } else {
        return [[NVObject alloc] initWithData:data];
    }
}

@end














#pragma mark -
#pragma mark -

#pragma mark - Model Print & Check

@implementation NVObjectFieldDef

@synthesize name, type;

- (id)initWithName:(NSString *)n type:(NSString *)t {
    if(self = [super init]) {
        name = n;
        type = t;
    }
    return self;
}

- (NSString *)description {
    NSString *n = __dpobj_selectorName(name);
    
    NSString *fixARC = @"";
    if([n hasPrefix:@"alloc"] || [n hasPrefix:@"copy"] || [n hasPrefix:@"mutableCopy"] || [n hasPrefix:@"new"]) {
        fixARC = @"__attribute__((ns_returns_autoreleased)) ";
    }
    
    NSString *t = type;
    if([t hasSuffix:@"[]"]) {
        return [NSString stringWithFormat:@"- (NSArray *)%@%@;", fixARC, n];
    }
    if([t isEqualToString:@"int"]) {
        return [NSString stringWithFormat:@"- (NSInteger)%@;", n];
    }
    if([t isEqualToString:@"string"]) {
        return [NSString stringWithFormat:@"- (NSString *)%@%@;", fixARC, n];
    }
    if([t isEqualToString:@"boolean"]) {
        return [NSString stringWithFormat:@"- (BOOL)%@;", n];
    }
    if([t isEqualToString:@"double"]) {
        return [NSString stringWithFormat:@"- (double)%@;", n];
    }
    if([t isEqualToString:@"long"]) {
        return [NSString stringWithFormat:@"- (int64_t)%@;", n];
    }
    if([t isEqualToString:@"time"]) {
        return [NSString stringWithFormat:@"- (NSTimeInterval)%@;", n];
    }
    return [NSString stringWithFormat:@"- (%@ *)%@%@;", t, fixARC, n];
}

@end

@implementation NVObjectClassDef

@synthesize name, parent, fields;

- (id)initWithName:(NSString *)n parent:(NSString *)p fields:(NSArray *)f {
    if(self = [super init]) {
        name = n;
        parent = p;
        fields = f;
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:[f count]];
        for(NVObjectFieldDef *field in f) {
            [dict setObject:field forKey:[[NSNumber alloc] initWithInteger:__dpobj_hash16(field.name)]];
        }
        fieldMap = dict;
    }
    return self;
}

- (NSString *)typeForHash:(NSInteger)hash16 {
    NVObjectFieldDef *f = [fieldMap objectForKey:[[NSNumber alloc] initWithInteger:hash16]];
    return f.type;
}

- (NSString *)description {
    NSMutableString *str = [[NSMutableString alloc] init];
    if([parent length]) {
        [str appendFormat:@"@interface %@ : %@\n", name, parent];
    } else {
        [str appendFormat:@"@interface %@ : NVObject\n", name];
    }
    for(NVObjectFieldDef *f in fields) {
        [str appendString:[f description]];
        [str appendString:@"\n"];
    }
    [str appendString:@"@end\n"];
    return str;
}

@end

