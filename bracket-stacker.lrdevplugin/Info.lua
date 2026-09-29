return {
	LrSdkVersion = 6.0,
	LrSdkMinimumVersion = 6.0,
	LrToolkitIdentifier = 'com.anton_dergunov.bracket_stacker',
	LrPluginName = "Bracket Stacker",
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
		    title = "Reject Extra Exposures After HDR Merge...",
		    file = "RejectExposures.lua",
		    -- Works on photos already in view; the SDK has no menu separators to set it apart.
		    enabledWhen = "photosAvailable",
		},
	},
	VERSION = { major=1, minor=0, revision=0, build="", },
}
