objc.import('AppKit')

local alert = objc.NSAlert:alloc():init()
alert:setMessageText('Hello Lua!')
alert:beginSheetModalForWindow_completionHandler(AppDelegate:window(), handler);

function button_clicked(param)
	print('Some parameter: '..param..' - Message in text field: '..AppDelegate:textField():stringValue())
end