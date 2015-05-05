objc.import('AppKit')

local alert = objc.NSAlert:alloc():init()
alert:setMessageText('Hello Lua!')
alert:runModal()

function button_clicked(param)
	print('Some parameter: '..param..' - Message in text field: '..AppDelegate:textField():stringValue())
end