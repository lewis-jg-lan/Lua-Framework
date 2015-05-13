//
// LuaObjCBridge.m
//
// By Tom McClean, 2005-2007
// tom@pixelballistics.com
//
// This file is public domain. It is provided without any warranty whatsoever,
// and may be modified or used without attribution.
//
	
//
// Header File Includes
//

#pragma mark Header File Includes

#import "LuaObjCBridge.h"
#include <objc/message.h>
#include <dlfcn.h>

//
// Lua Versioning Configuration
//

#pragma mark Lua Versioning Configuration

//
// These definitions instruct the LuaObjCBridge to account for differences
// between the various versions of the Lua library itself.
//
// The bridge is always configured to compile against the version included with
// it in the release .dmg archive, but can be configured to compile against
// earlier versions by changing these values.
//
// The earliest version of Lua against which the bridge has been tested is v5.0
//
 
#define LUA_OBJC_LUA_VERSION_5_0_0 0x050000
#define LUA_OBJC_LUA_VERSION_5_0_1 0x050001
#define LUA_OBJC_LUA_VERSION_5_1_0 0x050100

#ifndef LUA_OBJC_LUA_DEPLOYMENT_TARGET
	#define LUA_OBJC_LUA_DEPLOYMENT_TARGET LUA_OBJC_LUA_VERSION_5_1_0
#endif
	
//
// Optional Configuration
//

#pragma mark Optional Configuration

//
// These #defines enable features of the bridge which may not be compatible
// with scripts or code originally written for earlier versions.
//
// It should be fairly obvious from their names what these do. The features they
// enable can be disabled simply by commenting them out here. All efforts have
// been made to ensure that doing so will not cause adverse (backwards-
// incompatible) side effects.
//
	
#if LUA_OBJC_LUA_DEPLOYMENT_TARGET>=LUA_OBJC_LUA_VERSION_5_1_0
	//#define LUA_OBJC_EACH_LUA_TYPE_HAS_METATABLE
	#define LUA_OBJC_RETAIN_AND_RELEASE_INSTANCES
#endif
	
//
// Symbolic Constants
//

#pragma mark Symbolic Constants

//
// These symbols define strings that are used to identify or access data in the
// Lua execution environment
//

#define LUA_OBJC_GLOBAL_OBJECT_STORAGE_NAME "__lua_objc_ids"
#define LUA_OBJC_LIBRARY_NAME "objc"
#define LUA_OBJC_OBJECT_STORAGE_NAME "__lua_objc_id"
	
//
// These definitions just provide names for the various types that can be found
// in Objective-C runtime encodings.
//

#define LUA_OBJC_TYPE_BITFIELD 'b'
#define LUA_OBJC_TYPE_C99_BOOL 'B'
#define LUA_OBJC_TYPE_CHAR 'c'
#define LUA_OBJC_TYPE_UNSIGNED_CHAR 'C'
#define LUA_OBJC_TYPE_DOUBLE 'd'
#define LUA_OBJC_TYPE_FLOAT 'f'
#define LUA_OBJC_TYPE_INT 'i'
#define LUA_OBJC_TYPE_UNSIGNED_INT 'I'
#define LUA_OBJC_TYPE_LONG 'l'
#define LUA_OBJC_TYPE_UNSIGNED_LONG 'L'
#define LUA_OBJC_TYPE_LONG_LONG 'q'
#define LUA_OBJC_TYPE_UNSIGNED_LONG_LONG 'Q'
#define LUA_OBJC_TYPE_SHORT 's'
#define LUA_OBJC_TYPE_UNSIGNED_SHORT 'S'
#define LUA_OBJC_TYPE_VOID 'v'
#define LUA_OBJC_TYPE_UNKNOWN '?'

#define LUA_OBJC_TYPE_ID '@'
#define LUA_OBJC_TYPE_CLASS '#'
#define LUA_OBJC_TYPE_POINTER '^'
#define LUA_OBJC_TYPE_STRING '*'

#define LUA_OBJC_TYPE_UNION '('
#define LUA_OBJC_TYPE_UNION_END ')'
#define LUA_OBJC_TYPE_ARRAY '['
#define LUA_OBJC_TYPE_ARRAY_END ']'
#define LUA_OBJC_TYPE_STRUCT '{'
#define LUA_OBJC_TYPE_STRUCT_END '}'
#define LUA_OBJC_TYPE_SELECTOR ':'

#define LUA_OBJC_TYPE_IN 'n'
#define LUA_OBJC_TYPE_INOUT 'N'
#define LUA_OBJC_TYPE_OUT 'o'
#define LUA_OBJC_TYPE_BYCOPY 'O'
#define LUA_OBJC_TYPE_CONST 'r'
#define LUA_OBJC_TYPE_BYREF 'R'
#define LUA_OBJC_TYPE_ONEWAY 'V'
	
//
// Initialisation
//

#pragma mark Initialisation
	
//
// The contents of this struct are exposed to the Lua interpreter as a global 
// table called "objc" (as defined in LUA_OBJC_LIBRARY_NAME)
//

const luaL_reg lua_objc_functions[]={
	//{"class",lua_objc_lookup_class},
	{NULL,NULL},
	};
	
//
// Specifies the libraries to be opened by a call to lua_objc_init()
//

static const luaL_reg lua_objc_libraries[]={
#if LUA_OBJC_OBJC_LUA_OBJC_DEPLOYMENT_TARGET>=LUA_OBJC_OBJC_LUA_OBJC_VERSION_5_1_0
	{"base",luaopen_base},
#else
	{"",luaopen_base},
#endif
	{LUA_TABLIBNAME,luaopen_table},
	{LUA_IOLIBNAME,luaopen_io},
#if LUA_OBJC_LUA_DEPLOYMENT_TARGET>=LUA_OBJC_LUA_VERSION_5_1_0
	{LUA_OSLIBNAME,luaopen_os},
#endif
	{LUA_STRLIBNAME,luaopen_string},
	{LUA_MATHLIBNAME,luaopen_math},
	{LUA_DBLIBNAME,luaopen_debug},
#if LUA_OBJC_LUA_DEPLOYMENT_TARGET>=LUA_OBJC_LUA_VERSION_5_1_0
	{LUA_LOADLIBNAME,luaopen_package},
#else
	{LUA_LOADLIBNAME,luaopen_loadlib},
#endif
	{LUA_OBJC_LIBRARY_NAME,lua_objc_open},
	{NULL, NULL}
	};
	
//
// Creates a Lua interpreter, and initialises it by opening the libraries
// specified in lua_objc_libraries.
//

