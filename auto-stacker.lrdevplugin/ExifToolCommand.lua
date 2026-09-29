--[[
Builds the exiftool command line that reads a folder's metadata, and parses its output. Pure Lua 5.1 with no
Lightroom dependency, so it is shared by the plugin (ExifTool.lua) and the tests.

The folder and options go into a temporary argument file rather than onto the command line, so that paths with
spaces or non-ASCII characters reach exiftool intact on both macOS and Windows.
]]

local json = require 'Json'

local ExifToolCommand = {}

-- Photo formats to read; anything else in the folder (sidecars, videos, documents) is skipped.
ExifToolCommand.EXTENSIONS = {
    "3FR", "ARW", "CR2", "CR3", "CRW", "DNG", "ERF", "IIQ", "NEF", "NRW", "ORF", "PEF", "RAF", "RW2", "RWL",
    "SR2", "SRF", "SRW", "X3F", "JPG", "JPEG", "HEIC", "HIF", "TIF", "TIFF",
}

-- Lines of the per-run argument file: output format, which files to read, and the folder.
function ExifToolCommand.runArgs(folder, recursive)
    local lines = { "-j", "-n", "-G1", "-a", "-q", "-q", "-m", "-charset", "filename=utf8" }
    if recursive then lines[#lines + 1] = "-r" end
    for _, ext in ipairs(ExifToolCommand.EXTENSIONS) do
        lines[#lines + 1] = "-ext"
        lines[#lines + 1] = ext
    end
    lines[#lines + 1] = folder
    return table.concat(lines, "\n") .. "\n"
end

local function quote(platform, value)
    if platform == "win" then
        return '"' .. value .. '"'
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

--[[
Command line for one run. `options`:
  platform   "mac" or "win"
  program    list of words that start exiftool, e.g. { "/usr/bin/perl", ".../exiftool" } or { "...\\exiftool.exe" }
  tagsArgs   path of tags.args
  runArgs    path of the file holding ExifToolCommand.runArgs(...)
  output     path for the JSON output
  errors     path for error messages
]]
function ExifToolCommand.commandLine(options)
    local words = {}
    for _, word in ipairs(options.program) do words[#words + 1] = quote(options.platform, word) end
    words[#words + 1] = "-@ " .. quote(options.platform, options.tagsArgs)
    words[#words + 1] = "-@ " .. quote(options.platform, options.runArgs)
    words[#words + 1] = "> " .. quote(options.platform, options.output)
    words[#words + 1] = "2> " .. quote(options.platform, options.errors)
    local line = table.concat(words, " ")
    if options.platform == "win" then
        -- cmd.exe strips the outer pair of quotes when the line starts with a quoted program path.
        line = '"' .. line .. '"'
    end
    return line
end

-- Frames from exiftool's JSON output. No output at all means no photos were found.
function ExifToolCommand.parse(text)
    if text == nil or text:match("^%s*$") then return {} end
    local ok, frames = pcall(json.decode, text)
    if not ok or type(frames) ~= "table" then
        return nil, "Could not read exiftool's output: " .. tostring(frames)
    end
    return frames
end

return ExifToolCommand
