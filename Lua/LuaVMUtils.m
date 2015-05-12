/*
 * LuaVMUtils.m
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

#import "LuaVMUtils.h"
#include "lualib.h"
#include "lauxlib.h"
#include "lj_obj.h"

int lua_addpackagepath(lua_State *L, const char *path) {
	lua_getglobal( L, "package" );
	lua_getfield( L, -1, "path" ); // get field "path" from table at top of stack (-1)
	NSMutableString *cur_path = [NSMutableString stringWithUTF8String:lua_tostring( L, -1 )]; // grab path string from top of stack
	[cur_path appendString:@";"]; // do your path magic here
	[cur_path appendString:[NSString stringWithUTF8String:path]];
	lua_pop( L, 1 ); // get rid of the string on the stack we just pushed on line 5
	lua_pushstring( L, cur_path.UTF8String ); // push the new one
	lua_setfield( L, -2, "path" ); // set the field "path" in table at -2 with value at top of stack
	lua_pop( L, 1 ); // get rid of package table from top of stack
	return 0; // all done!
}

void cdataToPointer(id cdata, void **pointer) {
	*pointer = (__bridge void *)(cdata);
}

id lua_toid(lua_State *L, int idx) {

	id result = nil;

	if(idx<0){
		idx=lua_gettop(L)+(idx+1);
	}

	if (!lua_isnoneornil(L, idx)) {
		int type = lua_type(L, idx);

		if (type == LUA_TSTRING) {
			result = [NSString stringWithUTF8String:lua_tostring(L, idx)];

		} else if (type == LUA_TCDATA) {
			void *pointer = NULL;

			lua_pushvalue(L, idx);
			lua_setglobal(L, "__TEMP_CDATA__");

			lua_pushlightuserdata(L, &pointer);
			lua_setglobal(L, "__TEMP_USERDATA__");

			luaL_dostring(L,
						  "local ffi = require'ffi'\n"
						  "ffi.cdef[[\n"
						  "  void cdataToPointer(id cdata, void **pointer);\n"
						  "]]\n"
						  "ffi.C.cdataToPointer(__TEMP_CDATA__, __TEMP_USERDATA__)\n");

			result = (__bridge id)pointer;

		} else if (type == LUA_TUSERDATA) {
			result = (__bridge id)lua_touserdata(L, idx);

		} else if (type == LUA_TNUMBER) {
			result = [NSNumber numberWithDouble:lua_tonumber(L, idx)];

		} else if (type == LUA_TBOOLEAN) {
			result = [NSNumber numberWithBool:lua_toboolean(L, idx)];

		} else if (type == LUA_TTABLE) {
			int length = (int)lua_objlen(L, idx);

			if (length > 0) {
				NSMutableArray *array = [NSMutableArray array];

				for (int i=1; i<=length; ++i) {

					/* get element at position i */
					lua_rawgeti(L, idx, i);

					id value = lua_toid(L, -1);
					lua_pop(L, 1);

					if (value == nil)
						value = [NSNull null];

					[array addObject:value];
				}

				result = array;

			} else {
				NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];

				lua_pushnil(L);  /* first key */

				while (lua_next(L, idx) != 0) {

					/* uses 'key' (at index -2) and 'value' (at index -1) */
					NSString *key = [NSString stringWithUTF8String:lua_tostring(L, -2)];
					id value = lua_toid(L, -1);

					if (value == nil)
						value = [NSNull null];

					[dictionary setObject:value forKey:key];

					/* removes 'value'; keeps 'key' for next iteration */
					lua_pop(L, 1);
				}

				result = dictionary;
			}

		} else {
			assert(0);
		}
	}

	return result;
}
