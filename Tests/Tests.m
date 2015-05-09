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

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <Lua/LuaVirtualMachine.h>
#import "Mocks.h"

@interface Tests : XCTestCase {
	LuaVirtualMachine *_virtualMachine;
}
- (LuaContext *)createNewContext;
@end

@implementation Tests

#pragma mark SetUp & TearDown

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

#pragma mark Tests

- (void)testMultipleLuaContexts {

	/* Test the scope of global and local variables in the same context */
	LuaContext *ctx = [self createNewContext];

	[ctx evaluateScript:
	 @"if not aGlobalVariable then\n"
	 @"  local aLocalVariable = 'the value'\n"
	 @"  aGlobalVariable = aLocalVariable\n"
	 @"end\n"
	 ];

	XCTAssertNil(ctx[@"aLocalVariable"], @"A local variable SHOULD NOT be available from a global context");
	XCTAssertTrue([[ctx[@"aGlobalVariable"] toObject] isEqualToString:@"the value"], @"A global variable SHOULD be available from a global context");

	/* Test the scope of global and local variables from a second context */

	LuaContext *ctx2 = [self createNewContext];
	XCTAssertNotNil(ctx2, @"Couldn't initialize a separate global context");

	[ctx2 evaluateScript:@"aGlobalVariableInAnotherContext = 'value in other context'"];
	XCTAssertTrue(ctx2[@"aGlobalVariable"] == nil && ctx[@"aGlobalVariableInAnotherContext"] == nil, @"A global variable from one context SHOUD NOT be available to other contexts");
}

- (void)testLoadingFrameworksInMultipleContexts {

	/* Create an object from a loaded framework */
	LuaContext *ctx = [self createNewContext];

	LuaValue *result = [ctx evaluateScript:
						@"objc.import('AVKit')\n"
						@"local obj = objc.AVPlayerView:alloc():init()\n"
						@"return obj\n"];

	XCTAssertNotNil(result, @"Couldn't evaluate the script");
	XCTAssertTrue([[result toObject] class] == NSClassFromString(@"AVPlayerView"), @"Couldn't create an object from the loaded framework");

	/* Create an object from a framework loaded in a new context */

	LuaContext *ctx2 = [self createNewContext];
	XCTAssertNotNil(ctx2, @"Couldn't initialize a second context");

	result = [ctx2 evaluateScript:
			  @"objc.import('SpriteKit')\n"
			  @"local obj = objc.SKNode:alloc():init()\n"
			  @"return obj\n"];

	XCTAssertNotNil(result, @"Couldn't evaluate the script");
	XCTAssertTrue([[result toObject] class] == NSClassFromString(@"SKNode"), @"Couldn't create an object from a loaded framework in a separate context");
}

- (void)testRetrievingValuesFromTheLuaContext {
	LuaContext *ctx = [self createNewContext];

	NSNumber *result = [[ctx evaluateScript:
						 @"anIntNumber = 55\n"
						 @"aNegativeIntNumber = -15\n"

						 @"aFloatNumber = 25.33\n"
						 @"aNegativeFloatNumber = -45.25\n"

						 @"aTrueBooleanValue = true\n"
						 @"aFalseBooleanValue = false\n"

						 @"aStringWithANumber = '1.11e5'\n"

						 @"year2000InEpochTime = 946684800\n"

						 @"aTable = {color='blue', number=2, subtable={int=anIntNumber, float=aFloatNumber}}\n"

						 @"return anIntNumber + aFloatNumber\n"] toObject];

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
	LuaContext *ctx = [self createNewContext];

	/* The Obj-C object */
	MockObject *mockObj = [[MockObject alloc] init];
	mockObj.name = @"old name";

	/* Pass the object to the Lua context */
	ctx[@"mockObj"] = mockObj;

	/* Modify the object from a Lua script */
	[ctx evaluateScript:
	 @"oldName = mockObj:name()"
	 @"mockObj:setName('new name')"
	 @"newName = mockObj:name()"
	 @"mockObj:setName_appendingNumber('name with number', 1.5)"
	 ];

	XCTAssertTrue([[ctx[@"oldName"] toString] isEqualToString:@"old name"]);
	XCTAssertTrue([[ctx[@"newName"] toString] isEqualToString:@"new name"]);
	XCTAssertTrue([mockObj.name isEqualToString:@"name with number 1.5"]);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

#pragma mark HelperMethods

- (LuaContext *)createNewContext {
	if (!_virtualMachine) {
		_virtualMachine = [[LuaVirtualMachine alloc] init];
		XCTAssertNotNil(_virtualMachine, @"Couldn't initialize the Lua virtual machine");
	}
	LuaContext *newContext = [[LuaContext alloc] initWithVirtualMachine:_virtualMachine];
	XCTAssertNotNil(newContext, @"Couldn't initialize a new Lua context");
	return newContext;
}

@end
