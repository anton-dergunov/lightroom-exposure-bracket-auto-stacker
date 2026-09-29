--[[
Runs exiftool from inside Lightroom and returns the metadata of every photo in a folder.
Must be called from an LrTasks async task.

Uses the copy bundled in the plugin's exiftool/ folder (tools/fetch-exiftool.sh puts it there), and falls back
to an exiftool installed on the system.
]]

local LrTasks = import 'LrTasks'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'

local ExifToolCommand = require 'ExifToolCommand'

local ExifTool = {}

local platform = WIN_ENV and "win" or "mac"

-- The words that start exiftool, or nil and a message when there is none.
function ExifTool.program()
    local bundled = LrPathUtils.child(_PLUGIN.path, "exiftool")
    if platform == "win" then
        local exe = LrPathUtils.child(LrPathUtils.child(bundled, "win"), "exiftool.exe")
        if LrFileUtils.exists(exe) then return { exe } end
    else
        -- Run the script through perl, so it works even if the executable bit was lost when unpacking.
        local script = LrPathUtils.child(LrPathUtils.child(bundled, "mac"), "exiftool")
        if LrFileUtils.exists(script) then return { "/usr/bin/perl", script } end
        for _, path in ipairs({ "/opt/homebrew/bin/exiftool", "/usr/local/bin/exiftool" }) do
            if LrFileUtils.exists(path) then return { "/usr/bin/perl", path } end
        end
    end
    return nil, "exiftool was not found in the plugin folder. Reinstall the plugin, or run tools/fetch-exiftool.sh "
        .. "if you installed it from the source code."
end

local function readText(path)
    if LrFileUtils.exists(path) then return LrFileUtils.readFile(path) end
end

-- Metadata of every photo in `folder` (and its subfolders when `recursive`), as a list of exiftool frames.
-- Returns nil and a message on failure.
function ExifTool.readFolder(folder, recursive)
    local program, message = ExifTool.program()
    if not program then return nil, message end

    local temp = LrPathUtils.getStandardFilePath("temp")
    local base = LrFileUtils.chooseUniqueFileName(LrPathUtils.child(temp, "bracket-stacker"))
    local files = { runArgs = base .. ".args", output = base .. ".json", errors = base .. ".err" }

    local handle = io.open(files.runArgs, "wb")
    if not handle then return nil, "Could not write a temporary file in " .. temp end
    handle:write(ExifToolCommand.runArgs(folder, recursive))
    handle:close()

    local status = LrTasks.execute(ExifToolCommand.commandLine({
        platform = platform,
        program = program,
        tagsArgs = LrPathUtils.child(_PLUGIN.path, "tags.args"),
        runArgs = files.runArgs,
        output = files.output,
        errors = files.errors,
    }))

    local output, errors = readText(files.output), readText(files.errors)
    for _, path in pairs(files) do
        if LrFileUtils.exists(path) then LrFileUtils.delete(path) end
    end

    local frames, parseError = ExifToolCommand.parse(output)
    if not frames then return nil, parseError end
    -- exiftool also exits with an error when a folder has no photos at all, which is not a failure here.
    if #frames == 0 and status ~= 0 and errors and not errors:match("^%s*$") then
        return nil, "exiftool failed: " .. errors
    end
    -- exiftool reports Windows paths with forward slashes; Lightroom's catalog expects backslashes.
    if platform == "win" then
        for _, frame in ipairs(frames) do
            if frame.SourceFile then frame.SourceFile = frame.SourceFile:gsub("/", "\\") end
        end
    end
    return frames
end

return ExifTool
