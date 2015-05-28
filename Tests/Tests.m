/*
 * Test.m
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
#import <XCTest/XCTest.h>
#import <Lua/LuaVirtualMachine.h>
#import <JavaScriptCore/JavaScriptCore.h>

#pragma mark Mocks

@interface MockObject : NSObject
@property (strong) NSString *name;
- (void)setName:(NSString *)name appendingNumber:(NSNumber *)number;
@end

@implementation MockObject
@synthesize name = _name;
- (void)setName:(NSString *)name appendingNumber:(NSNumber *)number {
	self.name = [name stringByAppendingFormat:@" %@",[number stringValue]];
}
@end

#pragma mark Tests

@interface Tests : XCTestCase {
	LuaVirtualMachine *_virtualMachine;
}
@end

@implementation Tests

#pragma mark SetUp & TearDown

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

#pragma mark Test Methods

- (void)testMultipleLuaContexts {

	/* Test the scope of global and local variables in the same context */
	LuaContext *ctx = [LuaContext new];

	[ctx evaluateScript:
	 @LUA_STRING(
				 if not aGlobalVariable then
					local aLocalVariable = 'the value'
					aGlobalVariable = aLocalVariable
				 end
				 )
	 ];

	XCTAssertNil(ctx[@"aLocalVariable"], @"A local variable SHOULD NOT be available from a global context");
	XCTAssertTrue([[ctx[@"aGlobalVariable"] toObject] isEqualToString:@"the value"], @"A global variable SHOULD be available from a global context");

	/* Test the scope of global and local variables from a second context */
	LuaContext *ctx2 = [[LuaContext alloc] initWithVirtualMachine:ctx.virtualMachine];
	XCTAssertNotNil(ctx2, @"Couldn't initialize a separate global context");

	[ctx2 evaluateScript:@"aGlobalVariableInAnotherContext = 'value in other context'"];
	XCTAssertTrue(ctx2[@"aGlobalVariable"] == nil && ctx[@"aGlobalVariableInAnotherContext"] == nil, @"A global variable from one context SHOUD NOT be available to other contexts");

	/* Test passing values between contexts */
	ctx2[@"theOtherGlobalVariable"] = [ctx evaluateScript:@"return aGlobalVariable"];
	XCTAssertTrue([[ctx2[@"theOtherGlobalVariable"] toObject] isEqualToString:@"the value"]);
	[ctx2 evaluateScript:@"theOtherGlobalVariable = 'changed'"];
	XCTAssertTrue([[ctx2[@"theOtherGlobalVariable"] toObject] isEqualToString:@"changed"]);
	XCTAssertTrue([[ctx[@"aGlobalVariable"] toObject] isEqualToString:@"the value"]);
}

- (void)testRetrievingValuesFromTheLuaContext {
	LuaContext *ctx = [LuaContext new];

	NSNumber *result = [[ctx evaluateScript:
						 @LUA_STRING(
									 anIntNumber = 55
									 aNegativeIntNumber = -15

									 aFloatNumber = 25.33
									 aNegativeFloatNumber = -45.25

									 aTrueBooleanValue = true
									 aFalseBooleanValue = false

									 aStringWithANumber = '1.11e5'

									 year2000InEpochTime = 946684800

									 aTable = {color='blue', number=2, subtable={int=anIntNumber, float=aFloatNumber}}
									 
									 return anIntNumber + aFloatNumber
									 )
						 ] toObject];

	XCTAssertTrue([[ctx[@"anIntNumber"] toObject] intValue] == 55);
	XCTAssertTrue([[ctx[@"aNegativeIntNumber"] toObject] intValue] == -15);

	XCTAssertTrue([[ctx[@"aFloatNumber"] toObject] floatValue] == 25.33f);
	XCTAssertTrue([[ctx[@"aNegativeFloatNumber"] toObject] floatValue] == -45.25f);

	XCTAssertTrue([[ctx[@"aTrueBooleanValue"] toObject] boolValue] == YES);
	XCTAssertTrue([[ctx[@"aFalseBooleanValue"] toObject] boolValue] == NO);

	XCTAssertTrue([result floatValue] == 55 + 25.33f);

	XCTAssertTrue([ctx[@"anIntNumber"] toInt32] == 55);
	XCTAssertTrue([ctx[@"aNegativeIntNumber"] toInt32] == -15);
	XCTAssertTrue([ctx[@"anIntNumber"] toUInt32] == 55);

	XCTAssertTrue([ctx[@"aFloatNumber"] toDouble] == 25.33);
	XCTAssertTrue([ctx[@"aNegativeFloatNumber"] toDouble] == -45.25);

	XCTAssertTrue([ctx[@"aTrueBooleanValue"] toBool] == YES);
	XCTAssertTrue([ctx[@"aFalseBooleanValue"] toBool] == NO);

	XCTAssertTrue([[ctx[@"anIntNumber"] toNumber] intValue] == 55);
	XCTAssertTrue([[ctx[@"aFloatNumber"] toNumber] floatValue] == 25.33f);
	XCTAssertTrue([[ctx[@"aStringWithANumber"] toNumber] floatValue] == 1.11e5f);

	XCTAssertTrue([[ctx[@"anIntNumber"] toString] isEqualToString:@"55"]);
	XCTAssertTrue([[ctx[@"aFloatNumber"] toString] isEqualToString:@"25.33"]);
	XCTAssertTrue([[ctx[@"aStringWithANumber"] toString] isEqualToString:@"1.11e5"]);

	NSDateComponents *comps = [[NSDateComponents alloc] init];
	comps.day = 1;
	comps.month = 1;
	comps.year = 2000;

	XCTAssertEqualWithAccuracy([[ctx[@"year2000InEpochTime"] toDate] timeIntervalSinceReferenceDate],
							   [[[NSCalendar currentCalendar] dateFromComponents:comps] timeIntervalSinceReferenceDate], 60*60*24);

	NSDictionary *table = [ctx[@"aTable"] toObject];
	XCTAssertNotNil(table, @"Could't retrieve a table");
	XCTAssertTrue([table[@"color"] isEqualToString:@"blue"]);
	XCTAssertTrue([table[@"number"] isEqual:@(2)]);
	XCTAssertTrue([table[@"subtable"] isKindOfClass:[NSDictionary class]]);
	NSDictionary *subTable = table[@"subtable"];
	XCTAssertTrue([subTable isKindOfClass:[NSDictionary class]]);
	XCTAssertTrue([subTable[@"int"] isEqual:@(55)]);
	XCTAssertTrue([subTable[@"float"] isEqual: @(25.33)]);
}

