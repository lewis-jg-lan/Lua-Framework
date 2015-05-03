/*
 * LuaVirtualMachine.h
 * GameEditor
 *
 * Copyright (c) 2015 Rhody Lugo.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import <Foundation/Foundation.h>

#pragma mark LuaVirtualMachine

@interface LuaVirtualMachine : NSObject
- (instancetype)init;
+ (void)test;
@end

#pragma mark LuaContext

@class LuaValue;

@interface LuaContext : NSObject
@property (readonly, strong) LuaVirtualMachine *virtualMachine;
- (instancetype)initWithVirtualMachine:(LuaVirtualMachine *)virtualMachine;
- (LuaValue *)evaluateScript:(NSString *)script;
- (LuaValue *)evaluateScriptNamed:(NSString *)filename;
- (id)objectForKeyedSubscript:(id)key;
- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key;
@end

#pragma mark LuaValue

@interface LuaValue : NSObject
@property (readonly, strong) LuaContext *context;
+ (instancetype)valueWithString:(NSString *)string inContext:(LuaContext *)context;
+ (instancetype)valueWithInt32:(int32_t)value inContext:(LuaContext *)context;
- (NSString *)toString;
- (int32_t)toInt32;
- (LuaValue *)callWithArguments:(NSArray *)arguments;
@end
