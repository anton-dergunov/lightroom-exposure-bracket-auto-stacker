-- Menu item: read a folder's photos with exiftool and report the bracketed sequences found, without importing.

local LrTasks = import 'LrTasks'
local LrDialogs = import 'LrDialogs'
local LrProgressScope = import 'LrProgressScope'

local ExifTool = require 'ExifTool'
local Grouping = require 'Grouping'
local Summary = require 'Summary'

LrTasks.startAsyncTask(function()
    local folders = LrDialogs.runOpenPanel({
        title = "Choose a folder to check for bracketed photos (subfolders included)",
        canChooseFiles = false,
        canChooseDirectories = true,
        allowsMultipleSelection = false,
    })
    if not folders or #folders == 0 then return end

    local progress = LrProgressScope({ title = "Reading photo metadata" })
    local frames, message = ExifTool.readFolder(folders[1], true)
    progress:done()
    if not frames then
        LrDialogs.message("Could not read the photos", message, "critical")
        return
    end

    local groups, warnings = Grouping.group(frames)
    local headline, details = Summary.describe(#frames, groups, warnings)
    LrDialogs.message(headline, details, "info")
end, "Preview brackets")