- (void)testCallingObjCMethodsFromLua {
	LuaContext *ctx = [LuaContext new];

	/* The ObjC object */
	MockObject *mockObj = [[MockObject alloc] init];
	mockObj.name = @"old name";

	/* Pass the object to the Lua context */
	ctx[@"mockObj"] = mockObj;

	/* Modify the object from a Lua script */
	[ctx evaluateScript:
	 @LUA_STRING(
				 oldName = mockObj:name()
				 mockObj:setName('new name')
				 newName = mockObj:name()
				 mockObj:setName_appendingNumber('name with number', 1.5)
				 )
	 ];

	XCTAssertTrue([[ctx[@"oldName"] toString] isEqualToString:@"old name"]);
	XCTAssertTrue([[ctx[@"newName"] toString] isEqualToString:@"new name"]);
	XCTAssertTrue([mockObj.name isEqualToString:@"name with number 1.5"]);
}

- (void)testCallingLuaFunctionsFromObjC {
	LuaContext *ctx = [LuaContext new];

	/* The lua script */
	[ctx evaluateScript:
	 @LUA_STRING(
				 function aFunction(first, second)
					return tostring(first)..' '..tostring(second)
				 end
				 )
	 ];

	/* Call the Lua function from ObjC */
	LuaValue *result = [ctx[@"aFunction"] callWithArguments:@[@"first parameter", @(3.33)]];
	XCTAssertNotNil(result, @"The funtion has not return value");

	/* Check the returned value */
	XCTAssertTrue([[result toString] isEqualToString:@"first parameter 3.33"], @"The return value doesn't match");
}

- (void)testCallingObjCBlocksFromLua {
	LuaContext *ctx = [LuaContext new];
	LuaValue *result;

	/* Pass the ObjC block to Lua */
	ctx[@"aBlock"] = ^(int parameter, NSString *anotherParameter) {
		return [NSString stringWithFormat:@"%d %@", parameter, anotherParameter];
	};

	/* Retrieve the block from the Lua context */
	NSString *(^returnedBlock)() = [ctx[@"aBlock"] toObject];
	XCTAssertTrue([returnedBlock(123, @"string parameter") isEqualToString:@"123 string parameter"]);

	/* Call the block from Lua */
	result = [ctx evaluateScript:@"return aBlock(456, 'another test with string value')"];

	XCTAssertNotNil(result, @"Couldn't call the ObjC block from Lua");
	XCTAssertTrue([[result toString] isEqualToString:@"456 another test with string value"], @"The returned value doesn't match");

	/* Call an onject that is not a block */
	ctx[@"anObject"] = [NSObject new];
	result = [ctx evaluateScript:@"return anObject()"];
	XCTAssertNil(result, @"An object can't be called like a block");
}

