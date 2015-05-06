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
