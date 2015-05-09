//
//  AppDelegate.m
//  HelloLua
//
//  Created by Rhody Lugo on 5/5/15.
//
//

#import "AppDelegate.h"
#import <Lua/LuaVirtualMachine.h>

@interface AppDelegate ()
@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextField *textField;
@property (strong) LuaContext *context;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	/* Init Lua virtual machine */
	LuaVirtualMachine *vm = [[LuaVirtualMachine alloc] init];

	/* Get a context to run the sript */
	self.context = [[LuaContext alloc] initWithVirtualMachine:vm];

	/* Pass the application delegate to the Lua context */
	self.context[@"AppDelegate"] = self;

	/* Completition handler for the dialog sheet */
	self.context[@"handler"] = ^(NSModalResponse response) {
		printf("Dialog sheet dismissed\n");
	};

	/* Run the script file 'test.lua' */
	[self.context evaluateScriptNamed:@"test"];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	/* Run a script from a string */
	[self.context evaluateScript:@"print('Bye!')"];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}

- (IBAction)buttonClicked:(id)sender {
	/* Call a function from the lua context passing some parameters */
	[self.context[@"button_clicked"] callWithArguments:@[@"The parameter"]];
}

@end
