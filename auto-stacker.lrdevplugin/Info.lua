return {
	LrSdkVersion = 6.0,
	LrSdkMinimumVersion = 6.0,
	LrToolkitIdentifier = 'com.anton_dergunov.auto_stacker',
	LrPluginName = "Auto Stacker",
	LrLibraryMenuItems = {
		{
		    title = "Import Only Bracketed Photos, as Stacks...",
		    file = "ImportBracketed.lua",
		},
		{
		    title = "Import Entire Folder, Brackets as Stacks...",
		    file = "ImportFolder.lua",
		},
		{
		    title = "Preview Brackets in Folder...",
		    file = "PreviewBrackets.lua",
		},
		{
		    title = "Import from Groups File (Python Workflow)...",
		    file = "AutoStack.lua",
		},
	},
	VERSION = { major=0, minor=0, revision=1, build="", },
}
