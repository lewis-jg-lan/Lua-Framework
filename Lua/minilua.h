/* This is a heavily customized and minimized copy of Lua 5.1.5. */
/* It's only used to build LuaJIT. It does NOT have all standard functions! */
/******************************************************************************
 * Copyright (C) 1994-2012 Lua.org, PUC-Rio.  All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 ******************************************************************************/
#ifdef _MSC_VER
typedef unsigned __int64 U64;
#else
typedef unsigned long long U64;
#endif
typedef enum{
	TM_INDEX,
	TM_NEWINDEX,
	TM_GC,
	TM_MODE,
	TM_EQ,
	TM_ADD,
	TM_SUB,
	TM_MUL,
	TM_DIV,
	TM_MOD,
	TM_POW,
	TM_UNM,
	TM_LEN,
	TM_LT,
	TM_LE,
	TM_CONCAT,
	TM_CALL,
	TM_N
}TMS;
typedef unsigned int lu_int32;
typedef size_t lu_mem;
typedef unsigned char lu_byte;
typedef union{double u;void*s;long l;}L_Umaxalign;
#define check_exp(c,e)(e)
#define cast(t,exp)((t)(exp))
typedef lu_int32 Instruction;
typedef union GCObject GCObject;
typedef struct GCheader{
	GCObject*next;lu_byte tt;lu_byte marked;
}GCheader;
typedef union{
	GCObject*gc;
	void*p;
	lua_Number n;
	int b;
}Value;
typedef struct lua_TValue{
	Value value;int tt;
}TValue;
#define clvalue(o)check_exp(ttisfunction(o),&(o)->value.gc->cl)
#define checkliveness(g,obj)
#define sethvalue(L,obj,x){TValue*i_o=(obj);i_o->value.gc=cast(GCObject*,(x));i_o->tt=5;checkliveness(G(L),i_o);}
typedef TValue*StkId;
typedef union TString{
	L_Umaxalign dummy;
	struct{
		GCObject*next;lu_byte tt;lu_byte marked;
		lu_byte reserved;
		unsigned int hash;
		size_t len;
	}tsv;
}TString;
typedef union Udata{
	L_Umaxalign dummy;
	struct{
		GCObject*next;lu_byte tt;lu_byte marked;
		struct Table*metatable;
		struct Table*env;
		size_t len;
	}uv;
}Udata;
typedef struct Proto{
	GCObject*next;lu_byte tt;lu_byte marked;
	TValue*k;
	Instruction*code;
	struct Proto**p;
	int*lineinfo;
	struct LocVar*locvars;
	TString**upvalues;
	TString*source;
	int sizeupvalues;
	int sizek;
	int sizecode;
	int sizelineinfo;
	int sizep;
	int sizelocvars;
	int linedefined;
	int lastlinedefined;
	GCObject*gclist;
	lu_byte nups;
	lu_byte numparams;
	lu_byte is_vararg;
	lu_byte maxstacksize;
}Proto;
typedef struct UpVal{
	GCObject*next;lu_byte tt;lu_byte marked;
	TValue*v;
	union{
		TValue value;
		struct{
			struct UpVal*prev;
			struct UpVal*next;
		}l;
	}u;
}UpVal;
typedef struct CClosure{
	GCObject*next;lu_byte tt;lu_byte marked;lu_byte isC;lu_byte nupvalues;GCObject*gclist;struct Table*env;
	lua_CFunction f;
	TValue upvalue[1];
}CClosure;
typedef struct LClosure{
	GCObject*next;lu_byte tt;lu_byte marked;lu_byte isC;lu_byte nupvalues;GCObject*gclist;struct Table*env;
	struct Proto*p;
	UpVal*upvals[1];
}LClosure;
typedef union Closure{
	CClosure c;
	LClosure l;
}Closure;
typedef union TKey{
	struct{
		Value value;int tt;
		struct Node*next;
	}nk;
	TValue tvk;
}TKey;
typedef struct Node{
	TValue i_val;
	TKey i_key;
}Node;
typedef struct Table{
	GCObject*next;lu_byte tt;lu_byte marked;
	lu_byte flags;
	lu_byte lsizenode;
	struct Table*metatable;
	TValue*array;
	Node*node;
	Node*lastfree;
	GCObject*gclist;
	int sizearray;
}Table;
typedef struct Zio ZIO;
typedef struct Mbuffer{
	char*buffer;
	size_t n;
	size_t buffsize;
}Mbuffer;
#define gt(L)(&L->l_gt)
#define registry(L)(&G(L)->l_registry)
typedef struct stringtable{
	GCObject**hash;
	lu_int32 nuse;
	int size;
}stringtable;
typedef struct CallInfo{
	StkId base;
	StkId func;
	StkId top;
	const Instruction*savedpc;
	int nresults;
	int tailcalls;
}CallInfo;
#define curr_func(L)(clvalue(L->ci->func))
typedef struct global_State{
	stringtable strt;
	lua_Alloc frealloc;
	void*ud;
	lu_byte currentwhite;
	lu_byte gcstate;
	int sweepstrgc;
	GCObject*rootgc;
	GCObject**sweepgc;
	GCObject*gray;
	GCObject*grayagain;
	GCObject*weak;
	GCObject*tmudata;
	Mbuffer buff;
	lu_mem GCthreshold;
	lu_mem totalbytes;
	lu_mem estimate;
	lu_mem gcdept;
	int gcpause;
	int gcstepmul;
	lua_CFunction panic;
	TValue l_registry;
	struct lua_State*mainthread;
	UpVal uvhead;
	struct Table*mt[(8+1)];
	TString*tmname[TM_N];
}global_State;
struct lua_State{
	GCObject*next;lu_byte tt;lu_byte marked;
	lu_byte status;
	StkId top;
	StkId base;
	global_State*l_G;
	CallInfo*ci;
	const Instruction*savedpc;
	StkId stack_last;
	StkId stack;
	CallInfo*end_ci;
	CallInfo*base_ci;
	int stacksize;
	int size_ci;
	unsigned short nCcalls;
	unsigned short baseCcalls;
	lu_byte hookmask;
	lu_byte allowhook;
	int basehookcount;
	int hookcount;
	lua_Hook hook;
	TValue l_gt;
	TValue env;
	GCObject*openupval;
	GCObject*gclist;
	struct lua_longjmp*errorJmp;
	ptrdiff_t errfunc;
};
#define G(L)(L->l_G)
union GCObject{
	GCheader gch;
	union TString ts;
	union Udata u;
	union Closure cl;
	struct Table h;
	struct Proto p;
	struct UpVal uv;
	struct lua_State th;
};
