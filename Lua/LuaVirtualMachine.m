/*
 * LuaVirtualMachine.m
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

#import "LuaVirtualMachine.h"
#import "LuaObjCBridge.h"
#include <objc/runtime.h>

#pragma mark LuaVirtualMachine

@implementation LuaVirtualMachine {
	lua_State *L;
}

- (instancetype)init {
	if (self = [super init]) {
		L = lua_objc_init();
		luaL_openlibs(L);
	}
	return self;
}

- (lua_State *)state {
	return L;
}

- (void)dealloc {
	lua_close(L);
}

@end

#pragma mark LuaContext

@interface LuaValue ()
- (instancetype)initWithTopOfStackInContext:(LuaContext *)context;
- (int)index;
@end

@implementation LuaContext {
	lua_State *C;
}

@synthesize virtualMachine = _virtualMachine;

- (instancetype)initWithVirtualMachine:(LuaVirtualMachine *)virtualMachine {
	if (self = [super init]) {
		_virtualMachine = virtualMachine;

		lua_State *L = _virtualMachine.state;

		C = lua_newthread(L);

		/* Fix globals */
		lua_newtable(C); /* new table for globals */
		lua_newtable(C); /* metatable for new globals */
		lua_pushliteral(C, "__index");
		lua_pushvalue(C, LUA_GLOBALSINDEX); /* __index tries old common globals */
		lua_settable(C, -3);
		lua_setmetatable(C, -2);
		lua_replace(C, LUA_GLOBALSINDEX);
	}
	return self;
}

- (instancetype)init {
	return [self initWithVirtualMachine:[[LuaVirtualMachine alloc] init]];
}

- (LuaValue *)evaluateScript:(NSString *)script {
	if (script) {
		if (luaL_loadstring(C, script.UTF8String) || lua_pcall(C, 0, LUA_MULTRET, 0)) {
			NSLog(@"Lua error: %s", lua_tostring(C, -1));
			lua_pop(C, 1);
			return nil;
		} else if (lua_gettop(C) && !lua_isnoneornil(C, -1)) {
			return [[LuaValue alloc] initWithTopOfStackInContext:self];
		}
	}
	return nil;
}

- (LuaValue *)evaluateScriptNamed:(NSString *)filename {
	NSString *fullpath = [[NSBundle mainBundle] pathForResource:filename ofType:@"lua"];
	if (fullpath) {
		if (luaL_loadfile(C, fullpath.UTF8String) || lua_pcall(C, 0, LUA_MULTRET, 0)) {
			NSLog(@"Lua error: %s", lua_tostring(C, -1));
			lua_pop(C, 1);
			return nil;
		} else if (lua_gettop(C) && !lua_isnoneornil(C, -1)) {
			return [[LuaValue alloc] initWithTopOfStackInContext:self];
		}
	}
	return nil;
}

- (lua_State *)state {
	return C;
}

- (LuaValue *)objectForKeyedSubscript:(id)key {
	if ([key isKindOfClass:[NSString class]]) {
		lua_getglobal(C, [[self luaKeyWithString:key] UTF8String]);
		if (!lua_isnoneornil(C, -1)) {
			return [[LuaValue alloc] initWithTopOfStackInContext:self];
		}
	}
	return nil;
}

- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key {
	if ([(NSObject *)key isKindOfClass:[NSString class]]) {
		if ([obj isKindOfClass:[LuaValue class]]) {
			lua_rawgeti(self.state, LUA_REGISTRYINDEX, [(LuaValue *)obj index]);
			lua_setglobal(C, [[self luaKeyWithString:(NSString *)key] UTF8String]);
		} else if (lua_objc_pushpropertylist(C, obj)) {
			lua_setglobal(C, [[self luaKeyWithString:(NSString *)key] UTF8String]);
		}
	}
}

- (NSString *)luaKeyWithString:(NSString *)string {
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\W." options:NSRegularExpressionCaseInsensitive error:NULL];
	return [regex stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, [string length]) withTemplate:@"_"];
}

- (void)dealloc {
	//lua_close(C);
}

@end

#pragma mark LuaValue

@implementation LuaValue {
	int _index;
}

@synthesize context = _context;

- (instancetype)initWithContext:(LuaContext *)context {
	if (self = [super init]) {
		_context = context;
	}
	return self;
}

- (void)storeTopOfStack {
	_index = luaL_ref(_context.state, LUA_REGISTRYINDEX);
	NSAssert(_index >= 0, @"An index less or equal than zero means there is no object to be stored");
}

- (instancetype)initWithTopOfStackInContext:(LuaContext *)context {
	if (self = [self initWithContext:context]) {
		[self storeTopOfStack];
	}
	return self;
}

- (instancetype)initWithObject:(id)value inContext:(LuaContext *)context {
	if (self = [self initWithContext:context]) {
		lua_objc_pushpropertylist(_context.state, value);
		[self storeTopOfStack];
	}
	return self;
}

+ (instancetype)valueWithObject:(id)value inContext:(LuaContext *)context {
	return [[self alloc] initWithObject:value inContext:context];
}

