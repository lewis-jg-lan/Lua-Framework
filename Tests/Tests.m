//
//  Tests.m
//  Tests
//
//  Created by Rhody Lugo on 5/5/15.
//
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import <Lua/LuaVirtualMachine.h>

@interface MockObject : NSObject
@property (strong) NSString *name;
@end

@implementation MockObject
@synthesize name = _name;
@end

@interface Tests : XCTestCase
- (LuaVirtualMachine *)sharedLuaVirtualMachine;
- (LuaContext *)sharedLuaContext;
@end

@implementation Tests

- (void)setUp {
    [super setUp];
	XCTAssertNotNil(self.sharedLuaVirtualMachine);
	XCTAssertNotNil(self.sharedLuaContext);
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testMultipleLuaContexts {
	[self.sharedLuaContext evaluateScript:
	 @"if not aGlobalVariable then\n"
	 @"  local aLocalVariable = 'the value'\n"
	 @"  aGlobalVariable = aLocalVariable\n"
	 @"end\n"
	 ];

	XCTAssertNil(self.sharedLuaContext[@"aLocalVariable"], @"A local variable SHOULD NOT be available from a global context");

	XCTAssertTrue([[self.sharedLuaContext[@"aGlobalVariable"] toObject] isEqualToString:@"the value"], @"A global variable SHOULD be available from a global context");

	LuaContext *anotherLuaContext = [[LuaContext alloc] initWithVirtualMachine:self.sharedLuaVirtualMachine];
	XCTAssertNotNil(anotherLuaContext, @"Couldn't initialize a separate global context");

	[anotherLuaContext evaluateScript:@"aGlobalVariableInAnotherContext = 'value in other context'"];

	XCTAssertTrue(anotherLuaContext[@"aGlobalVariable"] == nil && self.sharedLuaContext[@"aGlobalVariableInAnotherContext"] == nil, @"A global variable from one context SHOUD NOT be available to other contexts");
}

- (void)testLoadingFrameworksInMultipleContexts {
	LuaValue *result = [self.sharedLuaContext evaluateScript:
			   @"objc.import('AVKit')\n"
			   @"local obj = objc.AVPlayerView:alloc():init()\n"
			   @"return obj\n"];

	XCTAssertNotNil(result, @"Couldn't evaluate the script");

	id obj = [[self.sharedLuaContext evaluateScript:
			   @"objc.import('AVKit')\n"
			   @"local obj = objc.AVPlayerView:alloc():init()\n"
			   @"return obj\n"] toObject];

	XCTAssertTrue([obj class] == NSClassFromString(@"AVPlayerView"), @"Couldn't create an object from a loaded framework");

	LuaContext *anotherLuaContext = [[LuaContext alloc] initWithVirtualMachine:self.sharedLuaVirtualMachine];
	XCTAssertNotNil(anotherLuaContext, @"Couldn't initialize a separate global context");

	obj = [[anotherLuaContext evaluateScript:
			@"objc.import('SpriteKit')\n"
			@"local obj = objc.SKNode:alloc():init()\n"
			@"return obj\n"] toObject];

	XCTAssertTrue([obj class] == NSClassFromString(@"SKNode"), @"Couldn't create an object from a loaded framework in a separate context");
}

- (void)testRetrievingValues {
	NSNumber *result = [[self.sharedLuaContext evaluateScript:
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

	XCTAssertTrue([[self.sharedLuaContext[@"anIntNumber"] toObject] intValue] == 55);
	XCTAssertTrue([[self.sharedLuaContext[@"aNegativeIntNumber"] toObject] intValue] == -15);

	XCTAssertTrue([[self.sharedLuaContext[@"aFloatNumber"] toObject] floatValue] == 25.33f);
	XCTAssertTrue([[self.sharedLuaContext[@"aNegativeFloatNumber"] toObject] floatValue] == -45.25f);

	XCTAssertTrue([[self.sharedLuaContext[@"aTrueBooleanValue"] toObject] boolValue] == YES);
	XCTAssertTrue([[self.sharedLuaContext[@"aFalseBooleanValue"] toObject] boolValue] == NO);

	XCTAssertTrue([result floatValue] == 55 + 25.33f);

	XCTAssertTrue([self.sharedLuaContext[@"anIntNumber"] toInt32] == 55);
	XCTAssertTrue([self.sharedLuaContext[@"aNegativeIntNumber"] toInt32] == -15);
	XCTAssertTrue([self.sharedLuaContext[@"anIntNumber"] toUInt32] == 55);

	XCTAssertTrue([self.sharedLuaContext[@"aFloatNumber"] toDouble] == 25.33);
	XCTAssertTrue([self.sharedLuaContext[@"aNegativeFloatNumber"] toDouble] == -45.25);

	XCTAssertTrue([self.sharedLuaContext[@"aTrueBooleanValue"] toBool] == YES);
	XCTAssertTrue([self.sharedLuaContext[@"aFalseBooleanValue"] toBool] == NO);

	XCTAssertTrue([[self.sharedLuaContext[@"anIntNumber"] toNumber] intValue] == 55);
	XCTAssertTrue([[self.sharedLuaContext[@"aFloatNumber"] toNumber] floatValue] == 25.33f);
	XCTAssertTrue([[self.sharedLuaContext[@"aStringWithANumber"] toNumber] floatValue] == 1.11e5f);

	XCTAssertTrue([[self.sharedLuaContext[@"anIntNumber"] toString] isEqualToString:@"55"]);
	XCTAssertTrue([[self.sharedLuaContext[@"aFloatNumber"] toString] isEqualToString:@"25.33"]);
	XCTAssertTrue([[self.sharedLuaContext[@"aStringWithANumber"] toString] isEqualToString:@"1.11e5"]);

	NSDateComponents *comps = [[NSDateComponents alloc] init];
	comps.day = 1;
	comps.month = 1;
	comps.year = 2000;

	XCTAssertEqualWithAccuracy([[self.sharedLuaContext[@"year2000InEpochTime"] toDate] timeIntervalSinceReferenceDate],
							   [[[NSCalendar currentCalendar] dateFromComponents:comps] timeIntervalSinceReferenceDate], 60*60*24);

	NSDictionary *table = [self.sharedLuaContext[@"aTable"] toObject];
	XCTAssertNotNil(table, @"Could't retrieve a table");
	XCTAssertTrue([table[@"color"] isEqualToString:@"blue"]);
	XCTAssertTrue([table[@"number"] isEqual:@(2)]);
	XCTAssertTrue([table[@"subtable"] isKindOfClass:[NSDictionary class]]);
	NSDictionary *subTable = table[@"subtable"];
	XCTAssertTrue([subTable isKindOfClass:[NSDictionary class]]);
	XCTAssertTrue([subTable[@"int"] isEqual:@(55)]);
	XCTAssertTrue([subTable[@"float"] isEqual: @(25.33)]);
}

- (void)testCallingMethods {
	MockObject *mockObject = [[MockObject alloc] init];
	mockObject.name = @"old name";

	self.sharedLuaContext[@"mockObject"] = mockObject;

	[self.sharedLuaContext evaluateScript:
	 @"oldName = mockObject:name()"
	 @"mockObject:setName('new name')"
	 @"newName = mockObject:name()"
	 ];

	XCTAssertTrue([[self.sharedLuaContext[@"oldName"] toString] isEqualToString:@"old name"]);
	XCTAssertTrue([[self.sharedLuaContext[@"newName"] toString] isEqualToString:@"new name"]);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

- (LuaVirtualMachine *)sharedLuaVirtualMachine {
	static LuaVirtualMachine *sharedLuaVirtualMachine = nil;
	if (!sharedLuaVirtualMachine) {
		sharedLuaVirtualMachine = [[LuaVirtualMachine alloc] init];
		XCTAssertNotNil(sharedLuaVirtualMachine, @"Couldn't initialize the Lua virtual machine");
	}
	return sharedLuaVirtualMachine;
}

- (LuaContext *)sharedLuaContext {
	static LuaContext *sharedLuaContext = nil;
	if (!sharedLuaContext) {
		sharedLuaContext = [[LuaContext alloc] initWithVirtualMachine:self.sharedLuaVirtualMachine];
		XCTAssertNotNil(sharedLuaContext, @"Couldn't initialize the Lua context");
	}
	return sharedLuaContext;
}

@end
