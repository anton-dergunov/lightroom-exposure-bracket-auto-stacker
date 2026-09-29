--[[
End-to-end check on the real test photos: runs the plugin's own exiftool command on each folder of the photo
pack and compares the frames and groups with the fixture of the same name. Needs the photos (tests/photos/fetch.sh)
and the bundled exiftool (tools/fetch-exiftool.sh); without them the check reports itself as skipped.
]]

local json = require 'Json'
local ExifToolCommand = require 'ExifToolCommand'
local Grouping = require 'Grouping'

local root = TEST_ROOT
local photos = root .. "/tests/photos/test-photos-v1"
local exiftool = root .. "/bracket-stacker.lrdevplugin/exiftool/mac/exiftool"

local function exists(path)
    local file = io.open(path, "rb")
    if file then file:close() end
    return file ~= nil
end

local function readFile(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local text = file:read("*a")
    file:close()
    return text
end

local function readFolder(folder)
    local base = os.tmpname()
    local files = { runArgs = base .. ".args", output = base .. ".json", errors = base .. ".err" }
    local handle = assert(io.open(files.runArgs, "wb"))
    handle:write(ExifToolCommand.runArgs(folder, true))
    handle:close()
    os.execute(ExifToolCommand.commandLine({
        platform = "mac",
        program = { "perl", exiftool },
        tagsArgs = root .. "/bracket-stacker.lrdevplugin/tags.args",
        runArgs = files.runArgs, output = files.output, errors = files.errors,
    }))
    local frames = assert(ExifToolCommand.parse(readFile(files.output)))
    os.remove(base)
    for _, path in pairs(files) do os.remove(path) end
    return frames
end

local function canonical(value)
    if type(value) ~= "table" then return tostring(value) end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = key .. "=" .. canonical(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function sortedLines(list)
    table.sort(list)
    return table.concat(list, "\n")
end

local function check(id)
    local fixture = json.decode(assert(readFile(root .. "/tests/fixtures/sony/" .. id .. ".json")))
    local frames = readFolder(photos .. "/" .. id)

    local want, got = {}, {}
    for i, frame in ipairs(fixture.frames) do want[i] = canonical(frame) end
    for i, frame in ipairs(frames) do
        local copy = {}
        for key, value in pairs(frame) do if key ~= "SourceFile" then copy[key] = value end end
        got[i] = canonical(copy)
    end
    if sortedLines(want) ~= sortedLines(got) then
        error(id .. ": exiftool output differs from the fixture's frames", 0)
    end

    local groups = Grouping.group(frames)
    local wantGroups, gotGroups = {}, {}
    for i, group in ipairs(fixture.expected or fixture.groups) do wantGroups[i] = table.concat(group, ",") end
    for i, group in ipairs(groups) do
        local names = {}
        for j, frame in ipairs(group.frames) do names[j] = frame["System:FileName"] end
        gotGroups[i] = table.concat(names, ",")
    end
    if sortedLines(wantGroups) ~= sortedLines(gotGroups) then
        error(id .. ": groups differ:\n" .. sortedLines(gotGroups), 0)
    end
end

local tests = {}

function tests.photo_pack_matches_fixtures()
    if not (exists(photos .. "/sony-a7c-ii-greenwich/RAW/DSC02108.ARW") and exists(exiftool)) then
        print("skipped test_photos.lua: run tests/photos/fetch.sh and tools/fetch-exiftool.sh to enable it")
        return
    end
    check("sony-a7c-ii-greenwich")
    check("sony-zv-1-chiltern")
end

return tests
