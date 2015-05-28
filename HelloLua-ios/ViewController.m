//
//  ViewController.m
//  HelloLua-ios
//
//  Created by Rhody Lugo on 5/20/15.
//
//

#import "ViewController.h"
#import <Lua/LuaVirtualMachine.h>


@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextView *editorView;
@property (weak, nonatomic) IBOutlet UILabel *resultLabel;
@property (strong) LuaContext *luaContext;
@end

@implementation ViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	self.luaContext = [LuaContext new];
	self.luaContext[@"UIAlertView"] = [UIAlertView class];
}

- (IBAction)runScript:(id)sender {
	id result = [self.luaContext evaluateScript:self.editorView.text];

	if ( result )
		[self.resultLabel setText:[NSString stringWithFormat:@"Succeeded with return value: %@", result]];
	else
		[self.resultLabel setText:@"Succeeded with no return value."];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

@end