- (instancetype)initWithBool:(BOOL)value inContext:(LuaContext *)context {
	if (self = [self initWithContext:context]) {
		lua_pushboolean(_context.state, value);
		[self storeTopOfStack];
	}
	return self;
}

+ (instancetype)valueWithBool:(BOOL)value inContext:(LuaContext *)context {
	return [[self alloc] initWithBool:value inContext:context];
}

- (instancetype)initWithDouble:(double)value inContext:(LuaContext *)context {
	if (self = [self initWithContext:context]) {
		lua_pushnumber(_context.state, value);
		[self storeTopOfStack];
	}
	return self;
}

+ (instancetype)valueWithDouble:(double)value inContext:(LuaContext *)context {
	return [[self alloc] initWithDouble:value inContext:context];
}

- (instancetype)initWithInt32:(int32_t)value inContext:(LuaContext *)context {
	if (self = [self initWithContext:context]) {
		lua_pushinteger(_context.state, value);
		[self storeTopOfStack];
	}
	return self;
}

+ (instancetype)valueWithInt32:(int32_t)value inContext:(LuaContext *)context {
	return [[self alloc] initWithInt32:value inContext:context];
}

- (instancetype)initWithUInt32:(uint32_t)value inContext:(LuaContext *)context {
	if (self = [self initWithContext:context]) {
		lua_pushinteger(_context.state, value);
		[self storeTopOfStack];
	}
	return self;
}

+ (instancetype)valueWithUInt32:(uint32_t)value inContext:(LuaContext *)context {
	return [[self alloc] initWithUInt32:value inContext:context];
}

- (id)toObject {
	lua_rawgeti(_context.state, LUA_REGISTRYINDEX, _index);
	id obj = lua_objc_topropertylist(_context.state, -1);
	lua_pop(_context.state, 1);
	return obj;
}

- (BOOL)toBool {
	lua_rawgeti(_context.state, LUA_REGISTRYINDEX, _index);
	BOOL value = (BOOL)lua_toboolean(_context.state, -1);
	lua_pop(_context.state, 1);
	return value;
}

- (double)toDouble {
	lua_rawgeti(_context.state, LUA_REGISTRYINDEX, _index);
	double value = (double)lua_tonumber(_context.state, -1);
	lua_pop(_context.state, 1);
	return value;
}

- (int32_t)toInt32 {
	lua_rawgeti(_context.state, LUA_REGISTRYINDEX, _index);
	int32_t value = (int32_t)lua_tointeger(_context.state, -1);
	lua_pop(_context.state, 1);
	return value;
}

- (uint32_t)toUInt32 {
	lua_rawgeti(_context.state, LUA_REGISTRYINDEX, _index);
	uint32_t value = (uint32_t)lua_tointeger(_context.state, -1);
	lua_pop(_context.state, 1);
	return value;
}

- (NSNumber *)toNumber {
	id obj = [self toObject];
	if ([obj isKindOfClass:[NSNumber class]]) {
		return obj;
	} else if ([obj isKindOfClass:[NSString class]]) {
		NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
		formatter.numberStyle = NSNumberFormatterDecimalStyle;
		return [formatter numberFromString:obj];
	} else {
		return nil;
	}
}

- (NSString *)toString {
	return [[self toObject] description];
}

- (NSDate *)toDate {
	// seconds since epochTime (1970)
	NSTimeInterval seconds = [self toDouble];
	return [[NSDate alloc] initWithTimeIntervalSince1970:seconds];
}

- (NSArray *)toArray {
	id obj = [self toObject];
	if ([obj isKindOfClass:[NSArray class]]) {
		return obj;
	}
	return nil;
}

- (NSDictionary *)toDictionary {
	id obj = [self toObject];
	if ([obj isKindOfClass:[NSDictionary class]]) {
		return obj;
	}
	unsigned int count = 0;
	// Get a list of all properties in the class.
	objc_property_t *properties = class_copyPropertyList([obj class], &count);
	NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithCapacity:count];
	for (int i = 0; i < count; i++) {
		NSString *key = [NSString stringWithUTF8String:property_getName(properties[i])];
		NSString *value = [obj valueForKey:key];

		// Only add to the NSDictionary if it's not nil.
		if (value)
			[dictionary setObject:value forKey:key];
	}
	free(properties);
	if (dictionary.count) {
		return dictionary;
	}
	return nil;
}

- (LuaValue *)callWithArguments:(NSArray *)arguments {

	lua_rawgeti(_context.state, LUA_REGISTRYINDEX, _index);

	if (!lua_isfunction(_context.state, -1))
		return nil;

	for (id arg in arguments) {
		lua_objc_pushpropertylist(_context.state, arg);
	}

	if (lua_pcall(_context.state, (int)arguments.count, LUA_MULTRET, 0) != 0) {
		NSLog(@"Lua error: %s", lua_tostring(_context.state, -1));
		lua_pop(_context.state, 1);
		return nil;
	}

	if (!lua_isnoneornil(_context.state, -1)) {
		return [[LuaValue alloc] initWithTopOfStackInContext:_context];
	}

	return nil;
}

- (int)index {
	return _index;
}

- (void)dealloc {
	luaL_unref(_context.state, LUA_REGISTRYINDEX, _index);
}

@end