static void measureBlock(id self, void(^block)(), int passCount, NSTimeInterval *time, NSTimeInterval *stdev) {
	NSMutableArray *passTimes = [NSMutableArray arrayWithCapacity:passCount];

	clock_t startTime, finishTime;

	double passTime;

	for( int i=0; i<passCount; ++i ) {
		startTime = clock();
		block();
		finishTime = clock();
		passTime = (double)(finishTime - startTime) / CLOCKS_PER_SEC;
		[passTimes addObject:@(passTime)];
	}

	NSExpression *expression;

	expression = [NSExpression expressionForFunction:@"average:" arguments:@[[NSExpression expressionForConstantValue:passTimes]]];
	*time = [[expression expressionValueWithObject:nil context:nil] doubleValue];

	expression = [NSExpression expressionForFunction:@"stddev:" arguments:@[[NSExpression expressionForConstantValue:passTimes]]];
	*stdev = [[expression expressionValueWithObject:nil context:nil] doubleValue] / *time * 100;
}

static BOOL compareObjects(id lobj, id robj) {
	if( [lobj isKindOfClass:[NSDictionary class]] ) {
		for( id key in lobj ) {
			if( !compareObjects(lobj[key], robj[key]) ) {
				return NO;
			}
		}
		return YES;
	}
	else if( [lobj isKindOfClass:[NSArray class]] ) {
		for( int i = 0; i < [lobj count]; ++i ) {
			if( !compareObjects(lobj[i], robj[i]) ) {
				return NO;
			}
		}
		return YES;
	}
	else {
		return [lobj isEqual:robj];
	}
}

static NSString *const luaTriangularNumberScript = @LUA_STRING
(
 function triangularNumber(n)
	local x = 0
	for i = 0,n do
		x = x + i
	end
	return x
 end
 );

static NSString *const luaDictionaryAccessScript = @LUA_STRING
(
 local result = {}
 for k, v in pairs(dictionary) do
	result[k] = v
 end
 return result;
 );

static NSString *const luaArrayAccessScript = @LUA_STRING
(
 local result = {}
 for i = 1, #array do
	result[i] = array[i]
 end
 return result;
 );

static NSString *const luaDeepCopyScript = @LUA_STRING
(
 local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == 'table' then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return setmetatable(copy, getmetatable(original));
 end
 return deepCopy(object)
 );

static NSString *const jsTriangularNumberScript = @LUA_STRING
(
 function triangularNumber(n) {
	 var i, x = 0;
	 for (i = 0; i <= n; ++i) {
		 x = x + i;
	 }
	 return x;
 }
 );

static NSString *const jsDictionaryAccessScript = @LUA_STRING
(
 var key, result = {};
 for (key in dictionary) {
	 result[key] = dictionary[key];
 }
 result;
 );

static NSString *const jsArrayAccessScript = @LUA_STRING
(
 var i, result = [];
 for (i = 0; i < array.length; i++) {
	 result[i] = array[i];
 }
 result;
 );

static NSString *const jsDeepCopyScript = @LUA_STRING
(
 function deepCopy(original) {
	 var copy = original.constructor();
	 for(var key in original) {
		 var value = original[key];
		 if(typeof(original[key])=='object' && original[key] != null) {
			 value = deepCopy(value);
		 }
		 copy[key] = value;
	 }
	 return copy;
 }
 deepCopy(object)
 );