lua_State* lua_objc_init(void){
	lua_State* state=lua_open();
	if(state){
	
		//
		// Open built-in libraries
		//
	
		const luaL_reg* libraries=lua_objc_libraries;
		for(;libraries->func;libraries++){
#if LUA_OBJC_LUA_DEPLOYMENT_TARGET>=LUA_OBJC_LUA_VERSION_5_1_0
			lua_pushcfunction(state,libraries->func);
			lua_pushstring(state,libraries->name);
			lua_call(state,1,0);
#else
			libraries->func(state);
			lua_settop(state,0);
#endif
			}
#ifdef LUA_OBJC_EACH_LUA_TYPE_HAS_METATABLE

		//
		// Configure metatables for built-in value types which correspond to Cocoa property-list types
		//
		
		lua_pushstring(state,"");
		lua_objc_configuremetatable(state,-1,YES);
		lua_pop(state,1);
		
		lua_pushnumber(state,0);
		lua_objc_configuremetatable(state,-1,YES);
		lua_pop(state,1);
		
		lua_pushboolean(state,0);
		lua_objc_configuremetatable(state,-1,YES);
		lua_pop(state,1);
#endif
		}
	return state;
	}

//
// Load a list of Frameworks.
//

static int lua_objc_import_framework(lua_State *L){
	NSString *frameworksPath = @"/System/Library/Frameworks";

	int i, n;
	n = lua_gettop(L);

	for(i=n;i>0;--i){
		const char *framework = lua_tostring(L,-1);
		NSBundle *bundle = [NSBundle bundleWithPath:[frameworksPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%s.framework", framework]]];
		void* handle = dlopen(bundle.executablePath.UTF8String,RTLD_NOW);
		dlclose(handle);
		lua_pop(L,1);
		}

	return 0;
	}

//
// A Lua function. Takes a string from the Lua stack, and uses lua_objc_pushid()
// to return the Objective-C class named by the string to the Lua caller.
//
	
int lua_objc_lookup_class(lua_State* state){
	const char *key = lua_tostring(state,-1);
	if(strcmp(key,"import") == 0)
		lua_pushcfunction(state,lua_objc_import_framework);
	else{
		id theClass;
		theClass=NSClassFromString([NSString stringWithUTF8String:key]);
		if(theClass!=nil)
			lua_objc_pushid(state,theClass);
		else
			lua_pushnil(state);
		}
	return 1;
	}
	
//
// Initialises the Lua library. Useful if you want to initialise your own Lua 
// interpreter.
//
	
int lua_objc_open(lua_State* state){
#if LUA_OBJC_LUA_DEPLOYMENT_TARGET>=LUA_OBJC_LUA_VERSION_5_1_0
	luaL_register(state,lua_tostring(state,-1),lua_objc_functions);

	//
	// Set hook to intercept method calls ("index events") and redirect them to the lookup class function
	//

	lua_getglobal(state,LUA_OBJC_LIBRARY_NAME);
	lua_createtable(state,0,0);
	lua_pushcfunction(state,lua_objc_lookup_class);
	lua_setfield(state,-2,"__index");
	lua_setmetatable(state,-2);

#else
	luaL_openlib(state,LUA_OBJC_LIBRARY_NAME,lua_objc_functions,0);
#endif
	return 0;
	}
	
//
// Instance Passing
//

#pragma mark Instance Passing
	
//
// Sets various callbacks in the metatable for the value at stack_index.
//

void lua_objc_configuremetatable(lua_State* state,int stack_index,int hook_gc_events){
	if(stack_index<0){
		stack_index=lua_gettop(state)+(stack_index+1);
		}
		
	if(lua_getmetatable(state,stack_index)){
		int metatable=lua_gettop(state);
		
		//
		// Set hook to intercept method calls ("index events")
		//

		lua_pushstring(state,"__index");
		lua_pushcfunction(state,&lua_objc_methodlookup);
		lua_settable(state,metatable);
		
		//
		// Set hook to intercept garbage collection events
		//
		
#ifdef LUA_OBJC_RETAIN_AND_RELEASE_INSTANCES
		if(hook_gc_events){
			lua_pushstring(state,"__gc");
			lua_pushcfunction(state,&lua_objc_release);
			lua_settable(state,metatable);
			}
#endif		
		lua_pop(state,1);
		}
	}
	
//
// Returns the Objective-C id associated with the specified value on the Lua
// stack. Returns nil if the Lua value does not have an associated ObjC value.
// As of Lua v5.1.0, all Lua values can be associated with ObjC values; prior
// to v5.1.0 this function will only return a non-nil result if it is asked to 
// return the id-value for a Lua value created using lua_objc_pushid().
//

id lua_objc_getid(lua_State* state,int stack_index){
	if(stack_index<0){
		stack_index=lua_gettop(state)+(stack_index+1);
		}
	
	//
	// Get the metatable for this value
	//
	
	id result=nil;
	if(lua_getmetatable(state,stack_index)){
		int metatable=lua_gettop(state);
#ifdef LUA_OBJC_EACH_LUA_TYPE_HAS_METATABLE
		if((lua_istable(state,stack_index))||(lua_isuserdata(state,stack_index))){
#else
		if(lua_istable(state,stack_index)){
#endif

			//
			// Get the Objective-C object stored in the metatable
			//

			lua_pushstring(state,LUA_OBJC_OBJECT_STORAGE_NAME);
			lua_gettable(state,metatable);
			if(lua_islightuserdata(state,-1)){
				result=lua_touserdata(state,-1);
				}
			lua_pop(state,1); // result;
			}
#ifdef LUA_OBJC_EACH_LUA_TYPE_HAS_METATABLE
		else if(!(lua_isnil(state,stack_index))){

			//
			// Get the Objective-C object associated with this specific value.
			// 
			// In Lua v5.1.0, each *instance* of a table and light userdata has its
			// own metatable. But each *class* of every other type shares a
			// metatable with all the others (strings, numbers, etc).
			//
			// We, however, need to be able to associate specific instances of Lua
			// strings and numbers with specific Objective-C instances of NSStrings
			// and NSNumbers. 
			//
			// To do this, we use a Lua table. The keys to the dictionary are
			// instances of Lua types, and the values are the ObjC instances
			// associated with them. These strings are stored in the global table 
			// LUA_OBJC_LIBRARY_NAME created by lua_objc_open(), under the name 
			// LUA_OBJC_GLOBAL_OBJECT_STORAGE_NAME to avoid any name collisions.
			// 
			// Unfortunately, the Lua public API does not provide any way of
			// converting a stack index into some sort of a unique reference
			// identifying the actual value stored on the stack. To get around this,
			// we re-implement one of Lua's private functions which does just that:
			// index2adr() takes a stack index and returns a pointer to the value
			// structure used internally by the Lua engine. We use this in full
			// knowledge that it's a dirty hack that may not work in future.
			//
			
			lua_pushstring(state,LUA_OBJC_LIBRARY_NAME);
			lua_gettable(state,LUA_GLOBALSINDEX);
			lua_pushstring(state,LUA_OBJC_GLOBAL_OBJECT_STORAGE_NAME);
			lua_gettable(state,-2);
							
			//
			// Retrieve the id from our global private table
			//
			
			if(!lua_isnil(state,-1)){
				lua_pushlightuserdata(state,lua_objc_topointer(state,stack_index));
				lua_gettable(state,-2);
				if(lua_isuserdata(state,-1)){
					result=lua_touserdata(state,-1);
					}
				lua_pop(state,1); // result
				}
			lua_pop(state,1); // object-with-shared-metatable cache
			lua_pop(state,1); // library global table
			}
#endif
		lua_pop(state,1); // parameter metatable
		}
	return result;
	}

//
// Returns YES if and only if the object on the stack has been associated with
// an Objective-C id via a call to lua_objc_pushid(),
// lua_objc_pushpropertylist() or lua_objc_setid(). Otherwise returns NO.
//

int lua_objc_isid(lua_State* state,int stack_index){
	return (lua_objc_getid(state,stack_index)!=nil);
	}
	
//
// Passes an Objective-C object (instance or class) to the Lua interpreter
// state.
//
// ObjC objects are generally represented in Lua as tables. These tables always
// have special metatables with the __index metamethod redirected to 
// lua_objc_methodlookup(), the __gc methamethod redirected to 
// lua_objc_release() and a special metavariable "index" which stores the ObjC
// id as a Lua light userdata.
//
// As of Lua v5.1.0, it is also possible to mess about with the metatables
// of all Lua values. This feature is discussed further at
// lua_objc_pushpropertylist, which uses it to set ids for all the other
// data types. This effectively means you can pass any ObjC property list
// type, and it will appear to the Lua script as a native data type
// which also responds to Objective-C methods.
//
// Previous versions of the LuaObjCBridge were completely agnostic with respect
// to synchronising Lua garbage collection and ObjC retain/release mechanisms.
// As of LuaObjCBridge v1.4, this is no longer the case. Objects which are
// passed to Lua will be retained for as long as they continue to exist within
// the Lua execution context.
//

void lua_objc_pushid(lua_State* state,id object){
	lua_newtable(state);
	lua_objc_setid(state,lua_gettop(state),object);
	}
	
//
// Releases the Objective-C object associated with a Lua value. This is called
// automatically by Lua when the associated value is garbage-collected.
// Objective-C objects are only retained if they are instances (i.e. class
// objects are not retained), and only if the bridge has been compiled with
// LUA_OBJC_RETAIN_AND_RELEASE_INSTANCES #defined. In this case, instances
// will be retained every time they are associated with a Lua value using
// lua_objc_setid(), lua_objc_pushid() or lua_objc_pushpropertylist().
//

int lua_objc_release(lua_State* state){
#ifdef LUA_OBJC_RETAIN_AND_RELEASE_INSTANCES
	[lua_objc_getid(state,-1) release];
#endif
	return 0;
	}
	
//
// Associates an Objective-C id with the specified value on the Lua stack.
// As of Lua v5.1.0, all Lua values can be associated with ObjC values; prior
// to v5.1.0 this function will only associate ObjC ids with tables.
//
	
void lua_objc_setid(lua_State* state,int stack_index,id object){
	if(stack_index<0){
		stack_index=lua_gettop(state)+(stack_index+1);
		}
	
	//
	// Get the metatable for this value; create if required
	//
	
	int metatable=0;
	if(!lua_getmetatable(state,stack_index)){
		lua_newtable(state);
		lua_setmetatable(state,stack_index);
#ifdef LUA_OBJC_RETAIN_AND_RELEASE_INSTANCES
		lua_objc_configuremetatable(state,stack_index,[object respondsToSelector:@selector(retain)]);
#else
		lua_objc_configuremetatable(state,stack_index,0);
#endif
		lua_getmetatable(state,stack_index);
		}
	metatable=lua_gettop(state);	
		
#ifdef LUA_OBJC_RETAIN_AND_RELEASE_INSTANCES
	if([object respondsToSelector:@selector(retain)]){
		[object retain];
		}
#endif

	//
	// Store a reference to the id in the metatable
	//		

#ifdef LUA_OBJC_EACH_LUA_TYPE_HAS_METATABLE
	if((lua_istable(state,stack_index))||(lua_isuserdata(state,stack_index))){
#else
	if(lua_istable(state,stack_index)){
#endif
		lua_pushstring(state,LUA_OBJC_OBJECT_STORAGE_NAME);
		lua_pushlightuserdata(state,object);
		lua_settable(state,metatable);
		}
#ifdef LUA_OBJC_EACH_LUA_TYPE_HAS_METATABLE
	else if(!lua_isnil(state,stack_index)){
	
		//
		// This type has a shared metatable - we have to store the id globally
		//
		
		lua_pushstring(state,LUA_OBJC_LIBRARY_NAME);
		lua_gettable(state,LUA_GLOBALSINDEX);
		int globals=lua_gettop(state);
		lua_pushstring(state,LUA_OBJC_GLOBAL_OBJECT_STORAGE_NAME);
		lua_gettable(state,globals);
		
		//
		// Create a global private table for storage, if required.
		//
		// To avoid interfering with the mechanism linking Lua's garbage
		// collection with ObjC's retain/release system, we use a Lua table to
		// do this.
		//
		
		if(lua_isnil(state,-1)){
			lua_pop(state,1);
			
			lua_pushstring(state,LUA_OBJC_GLOBAL_OBJECT_STORAGE_NAME);
			lua_newtable(state);
			lua_settable(state,globals);
			
			lua_pushstring(state,LUA_OBJC_GLOBAL_OBJECT_STORAGE_NAME);
			lua_gettable(state,globals);
			}
		int ids=lua_gettop(state);
			
		//
		// Store the id in our global private table
		//
			
		lua_pushlightuserdata(state,lua_objc_topointer(state,stack_index));
		lua_pushlightuserdata(state,object);
		lua_settable(state,ids);
			
		lua_pop(state,1);
		lua_pop(state,1);
		}
#endif
	lua_pop(state,1);
	}
	
//
// Returns the Objective-C id represented by the specified object on Lua stack.
//

id lua_objc_toid(lua_State* state,int stack_index){
	return lua_objc_getid(state,stack_index);
	}
	
//
// Converts a Lua stack index into a pointer to the underlying Lua value
// structure. This is used by lua_objc_setid() and lua_objc_getid() to give a
// unique identifier for each value, for reasons discussed in comments under
// lua_objc_getid(). 
//
// This is a reimplementation of index2adr(), an internal Lua function. It works
// for Lua v5.1.0, but may need to be reimplemented in future if Lua's internals
// change.
//
// Note, for example, that since this function is used to uniquely identify 
// values throughout a particular Lua session, the Bridge depends on the Lua
// garbage collector not moving blocks of memory around.
//

#ifdef LUA_OBJC_EACH_LUA_TYPE_HAS_METATABLE
	#include "lobject.h"
	#include "lstate.h"
#endif

#if LUA_OBJC_LUA_DEPLOYMENT_TARGET>LUA_OBJC_LUA_VERSION_5_1_0
	#warning lua_objc_topointer() has not been tested for your target Lua version.
#endif


void* lua_objc_topointer(lua_State* state,int stack_index){
	void* result = NULL;
#ifdef LUA_OBJC_EACH_LUA_TYPE_HAS_METATABLE
	StkId stack_record = NULL;
		
	//
	// Get the stack record at the specified stack index
	//
	
	if(stack_index>0){
		stack_record=state->base+(stack_index-1);
		if((stack_record<=(StkId)(state->top-state->base))||(stack_record>=state->top)){
			stack_record=NULL;
			}
		}
	
	//
	// Negative (ie: top-relative) stack indices
	//
	
	else if(stack_index>LUA_REGISTRYINDEX){
		if((stack_index!=0)&&(-stack_index<=state->top-state->base)){
			stack_record=state->top+stack_index;
			}
		}
	
	//
	// Pseudoindices to special data areas, namely:
	//
	
	else{ 
		switch(stack_index){
			
			//
			// the data registry;
			//
			
			case LUA_REGISTRYINDEX:
				stack_record=registry(state);
			
			//
			// the execution environment;
			//
			
			case LUA_ENVIRONINDEX:{
				Closure *func=curr_func(state);
				sethvalue(state,&state->env,func->c.env);
				stack_record=&state->env;
				}
			
			//
			// global data; and
			//
			
			case LUA_GLOBALSINDEX:
				stack_record=gt(state);
			
			//
			// closures for current function.
			//
				
			default:{
				Closure* func=curr_func(state);
				stack_index=LUA_GLOBALSINDEX-stack_index;
				stack_record=(stack_index<=func->c.nupvalues)?&func->c.upvalue[stack_index-1]:NULL;
				}
			}
		}
		
	//
	// Now get the pointer to the Lua storage record
	//
	
	if(stack_record){
		switch(stack_record->tt){
			case LUA_TNUMBER:{
				result=(void*)stack_record->value.gc;
				break;
				}
			case LUA_TBOOLEAN:{
				result=(void*)stack_record->value.gc;
				break;
				}
			case LUA_TSTRING:{
				result=&(stack_record->value.gc->ts);
				break;
				}
			case LUA_TTABLE:{
				result=&(stack_record->value.gc->h);
				break;
				}
			case LUA_TFUNCTION:{
				result=&(stack_record->value.gc->cl);
				break;
				}
			case LUA_TTHREAD:{
				result=&(stack_record->value.gc->th);
				break;
				}
			case LUA_TUSERDATA:
			case LUA_TLIGHTUSERDATA:{
				result=(void*)stack_record->value.p;
				break;
				}
			case LUA_TNIL:
			default:{
				result=NULL;
				break;
				}
			}
		}
#else
	result=lua_topointer(state,stack_index);
#endif
	return result;
	}

//
// Blocks
//

#pragma mark Blocks

static int lua_objc_blockcall(lua_State *state){
	lua_pushvalue(state,-1);
	lua_objc_methodcall(state);
	return 1;
	}

static NSMethodSignature *lua_objc_blocksignature(id blockObj){
	struct Block{
		void *isa;
		int flags;
		int reserved;
		void *invoke;

		struct Descriptor{
			unsigned long reserved;
			unsigned long size;
			void *rest[1];
			}*descriptor;
		};

	struct Block *block = (__bridge void *)blockObj;

	int copyDisposeFlag=1<<25;
	int signatureFlag=1<<30;

	assert(block->flags&signatureFlag);

	int index = 0;
	if(block->flags&copyDisposeFlag)
		index+=2;

	const char *types=block->descriptor->rest[index];
	NSMethodSignature *signature=[NSMethodSignature signatureWithObjCTypes:types];

	while([signature numberOfArguments]<2){
		types=[[NSString stringWithFormat:@"%s%s",types,@encode(void*)] UTF8String];
		signature=[NSMethodSignature signatureWithObjCTypes:types];
		}
	
	return signature;
	}

//
// Property List Translation
//

#pragma mark Property List Translation
	
//
// Pushes a Cocoa property list onto the Lua stack.
// This function only operates on a subset of the canonical property list
// classes: NSArray, NSDictionary, NSString, NSNumber and NSNull.
//

BOOL lua_objc_pushpropertylist(lua_State* state,id propertylist){
	BOOL result=YES;
	int top=lua_gettop(state);

	//
	// NSNull
	//
		 
	if((propertylist==nil)||(propertylist==[NSNull null])){
		lua_pushnil(state);
		lua_objc_setid(state,-1,propertylist);
		}

	//
	// NSNumber (includes boolean values)
	//
	 
	else if([propertylist isKindOfClass:[NSNumber class]]){
		if(strcmp([propertylist objCType],@encode(_Bool))==0)
			lua_pushboolean(state,[propertylist boolValue]);
		else
			lua_pushnumber(state,[propertylist doubleValue]);
		lua_objc_setid(state,-1,propertylist);
		}

	//
	// NSString
	//
	 
	else if([propertylist isKindOfClass:[NSString class]]){
		lua_pushstring(state,[propertylist UTF8String]);
		lua_objc_setid(state,-1,propertylist);
		}

#ifdef LUA_OBJC_PASS_NSDATA_AS_STRING

	//
	// NSData (passed as a string
	//
	 
	else if([propertylist isKindOfClass:[NSData class]]){
		lua_pushlstring(state,[propertylist bytes],[propertylist length]);
		lua_objc_setid(state,-1,propertylist);
		}
	
#endif

	//
	// NSDictionary
	//
	 
	else if([propertylist isKindOfClass:[NSDictionary class]]){
		lua_newtable(state);
		lua_objc_setid(state,-1,propertylist);
		int table=lua_gettop(state);
		NSEnumerator* enumerator=[propertylist keyEnumerator];
		id key;
		while((key=[enumerator nextObject])){
			lua_objc_pushpropertylist(state,key);
			if(!lua_objc_pushpropertylist(state,[propertylist valueForKey:key])){
				result=NO;
				break;
				}
			lua_rawset(state,table);
			}
		}

	//
	// NSArray
	//
	 
	else if([propertylist isKindOfClass:[NSArray class]]){
		lua_newtable(state);
		lua_objc_setid(state,-1,propertylist);
		int table=lua_gettop(state);
		NSEnumerator* enumerator=[propertylist objectEnumerator];
		id value;
		lua_Number stack_index;
		for(stack_index=0;(value=[enumerator nextObject]);stack_index++){
			lua_pushnumber(state,stack_index+1);
			if(!lua_objc_pushpropertylist(state,value)){
				result=NO;
				break;
				}
			lua_rawset(state,table);
			}
		lua_pushliteral(state,"n");
		lua_pushnumber(state,stack_index);
		lua_rawset(state,table);
		}

	//
	// Class or instance object
	//

	else{
		lua_objc_pushid(state,propertylist);

		//
		// Block
		//

		if ([propertylist isKindOfClass:[^{} class]]){

			lua_getmetatable(state,-1);
			lua_pushcfunction(state,lua_objc_blockcall);
			lua_setfield(state,-2,"__call");
			lua_pop(state,1);
			}

		}
		
	if(!result)
		lua_settop(state,top);
	return result;
	}
	
//
// Converts a given Lua value into its equivalent Cocoa (mutable) property list
// type. This function only returns a subset of the canonical property list
// classes: NSMutableArray, NSMutableDictionary, NSString, NSNumber and NSNull.
// A Lua table with only sequential numeric keys (and, optionally, a numeric
// value whose key is "n") is returned as an NSMutableArray. For all other 
// tables, an NSMutableDictionary is returned.
//
// Note that, as of Lua v5.1.0 and up, if you call this function on a Lua value
// which was created using lua_objc_pushpropertylist() and whose value has not 
// changed since, it will return the original ObjC id, not a new id of identical
// value.
//

id lua_objc_topropertylist(lua_State* state,int stack_index){
	if(stack_index<0){
		stack_index=lua_gettop(state)+(stack_index+1);
		}
		
	//
	// Convert the value on the top of the stack
	//
		
	id original=lua_objc_toid(state,stack_index);
	id result=nil;
	switch(lua_type(state,stack_index)){
	
		//
		// Numbers
		//
		
		case LUA_TNUMBER:{
			result=[NSNumber numberWithDouble:lua_tonumber(state,stack_index)];
			break;
			}
	
		//
		// Boolean values
		//
		 
		case LUA_TBOOLEAN:{
			result=[NSNumber numberWithBool:lua_toboolean(state,stack_index)];
			break;
			}
	
		//
		// Strings
		//
		 
		case LUA_TSTRING:{
			size_t string_length;
			const char* string=lua_tolstring(state,stack_index,&string_length);
#ifdef LUA_OBJC_PASS_NSDATA_AS_STRING
			if([original isKindOfClass:[NSData class]]) {
				result=[NSData dataWithBytes:string length:string_length];
				}
			else{
				result=[NSString stringWithCString:string length:string_length];
				}
#else		
			result=[[NSString alloc] initWithBytes:string length:string_length encoding:NSUTF8StringEncoding];
#endif
			break;
			}
	
		//
		// Tables
		//
		 
		case LUA_TTABLE:{
			if(([original isKindOfClass:[NSDictionary class]])||([original isKindOfClass:[NSArray class]])){
				NSMutableArray* keys=[NSMutableArray array];
				NSMutableArray* values=[NSMutableArray array];
				double key;
				BOOL array=YES;
				lua_pushnil(state);
				for(key=1;lua_next(state,stack_index);key++){
				
					//
					// If the Lua Table has so far conformed to the conditions for an array...
					//
				
					if(array){
				
						//
						// ..but this key either not a number, or not the number we expect..
						//
						
						if((lua_type(state,-2)!=LUA_TNUMBER)||(key!=lua_tonumber(state,-2))){
						
							//
							// ..nor is it the "n" key accompanied by a number indicating the size of the array...
							//
					
							if((lua_type(state,-2)!=LUA_TSTRING)||(strcmp(lua_tostring(state,-2),"n")!=0)||(lua_type(state,-1)!=LUA_TNUMBER)){
							
								//
								// ..then this table is not an array, it's a dictionary.
								//
							
								array=NO;
								}
							else{
							
								//
								// If it *is* an array, however, we don't want to insert the Lua-internal "n" element into the ObjC array, since it just gives the array length
								//
							
								key=0.0;
								}
							}
						}
						
					//	
					// Update the ObjC values we've been storing
					//
					
					if(key){
						[values addObject:lua_objc_topropertylist(state,-1)];
						[keys addObject:lua_objc_topropertylist(state,-2)];
						}
					lua_pop(state,1);
					}
				if(array){
					result=values;
					}
				else{
					result=[NSMutableDictionary dictionaryWithObjects:values forKeys:keys];
					}
				}
			else if (!original) {

				//
				// Convert table to dictionary recursivelly
				//

				NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
				// Push another reference to the table on top of the stack (so we know
				// where it is, and this function can work for negative, positive and
				// pseudo indices
				lua_pushvalue(state,stack_index);
				// stack now contains: -1 => table
				lua_pushnil(state);
				// stack now contains: -1 => nil; -2 => table
				while (lua_next(state,-2)){
					// stack now contains: -1 => value; -2 => key; -3 => table
					// copy the key so that lua_tostring does not modify the original
					lua_pushvalue(state,-2);
					// stack now contains: -1 => key; -2 => value; -3 => key; -4 => table
					const char *key = lua_tostring(state,-1);
					id value = lua_objc_topropertylist(state,-2);
					[dictionary setObject:value forKey:[NSString stringWithUTF8String:key]];
					// pop value + copy of key, leaving original key
					lua_pop(state,2);
					// stack now contains: -1 => key; -2 => table
					}
				// stack now contains: -1 => table (when lua_next returns 0 it pops the key
				// but does not push anything.)
				// Pop table
				lua_pop(state,1);
				// Stack is now the same as it was on entry to this function
				result=dictionary;
				}
			else {
				result=original;
				}
			break;
			}

		//
		// All other Lua types are treated as Null values
		//
		 
		case LUA_TFUNCTION:
		case LUA_TUSERDATA:
		case LUA_TNIL:
		case LUA_TTHREAD:
		case LUA_TLIGHTUSERDATA:
		default:{
			result=nil;
			break;
			}
		}
		
	//
	// Return the original object if its value hasn't been changed by the Lua script
	//
		
	if(result != original && [result isEqual:original]){
		result=original;
		}
	return result;
	}
	
//
// Lua Instance Table Value Manipulation
//

#pragma mark Lua Instance Table Value Manipulation

//
// Returns an NSDictionary representation of the standard Lua table part of a
// Lua-representation id. This function can be used to extract any information
// stored in the table by a script in a form which can be stored and loaded by
// Cocoa.
//
// Note that the method-calling code in the LuaObjCBridge looks up native values
// stored in a table before invoking any method-calling code. Therefore, if a
// script inserts a value into a table using a key that matches a selector
// recognised by the underlying Objective-C class, the script will not be able
// to call that method (this only affects the script, not the Objective-C
// runtime, and can be reversed by assigning a nil value to the offending key in
// the table).
//
		
NSDictionary* lua_objc_id_getvalues(lua_State* state,int stack_index){
	if(lua_objc_isid(state,stack_index)){
		return lua_objc_topropertylist(state,stack_index);
		}
	return nil;
	}

//
// Populates a Lua table on the Lua stack with the contents of the NSDictionary.
// This function can be used to restore any information stored in the table by
// a script. 
//
// Note that the method-calling code in the LuaObjCBridge looks up native values
// stored in a table before invoking any method-calling code. Therefore, if a
// script inserts a value into a table using a key that matches a selector
// recognised by the underlying Objective-C class, the script will not be able
// to call that method (this only affects the script, not the Objective-C
// runtime, and can be reversed by assigning a nil value to the offending key in
// the table).
//

void lua_objc_id_setvalues(lua_State* state,int stack_index,NSDictionary* dictionary){
	if(stack_index<0){
		stack_index=lua_gettop(state)+(stack_index+1);
		}
		
	if(lua_objc_isid(state,stack_index)){
		NSEnumerator* enumerator=[dictionary keyEnumerator];
		id key;
		while((key=[enumerator nextObject])){
			lua_objc_pushpropertylist(state,[dictionary objectForKey:key]);
			lua_objc_pushpropertylist(state,key);
			lua_settable(state,stack_index);
			}
		}
	}
	
//
// Method Calls
//

#pragma mark Method Calls

//
// Calls the specified method of the specified Objective-C object. This function
// is passed to the Lua interpreter on its stack as a "closure". Its only
// closure value is the name of the method to be called.
//
// Note that Objective-C selector names often contain the colon (":") character,
// which cannot appear in the method name string passed from Lua. This function
// assumes the Lua script uses underscores in place of these colons. So...
//	[[FooBar alloc] initWithName:name number:0]
// ..would be written as...
// 	FooBar:alloc():initWithName_number_(name,0)
// ..or, omitting the final underscore (a convenience)...
// 	FooBar:alloc():initWithName_number(name,0)
//
// This approach means that you cannot call an Objective-C method with an
// underscore in its name from a Lua script. This is not expected to be a
// problem: does such a thing even exist?
//
// As a convenience, Lua native data types are converted to Cocoa property list
// classes if the Objective-C method expects an id. Note that this may cause an
// exception to be raised if the Objective-C method does not get what it
// expects. But if you don't know what values methods expect, you're in trouble
// anyway...
//
// Note that the default version of this function links quite tightly in with
// the NeXT-runtime itself. This is a historical artefact: the bridge grew out
// of a hackish-fun desire to see how the runtime works. If you want to compile
// a more portable version, using Foundation objects instead of direct calls to
// the runtime, just #define LUA_OBJC_USE_FOUNDATION_INSTEAD_OF_RUNTIME. This is
// #defined by default when linking against any non-Apple/NeXT runtime (ie: the
// GNU runtime)
//

#define lua_objc_methodcall_error(message) {\
	luaErrorMessage=message;\
	goto finish;\
	}
	
#define lua_objc_methodcall_setArgumentValue(type,value) (*((type*)argumentValue))=((type)value)

int lua_objc_methodcall(lua_State* state){
	int argumentCount=0;
	int argumentIndex=0;
	//marg_list argumentList=NULL;
	//int argumentOffset=0;
	unsigned argumentSize=0;
	char* argumentType=NULL;
	void* argumentValue=NULL;
	NSInvocation* invocation=nil;
	int luaArgument=0;
#ifdef LUA_OBJC_METHODCALL_PASS_FLOATS_IN_MARG_HEADER
	int luaFloatArguments=0;
#endif
	char* luaErrorMessage=NULL;
	int resultCount=0;
	//Method method=NULL;
	id receiver=nil;
	unsigned resultSize=0;
	void* resultValue=NULL;
	SEL selector=NULL;
	char* selectorName=NULL;
	int selectorNameLength=0;
	NSMethodSignature* signature=nil;

	//
	// Get the Objective-C receiver
	//

	receiver=lua_objc_toid(state,1);
	if(receiver==nil){
		lua_objc_methodcall_error("Receiver for method call is not an object.");
		}

	//
	// Get the invocation signature
	//

	selectorNameLength=(int)lua_strlen(state,lua_upvalueindex(1));
	selectorName=malloc(selectorNameLength+2);
	if(selectorName==NULL){
		lua_objc_methodcall_error("Insufficient memory (could not allocate selector buffer).");
		}
	int stack_index;
	int firstArgument;

	//
	// Receiver has a method to be called
	//

	if(selectorNameLength>0){

		strcpy(selectorName,lua_tostring(state,lua_upvalueindex(1)));
		for(stack_index=0;stack_index<selectorNameLength;stack_index++)
			if(selectorName[stack_index]=='_')
				selectorName[stack_index]=':';
		selectorName[stack_index]='\0';
		selector=NSSelectorFromString([NSString stringWithUTF8String:selectorName]);
		signature=[receiver methodSignatureForSelector:selector];
		firstArgument = 2;

		//
		// Convert the method's name of the selector to canonical Objective-C form
		//

		if(signature==nil){
			selectorName[stack_index]=':';
			selectorName[stack_index+1]='\0';
			selector=NSSelectorFromString([NSString stringWithUTF8String:selectorName]);
			signature=[receiver methodSignatureForSelector:selector];
			}

		}

	//
	// Receiver has no method to be called, i.e. it's a block
	//

	else{

		stack_index = 0;
		strcpy(selectorName,"");
		selector=nil;
		signature=lua_objc_blocksignature(receiver);
		firstArgument = 1;
		}

	if(signature==nil){
		lua_objc_methodcall_error("Reciever does not implement method.");
		}

	//
	// Create an NSInvocation to do the Objective-C calling for us
	//
	
	invocation=[NSInvocation invocationWithMethodSignature:signature];
	if(invocation==nil){
		lua_objc_methodcall_error("Unable to create NSInvocation.");		
		}
	[invocation setSelector:selector];
	[invocation setTarget:receiver];

	//
	// Create space for passing method arguments between the two environments
	//

	argumentCount=(int)[signature numberOfArguments];
	argumentSize=(unsigned)[signature frameLength];
	argumentValue=malloc(argumentSize);
	if(argumentValue==NULL){
		lua_objc_methodcall_error("Unable to allocate method argument conversion buffer.");		
		}
	bzero(argumentValue,argumentSize);

	//
	// Convert Lua arguments to Objective-C arguments
	//

	for(argumentIndex=firstArgument,luaArgument=2;argumentIndex<argumentCount;argumentIndex++,luaArgument++){
		argumentType=(char*)[signature getArgumentTypeAtIndex:argumentIndex];
		switch(*argumentType){
		
			//
			// Skip over modifiers for distributed objects
			//
		
			case LUA_OBJC_TYPE_IN:
			case LUA_OBJC_TYPE_INOUT:
			case LUA_OBJC_TYPE_OUT:
			case LUA_OBJC_TYPE_BYCOPY:
			case LUA_OBJC_TYPE_BYREF:
			case LUA_OBJC_TYPE_CONST:
			case LUA_OBJC_TYPE_ONEWAY:
				assert(0);
				break;
				
			//
			// Convert each parameter from Lua to Objective-C
			//
			
			case LUA_OBJC_TYPE_C99_BOOL:{
				if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(_Bool,lua_tonumber(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to a C99 _Bool).");
					}
				break;
				}
			case LUA_OBJC_TYPE_CHAR:{
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(char,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(char,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to char).");
					}
				break;
				}
			case LUA_OBJC_TYPE_UNSIGNED_CHAR:{
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(unsigned char,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(unsigned char,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to unsigned char).");
					}
				break;
				}
			case LUA_OBJC_TYPE_DOUBLE:{
#ifdef LUA_OBJC_METHODCALL_PASS_FLOATS_IN_MARG_HEADER
				double value;
#endif
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(double,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(double,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to double).");
					}
#ifdef LUA_OBJC_METHODCALL_PASS_FLOATS_IN_MARG_HEADER
				if(luaFloatArguments>=LUA_OBJC_MARG_MAX_FLOATS){
					lua_objc_methodcall_error("Too many floating point arguments (The NeXT runtime on PPC only allows 13).");	
					}
				lua_objc_marg_setDoubleValue(argumentList,luaFloatArguments,value);
				luaFloatArguments++;
				marg_setValue(argumentList,argumentOffset,double,value);
#endif
				break;
				}
			case LUA_OBJC_TYPE_FLOAT:{
#ifdef LUA_OBJC_METHODCALL_PASS_FLOATS_IN_MARG_HEADER
				float value;
#endif
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(float,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(float,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to float).");
					}
#ifdef LUA_OBJC_METHODCALL_PASS_FLOATS_IN_MARG_HEADER
				if(luaFloatArguments>=LUA_OBJC_MARG_MAX_FLOATS){
					lua_objc_methodcall_error("Too many floating point arguments (The NeXT runtime on PPC only allows 13).");	
					}
				lua_objc_marg_setDoubleValue(argumentList,luaFloatArguments,value);
				luaFloatArguments++;
				marg_setValue(argumentList,argumentOffset,float,value);
#endif
				break;
				}
			case LUA_OBJC_TYPE_INT:{
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(int,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(int,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to int).");
					}
				break;
				}
			case LUA_OBJC_TYPE_UNSIGNED_INT:{
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(unsigned int,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(unsigned int,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to unsigned int).");
					}
				break;
				}
			case LUA_OBJC_TYPE_LONG:{
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(long,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(long,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to long).");
					}
				break;
				}
			case LUA_OBJC_TYPE_UNSIGNED_LONG:{
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(unsigned long,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(unsigned long,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to unsigned long).");
					}
				break;
				}
			case LUA_OBJC_TYPE_LONG_LONG:{
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(long long,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(long long,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to long long).");
					}
				break;
				}
			case LUA_OBJC_TYPE_UNSIGNED_LONG_LONG:{
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(unsigned long long,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(unsigned long long,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to unsigned long long).");
					}
				break;
				}
			case LUA_OBJC_TYPE_SHORT:{
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(short,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(short,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to short).");
					}
				break;
				}
			case LUA_OBJC_TYPE_UNSIGNED_SHORT:{
				if(lua_isnumber(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(unsigned short,lua_tonumber(state,luaArgument));
					}
				else if(lua_isboolean(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(unsigned short,lua_toboolean(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to unsigned short).");
					}
				break;
				}
			case LUA_OBJC_TYPE_STRING:{
				if(lua_isstring(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(const char*,lua_tostring(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting something that can be converted to char*).");
					}
				break;
				}
			case LUA_OBJC_TYPE_ID:{
				if(lua_isnil(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(id,nil);
					}
				else if(lua_objc_isid(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(id,lua_objc_toid(state,luaArgument));
					}
				else{
					lua_objc_methodcall_setArgumentValue(id,lua_objc_topropertylist(state,luaArgument));
					}
				break;
				}
			case LUA_OBJC_TYPE_CLASS:{
				if(lua_objc_isid(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(Class,lua_objc_toid(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting an Objective-C Class).");
					}
				break;
				}
			case LUA_OBJC_TYPE_SELECTOR:{
				if(lua_isstring(state,luaArgument)){
					SEL value;
					value=NSSelectorFromString([NSString stringWithUTF8String:(lua_tostring(state,luaArgument))]);
					lua_objc_methodcall_setArgumentValue(SEL,value);
					}
				else if(lua_isuserdata(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(SEL,lua_touserdata(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting an Objective-C SEL).");
					}
				break;
				}
			case LUA_OBJC_TYPE_POINTER:{
				if(lua_isuserdata(state,luaArgument)){
					lua_objc_methodcall_setArgumentValue(void*,lua_touserdata(state,luaArgument));
					}
				else{
					lua_objc_methodcall_error("Type mismatch for method argument (expecting a void*).");
					}
				break;
				}
			case LUA_OBJC_TYPE_ARRAY:
			case LUA_OBJC_TYPE_STRUCT:{
				memcpy(argumentValue,lua_touserdata(state,luaArgument),argumentSize);				
				break;
				}
			case LUA_OBJC_TYPE_UNION:{
				
				//
				// NSInvocation does not support union parameters... unlike our hand-tuned implementation below :-(
				//
				 
				lua_objc_methodcall_error("Unsupported type for method argument (union).");
				}
			case LUA_OBJC_TYPE_BITFIELD:{
				lua_objc_methodcall_error("Unsupported type for method argument (bitfield).");
				}
			case LUA_OBJC_TYPE_VOID:{
				lua_objc_methodcall_error("Invalid type for method argument (void).");
				}
			case LUA_OBJC_TYPE_UNKNOWN:
			default:{
				lua_objc_methodcall_error("Unknown type for method argument.");
				}
			}
		[invocation setArgument:argumentValue atIndex:argumentIndex];
		}

	//
	// Send the Objective-C message, pass the resultValue to Lua
	//
	 
	[invocation invoke];
	if(*[signature methodReturnType]!=LUA_OBJC_TYPE_VOID){
		resultSize=(unsigned)[signature methodReturnLength];
		resultValue=malloc(resultSize);
		if(resultValue==NULL){
			lua_objc_methodcall_error("Unable to allocate resultValue conversion buffer.");
			}
		bzero(resultValue,resultSize);
		[invocation getReturnValue:resultValue];
		}

	resultCount=-1;
	while(resultCount==-1){

		//
		// Ignore modifiers used for distributed objects
		//
		const char *type = [signature methodReturnType];
		int pos = 0;
		if (type[0] == LUA_OBJC_TYPE_IN
			|| type[0] == LUA_OBJC_TYPE_INOUT
			|| type[0] == LUA_OBJC_TYPE_OUT
			|| type[0] == LUA_OBJC_TYPE_BYCOPY
			|| type[0] == LUA_OBJC_TYPE_BYREF
			|| type[0] == LUA_OBJC_TYPE_CONST
			|| type[0] == LUA_OBJC_TYPE_ONEWAY)
			pos++;

		switch(type[pos]){

			//
			// Skip over modifiers for distributed objects
			//

			case LUA_OBJC_TYPE_IN:
			case LUA_OBJC_TYPE_INOUT:
			case LUA_OBJC_TYPE_OUT:
			case LUA_OBJC_TYPE_BYCOPY:
			case LUA_OBJC_TYPE_BYREF:
			case LUA_OBJC_TYPE_CONST:
			case LUA_OBJC_TYPE_ONEWAY:
				assert(0);
				break;

			//
			// Return method result to Lua
			//
				
			case LUA_OBJC_TYPE_BITFIELD:{
				lua_objc_methodcall_error("Unsupported return type for method (bitfield).");
				}
			case LUA_OBJC_TYPE_C99_BOOL:{
				lua_pushboolean(state,(_Bool)(*((_Bool*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_CHAR:{
				lua_pushnumber(state,(char)(*((char*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_UNSIGNED_CHAR:{
				lua_pushnumber(state,(unsigned char)(*((unsigned char*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_DOUBLE:
				lua_pushnumber(state,(lua_Number)(*((double*)resultValue)));
				break;
			case LUA_OBJC_TYPE_FLOAT:
				lua_pushnumber(state,(lua_Number)(*((float*)resultValue)));
				break;
			case LUA_OBJC_TYPE_INT:{
				lua_pushnumber(state,(int)(*((int*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_UNSIGNED_INT:{
				lua_pushnumber(state,(unsigned int)(*((unsigned int*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_LONG:{
				lua_pushnumber(state,(long)(*((long*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_UNSIGNED_LONG:{
				lua_pushnumber(state,(unsigned long)(*((unsigned long*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_LONG_LONG:{
				lua_pushnumber(state,(long long)(*((long long*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_UNSIGNED_LONG_LONG:{
				lua_pushnumber(state,(unsigned long long)(*((unsigned long long*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_SHORT:{
				lua_pushnumber(state,(short)(*((short*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_UNSIGNED_SHORT:{
				lua_pushnumber(state,(unsigned short)(*((unsigned short*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_VOID:
				resultCount=0;
				break;
			case LUA_OBJC_TYPE_STRING:{
				lua_pushstring(state,(char*)(*((char**)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_ID:{
				if(!(lua_objc_pushpropertylist(state,(id)(*((id*)resultValue))))){
					lua_objc_pushid(state,(id)(*((id*)resultValue)));
					}
				break;
				}
			case LUA_OBJC_TYPE_CLASS:{
				lua_objc_pushid(state,(id)(*((id*)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_SELECTOR:{
				lua_pushstring(state,[NSStringFromSelector((SEL)(*((SEL*)resultValue))) UTF8String]);
				break;
				}
			case LUA_OBJC_TYPE_POINTER:{
				lua_pushlightuserdata(state,(id)(*((void**)resultValue)));
				break;
				}
			case LUA_OBJC_TYPE_ARRAY:
			case LUA_OBJC_TYPE_STRUCT:
			case LUA_OBJC_TYPE_UNION:{
				void* temp=lua_newuserdata(state,resultSize);
				if(temp==NULL){
					lua_objc_methodcall_error("Unable to allocate enough space on Lua stack to pass result.");
					}
				memcpy(temp,resultValue,resultSize);
				break;
				}
			case LUA_OBJC_TYPE_UNKNOWN:
			default:{
				lua_objc_methodcall_error("Unknown return type for method.");
				}
			}
		if(resultCount!=0){
			resultCount=1;
			}
		}
		
	//
	// Clean up and leave (lua_objc_methodcall_error does a "goto" to here)
	//
		
	finish:{
		if(argumentValue){
			free(argumentValue);
			}
		if(resultValue){
			free(resultValue);
			}
		if(selectorName){
			free(selectorName);
			}
		if(luaErrorMessage){
			luaL_error(state,luaErrorMessage);
			}
		}
	return resultCount;
	}

//
// Called by the Lua interpreter whenever a Lua script attempts to access
// members of a Lua proxy for an Objective-C id.
//
// This method first tries to retrieve the named value from the table itself.
// If that fails, it assumes the script asked for an Objective-C method, so it
// redirects Lua to the lua_objc_methodcall() function. 
//
// This means that if you store a value in the table part of an id-proxy using a
// key that matches a method name, you won't be able to call that method (until
// you delete the value by assigning the value "nil" to the key).
//
// To get around the fact that Lua does not pass the name of a function to the
// function itself, this is passed to lua_objc_methodcall() as a closure value. 
// The name of the function is required by lua_objc_methodcall() to look up the
// corresponding Objective-C selector.
//
	
int lua_objc_methodlookup(lua_State* state){
#ifdef LUA_OBJC_EACH_LUA_TYPE_HAS_METATABLE
	if(lua_istable(state,-2)){
		lua_pushvalue(state,-1);
		lua_rawget(state,-3);
		if(!lua_isnil(state,-1)){
			return 1;
			}
		else{
			lua_pop(state,1);
			}
		}
	lua_pushvalue(state,-1);
	lua_pushcclosure(state,&lua_objc_methodcall,1);
#else
	lua_pushvalue(state,-1);
	lua_rawget(state,-3);
	if(lua_isnil(state,-1)){
		lua_pop(state,1);
		lua_pushvalue(state,-1);
		lua_pushcclosure(state,&lua_objc_methodcall,1);
		}
#endif
	return 1;
	}
	
//
// Objective-C Type Alignment and Size
//

#pragma mark Objective-C Type Alignment and Size

#define lua_objc_type_skip_name(type) {\
	while((*type)&&(*type!='='))\
		type++;\
	if(*type)\
		type++;\
	}

#define lua_objc_type_skip_number(type) {\
	if(*type=='+')\
		type++;\
	if(*type=='-')\
		type++;\
	while((*type)&&(*type>='0')&&(*type<='9'))\
		type++;\
	}

#define lua_objc_type_skip_past_char(type,char) {\
	while((*type)&&(*type!=char))\
		type++;\
	if((*type)&&(*type==char))\
		type++;\
	else\
		result=0;\
	}\
	
//
// Given an Objective-C type encoding, this function calculates the alignment
// in bytes of the type. 
//
// The function alters its parameter to point to the start of the next
// description in the type encoding.
//
// Returns 0 if the type_encoding is improperly encoded.
// This function *should* calculate structure sizes correctly for either PowerPC
// or Intel Macs, but it has only been tested on PowerPC.
//
 
unsigned lua_objc_type_alignment(char** type_encoding){
	int result=-1;
	*type_encoding=(char*)NSGetSizeAndAlignment(*type_encoding,NULL,(NSUInteger*)&result);
	return result;
	}
	
//
// Given an Objective-C type encoding, this function calculates the size in
// bytes of the type. 
//
// The function alters its parameter to point to the start of the next
// description in the type encoding.
//
// Returns 0 if the type_encoding is improperly encoded.
// This function *should* calculate structure sizes correctly for either PowerPC
// or Intel Macs, but it has only been tested on PowerPC.
//

unsigned lua_objc_type_size(char** type_encoding){
	int result=-1;
	*type_encoding=(char*)NSGetSizeAndAlignment(*type_encoding,(NSUInteger*)&result,NULL);
	return result;
	}

//
// Print to the console the contents of the stack, this function prints a table
// with the type and value of all the objects in the stack starting from the top.
//

void lua_objc_printstack(lua_State* state){
	int top = lua_gettop(state);
	printf("Lua stack:\n");
	for(int idx=-1; idx>=-top; idx--){
		int type = lua_type(state, idx);
		printf("%d\t%s\t%s\n", idx, lua_typename(state, type), lua_tostring(state, idx));
		}
	}
