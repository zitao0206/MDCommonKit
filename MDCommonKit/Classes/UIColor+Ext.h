//
//  UIColor+Ext.h
//  Pods
//
//  Created by Leon on 3/22/16.
//
//

#import <UIKit/UIKit.h>

@interface UIColor (Ext)

+ (UIColor *)md_ColorWithHexString:(NSString *)hexString;
+ (UIColor *)md_ColorWithHexString:(NSString *)hexString alpha:(CGFloat)alpha;
+ (UIColor *)md_ColorWithIntRed:(NSInteger)r green:(NSInteger)g blue:(NSInteger)b;
+ (UIColor *)md_ColorWithIntRed:(NSInteger)r green:(NSInteger)g blue:(NSInteger)b alpha:(NSInteger)a;

@end