- (void)testPerformance {
	const int passCount = 100;
	const int triangularNumber = passCount*(passCount+1)/2;

	NSDictionary *dictionary = @{@"Key1":@1, @"Key2": @2.3, @"Key3": @"four", @"Key4": @YES};
	NSArray *array = @[@1, @2.3, @"four", @YES];
	id obj1 = @{@"Key1": dictionary, @"Key2": array};
	id obj2 = @[dictionary, array];
	id obj3 = @{@"Key1": array, @"Key2": dictionary};
	id obj4 = @[array, dictionary];
	id object = @{@"Key1": obj1, @"Key2": obj2, @"Key3": obj3, @"Key4": obj4};

	NSTimeInterval luaTime, luaStdev, jsTime, jsStdev;

	BOOL testPassed;

	LuaContext *ctx = [LuaContext new];
	LuaContext *luaCtx = [LuaContext new];
	JSContext *jsCtx = [JSContext new];

	[self measureBlock:^{
		[ctx evaluateScript:luaTriangularNumberScript];
		XCTAssert([[ctx[@"triangularNumber"] callWithArguments:@[@(passCount)]] toInt32] == triangularNumber, @"result is wrong");
	}];

	measureBlock(self,
				 ^{
					 [luaCtx evaluateScript:luaTriangularNumberScript];
					 XCTAssert([[luaCtx[@"triangularNumber"] callWithArguments:@[@(passCount)]] toInt32] == triangularNumber, @"result is wrong");
				 },
				 passCount,
				 &luaTime, &luaStdev
				 );
	NSLog(@"Lua execution time %f with standard deviation %.3f%%", luaTime, luaStdev);

	measureBlock(self,
				 ^{
					 [jsCtx evaluateScript:jsTriangularNumberScript];
					 XCTAssert([[jsCtx[@"triangularNumber"] callWithArguments:@[@(passCount)]] toInt32] == triangularNumber, @"result is wrong");
				 },
				 passCount,
				 &jsTime, &jsStdev
				 );
	NSLog(@"JavaScript execution time %f with standard deviation %.3f%%", jsTime, jsStdev);

	testPassed = luaTime < jsTime;
	NSLog(@"Triangular Number: Lua execution time is %s than JavaScript's", testPassed ? "less" : "greater or equal");
	XCTAssert(testPassed, @"Triangular Number: Lua execution time is %s than JavaScript's", testPassed ? "less" : "greater or equal");

	measureBlock(self,
				 ^{
					 luaCtx[@"dictionary"] = dictionary;
					 NSDictionary *result = [[luaCtx evaluateScript:luaDictionaryAccessScript] toDictionary];
					 XCTAssert(compareObjects(dictionary, result), @"objects are different");
				 },
				 passCount,
				 &luaTime, &luaStdev
				 );
	NSLog(@"Lua execution time %f with standard deviation %.3f%%", luaTime, luaStdev);

	measureBlock(self,
				 ^{
					 jsCtx[@"dictionary"] = dictionary;
					 NSDictionary *result = [[jsCtx evaluateScript:jsDictionaryAccessScript] toDictionary];
					 XCTAssert(compareObjects(dictionary, result), @"objects are different");
				 },
				 passCount,
				 &jsTime, &jsStdev
				 );
	NSLog(@"JavaScript execution time %f with standard deviation %.3f%%", jsTime, jsStdev);

	testPassed = luaTime < jsTime;
	NSLog(@"Dictionary access: Lua execution time is %s than JavaScript's", testPassed ? "less" : "greater or equal");
	XCTAssert(testPassed, @"Dictionary access: Lua execution time is %s than JavaScript's", testPassed ? "less" : "greater or equal");

	measureBlock(self,
				 ^{
					 luaCtx[@"array"] = array;
					 NSArray *result = [[luaCtx evaluateScript:luaArrayAccessScript] toArray];
					 XCTAssert(compareObjects(array, result), @"objects are different");
				 },
				 passCount,
				 &luaTime, &luaStdev
				 );
	NSLog(@"Lua execution time %f with standard deviation %.3f%%", luaTime, luaStdev);

	measureBlock(self,
				 ^{
					 jsCtx[@"array"] = array;
					 NSArray *result = [[jsCtx evaluateScript:jsArrayAccessScript] toArray];
					 XCTAssert(compareObjects(array, result), @"objects are different");
				 },
				 passCount,
				 &jsTime, &jsStdev
				 );
	NSLog(@"JavaScript execution time %f with standard deviation %.3f%%", jsTime, jsStdev);

	testPassed = luaTime < jsTime;
	NSLog(@"Array access: Lua execution time is %s than JavaScript's", testPassed ? "less" : "greater or equal");
	XCTAssert(testPassed, @"Array access: Lua execution time is %s than JavaScript's", testPassed ? "less" : "greater or equal");

	measureBlock(self,
				 ^{
					 luaCtx[@"object"] = object;
					 id result = [[luaCtx evaluateScript:luaDeepCopyScript] toObject];
					 XCTAssert(compareObjects(object, result), @"objects are different");
				 },
				 passCount,
				 &luaTime, &luaStdev
				 );
	NSLog(@"Lua execution time %f with standard deviation %.3f%%", luaTime, luaStdev);

	measureBlock(self,
				 ^{
					 jsCtx[@"object"] = object;
					 id result = [[jsCtx evaluateScript:jsDeepCopyScript] toObject];
					 XCTAssert(compareObjects(object, result), @"objects are different");
				 },
				 passCount,
				 &jsTime, &jsStdev
				 );
	NSLog(@"JavaScript execution time %f with standard deviation %.3f%%", jsTime, jsStdev);

	testPassed = luaTime < jsTime;
	NSLog(@"Deep copy: Lua execution time is %s than JavaScript's", testPassed ? "less" : "greater or equal");
	XCTAssert(testPassed, @"Deep copy: Lua execution time is %s than JavaScript's", testPassed ? "less" : "greater or equal");
}

@end
