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
		lua_newtable(L); /* new table for globals */
		lua_newtable(L); /* metatable for new globals */
		lua_pushliteral(L, "__index");
		lua_pushvalue(L, LUA_GLOBALSINDEX); /* __index tries old common globals */
		lua_settable(L, -3);
		lua_setmetatable(L, -2);
		lua_replace(L, LUA_GLOBALSINDEX);
	}
	return self;
}

- (LuaValue *)evaluateScript:(NSString *)script {
	if (script) {
		luaL_dostring(C, script.UTF8String);
		if (lua_gettop(C)) {
			return [[LuaValue alloc] initWithTopOfStackInContext:self];
		}
	}
	return nil;
}

- (LuaValue *)evaluateScriptNamed:(NSString *)filename {
	NSString *fullpath = [[NSBundle mainBundle] pathForResource:filename ofType:@"lua"];
	if (fullpath) {
		luaL_dofile(C, fullpath.UTF8String);
		if (lua_gettop(C)) {
			return [[LuaValue alloc] initWithTopOfStackInContext:self];
		}
	}
	return nil;
}

- (lua_State *)state {
	return C;
}

- (id)objectForKeyedSubscript:(id)key {
	if ([key isKindOfClass:[NSString class]]) {
		lua_getglobal(self.state, [key UTF8String]);
		id obj = lua_objc_topropertylist(self.state, -1);
		lua_pop(self.state, 1);
		return obj;
	}
	return nil;
}

- (void)setObject:(id)obj forKeyedSubscript:(id <NSCopying>)key {
	if ([(NSObject *)key isKindOfClass:[NSString class]]) {
		if (lua_objc_pushpropertylist(self.state, obj)) {
			lua_setglobal(self.state, [(NSString *)key UTF8String]);
		}
	}
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
}

- (instancetype)initWithTopOfStackInContext:(LuaContext *)context {
	if (self = [self initWithContext:context]) {
		[self storeTopOfStack];
	}
	return self;
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

- (int32_t)toInt32 {
	lua_rawgeti(_context.state, LUA_REGISTRYINDEX, _index);
	int32_t value = (int32_t)lua_tointeger(_context.state, -1);
	lua_pop(_context.state, 1);
	return value;
}

- (LuaValue *)callWithArguments:(NSArray *)arguments {
	return nil;
}

- (void)dealloc {
	luaL_unref(_context.state, LUA_REGISTRYINDEX, _index);
}

@end
