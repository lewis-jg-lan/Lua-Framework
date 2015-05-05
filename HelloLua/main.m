//
//  main.m
//  HelloLua
//
//  Created by Rhody Lugo on 5/5/15.
//
//

#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char * argv[]) {

	@autoreleasepool {
		[NSApplication sharedApplication];
		/* Load the main UI if not running the tests */
		if(NSClassFromString(@"XCTestCase") == nil) {
			[[NSBundle mainBundle] loadNibNamed:@"MainMenu" owner:NSApp topLevelObjects:nil];
		}
		[NSApp run];
	};

	return 0;
}
