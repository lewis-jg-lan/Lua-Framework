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
	LuaContext *anotherLuaContext = [[LuaContext alloc] initWithVirtualMachine:self.sharedLuaVirtualMachine];

	XCTAssertNotNil(anotherLuaContext, @"Couldn't initialize another context");

	[anotherLuaContext evaluateScript:@"aGlobalVariableInAnotherContext = 'value in other context'"];

	XCTAssertTrue(anotherLuaContext[@"aGlobalVariable"] == nil && self.sharedLuaContext[@"aGlobalVariableInAnotherContext"] == nil, @"A global variable from one context SHOUD NOT be available to other contexts");
}

- (void)testLoadFramework {
	id obj = [[self.sharedLuaContext evaluateScript:
			   @"objc.import('AVKit')\n"
			   @"local obj = objc.AVPlayerView:alloc():init()\n"
			   @"return obj\n"] toObject];

	XCTAssertTrue([obj class] == NSClassFromString(@"AVPlayerView"), @"Couldn't create an object from a loaded framework");
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

						 @"aTable = {color='blue', number=2}\n"

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

		[self.sharedLuaContext evaluateScript:
		 @"if not aGlobalVariable then\n"
		 @"  local aLocalVariable = 'the value'\n"
		 @"  aGlobalVariable = aLocalVariable\n"
		 @"end\n"
		 ];

		XCTAssertNil(self.sharedLuaContext[@"aLocalVariable"], @"A local variable SHOULD NOT be available from the global context");

		XCTAssertTrue([[self.sharedLuaContext[@"aGlobalVariable"] toObject] isEqualToString:@"the value"], @"A global variable SHOULD be available from the global context");
	}
	return sharedLuaContext;
}

@end
