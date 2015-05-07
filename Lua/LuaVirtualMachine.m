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

#define STR(s) #s

static int report (lua_State *L, int status) {
	const char *msg;
	if (status) {
		msg = lua_tostring(L, -1);
		if (msg == NULL) msg = "(error with no message)";
		//fprintf(stderr, "%s\n", msg);
		lua_pop(L, 1);
	}
	return status;
}

static void fixglobals (lua_State *L) {
	lua_newtable(L); /* new table for globals */
	lua_newtable(L); /* metatable for new globals */
	lua_pushliteral(L, "__index");
	lua_pushvalue(L, LUA_GLOBALSINDEX); /* __index tries old common globals */
	lua_settable(L, -3);
	lua_setmetatable(L, -2);
	lua_replace(L, LUA_GLOBALSINDEX);
}

#pragma mark LuaVirtualMachine

@implementation LuaVirtualMachine {
	lua_State *L;
}

+ (void)test {
	lua_State *L = lua_open();

	luaopen_base(L);
	luaopen_table(L);
	luaopen_io(L);
	luaopen_string(L);
	luaopen_math(L);
	luaopen_debug(L);

	lua_State *C1 = lua_newthread(L);
	lua_State *C2 = lua_newthread(L);

	fixglobals(C1);
	lua_pushliteral(C1, "c1");
	lua_setglobal(C1, "name");
	lua_pushnumber(C1, 2);
	lua_setglobal(C1, "N");

	fixglobals(C2);
	lua_pushliteral(C2, "c2");
	lua_setglobal(C2, "name");
	lua_pushnumber(C2, 3);
	lua_setglobal(C2, "N");

	printf("loading %s\n", "test2.lua");
	if (report(C1, luaL_loadfile(C1, "test2.lua") )) exit(1);
	printf("loading %s\n", "string");
	if (report(C2, luaL_loadstring(C2,
								   "string = 'string test'\n"

								   "function hello(s)\n"
								   "	print('hello '..s)\n"
								   "end\n"

								   "print('env', name, getfenv())\n"

								   "not_dead_yet = true\n"

								   "while not_dead_yet do\n"
								   "	for i = 1,N do\n"
								   "		print(name, i)\n"
								   "		coroutine.yield(i)\n"
								   "	end\n"
								   "end\n"

								   "print('finished')"))) exit(2);

	printf("start looping\n");
	for (int i=0; i<10; i++) {
		if (!report(C1, lua_resume(C1, 0))) exit(3);
		if (!report(C2, lua_resume(C2, 0))) exit(4);
		printf(">>>i = %d\n", i);
	}

	lua_getglobal(C1, "hello");
	lua_pushstring(C1, "world");
	lua_call(C1, 1, 0);

	lua_getglobal(C2, "hello");
	lua_getglobal(C2, "string");
	lua_call(C2, 1, 0);

	lua_close(L);

	LuaVirtualMachine *luaVM = [[LuaVirtualMachine alloc] init];

	LuaContext *ctx1 = [[LuaContext alloc] initWithVirtualMachine:luaVM];
	LuaContext *ctx2 = [[LuaContext alloc] initWithVirtualMachine:luaVM];

	ctx1[@"number"] = @(2);
	LuaValue *value = [ctx1 evaluateScript:@"return 1 + number:intValue()"];
	printf("%d\n", value.toInt32);

	ctx1[@"string"] = @"hello world";
	[ctx1 evaluateScript:@"print('lua: '..string:UTF8String())"];

	ctx2[@"string"] = @"hello world in other context";
	[ctx2 evaluateScript:@"print('lua: '..string:UTF8String())"];
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

- (LuaValue *)evaluateScript:(NSString *)script {
	if (script) {
		luaL_dostring(C, script.UTF8String);
		if (lua_gettop(C) && !lua_isnoneornil(C, -1)) {
			return [[LuaValue alloc] initWithTopOfStackInContext:self];
		}
	}
	return nil;
}

- (LuaValue *)evaluateScriptNamed:(NSString *)filename {
	NSString *fullpath = [[NSBundle mainBundle] pathForResource:filename ofType:@"lua"];
	if (fullpath) {
		luaL_dofile(C, fullpath.UTF8String);
		if (lua_gettop(C) && !lua_isnoneornil(C, -1)) {
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
		if (lua_objc_pushpropertylist(C, obj)) {
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

	int err = lua_pcall(_context.state, (int)arguments.count, 1, 0);
	if (err != 0) {
		switch(err) {
			case LUA_ERRRUN:
				NSLog(@"Lua: runtime error");
				break;

			case LUA_ERRMEM:
				NSLog(@"Lua: memory allocation error");
				break;

			case LUA_ERRERR:
				NSLog(@"Lua: error handler error");
				break;

			default:
				NSLog(@"Lua: unknown error");
				return nil;
		}

		NSLog(@"Lua: %s", lua_tostring(_context.state, -1));
		return nil;
	}

	if (!lua_isnoneornil(_context.state, -1)) {
		return [[LuaValue alloc] initWithTopOfStackInContext:_context];
	}

	return nil;
}

- (void)dealloc {
	luaL_unref(_context.state, LUA_REGISTRYINDEX, _index);
}

@end
