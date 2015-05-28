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
@property (unsafe_unretained) IBOutlet NSTextView *editorView;
@property (weak) IBOutlet NSTextField *resultLabel;
@property (strong) LuaContext *luaContext;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[self.editorView setAutomaticDashSubstitutionEnabled:NO];
	self.luaContext = [LuaContext new];
	self.luaContext[@"NSAlert"] = [NSAlert class];
}

- (IBAction)runScript:(id)sender {
	id result = [self.luaContext evaluateScript:self.editorView.string];

	if (result)
		[self.resultLabel setStringValue:[NSString stringWithFormat:@"Succeeded with return value: %@", result]];
	else
		[self.resultLabel setStringValue:@"Succeeded with no return value."];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
	return YES;
}

@end
