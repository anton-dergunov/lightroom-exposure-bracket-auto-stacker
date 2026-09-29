--[[
Test runner for the grouping logic, using plain Lua with no other dependencies.

  lua tests/lua/run.lua tests/fixtures/*/*.json tests/lua/test_*.lua

A .json argument is a fixture. It must follow the format in tests/fixtures/README.md and keep only tags listed in
tags.args (which keeps serial numbers, names, GPS and paths out), and grouping its frames must give its "expected"
groups, or its "groups" when there is no "expected". A .lua argument is a test file returning a table of named test
functions.
]]

local root = (arg[0]:match("^(.*)[/\\]tests[/\\]lua[/\\]run%.lua$") or ".")
package.path = root .. "/bracket-stacker.lrdevplugin/?.lua;" .. package.path
-- Repository root, for test files that read other files from the repository.
TEST_ROOT = root

local json = require 'Json'
local Grouping = require 'Grouping'

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

-- A frame's name in "groups": its relative path when the fixture spans folders, else its file name.
local function frameName(frame)
    return frame.SourceFile or frame["System:FileName"]
end

local function names(frames)
    local list = {}
    for i, frame in ipairs(frames) do list[i] = frameName(frame) end
    return list
end

-- Groups as lines of comma-separated file names, sorted so that group order does not matter.
local function describe(groups)
    local lines = {}
    for i, group in ipairs(groups) do lines[i] = table.concat(group, ", ") end
    table.sort(lines)
    return table.concat(lines, "\n")
end

local allowedTags = {}
for line in readFile(root .. "/bracket-stacker.lrdevplugin/tags.args"):gmatch("[^\r\n]+") do
    local tag = line:match("^%s*%-(%S+)")
    if tag then allowedTags[tag] = true end
end

local function check(condition, message)
    if not condition then error(message, 0) end
end

-- The fixture format described in tests/fixtures/README.md.
local function checkFormat(path, fixture)
    local stem = path:match("([^/\\]+)%.json$")
    check(fixture.id == stem, "id must match the file name: " .. tostring(fixture.id))
    check(fixture.kind == "exposure" or fixture.kind == "focus" or fixture.kind == "none", "kind: " .. tostring(fixture.kind))
    check(type(fixture.complete) == "boolean", "complete must be true or false")
    check(fixture.derived == nil or type(fixture.derived) == "string", "derived must be text")
    local source = fixture.source or {}
    for _, key in ipairs({ "url", "license", "author" }) do
        check(type(source[key]) == "string" and source[key] ~= "", "source." .. key .. " is missing")
    end

    local present = {}
    for _, frame in ipairs(fixture.frames) do
        local name = frameName(frame)
        check(frame["System:FileName"] and not present[name], "missing or duplicate file name: " .. tostring(name))
        present[name] = true
        -- Paths are kept only relative to the photos' own folder, so they cannot reveal anything about the owner.
        check(not frame.SourceFile or not (frame.SourceFile:match("^[/\\]") or frame.SourceFile:match("^%a:")),
            name .. ": SourceFile must be a relative path")
        for key in pairs(frame) do
            if key ~= "SourceFile" then
                local group, tag = key:match("^([^:]+):.-([^:]+)$")
                check(group and allowedTags[tag], name .. ": " .. key .. " is not in tags.args")
            end
        end
    end
    for name in pairs(source.files or {}) do
        check(present[name], "source.files lists a frame that is not in frames: " .. name)
    end

    for _, field in ipairs({ "groups", "expected" }) do
        local seen = {}
        for _, group in ipairs(fixture[field] or {}) do
            check(#group >= 2, field .. " has a group with fewer than 2 frames")
            for _, name in ipairs(group) do
                check(present[name], field .. " lists a frame that is not in frames: " .. name)
                check(not seen[name], field .. " lists a frame twice: " .. name)
                seen[name] = true
            end
        end
    end
    check(fixture.kind ~= "none" or #fixture.groups == 0, "kind none must have no groups")
end

local function checkFixture(path)
    local fixture = json.decode(readFile(path))
    checkFormat(path, fixture)
    local groups = Grouping.group(fixture.frames)
    local actual = {}
    for i, group in ipairs(groups) do
        actual[i] = names(group.frames)
        check(group.kind == fixture.kind, string.format("group starting at %s is a %s bracket, the fixture's kind is %s",
            actual[i][1], group.kind, fixture.kind))
    end
    local want, got = describe(fixture.expected or fixture.groups), describe(actual)
    if want ~= got then
        error(string.format("expected groups:\n%s\ngot:\n%s", want == "" and "(none)" or want, got == "" and "(none)" or got), 0)
    end
end

local passed, failed = 0, {}

local function run(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed[#failed + 1] = name .. "\n" .. tostring(err)
    end
end

for _, path in ipairs(arg) do
    if path:match("%.json$") then
        run(path, function() checkFixture(path) end)
    elseif path:match("%.lua$") then
        local tests = dofile(path)
        local list = {}
        for name in pairs(tests) do list[#list + 1] = name end
        table.sort(list)
        for _, name in ipairs(list) do run(path .. ": " .. name, tests[name]) end
    end
end

for _, message in ipairs(failed) do print("FAIL " .. message .. "\n") end
print(string.format("%d passed, %d failed", passed, #failed))
os.exit(#failed == 0 and 0 or 1)
