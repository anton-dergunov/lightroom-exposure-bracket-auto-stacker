--[[
Test runner for the grouping logic, using plain Lua with no other dependencies.

  lua tests/lua/run.lua tests/fixtures/*/*.json tests/lua/test_*.lua

A .json argument is a fixture: grouping its frames must give its "expected" groups, or its "groups" when there is
no "expected". A .lua argument is a test file returning a table of named test functions.
]]

local root = (arg[0]:match("^(.*)[/\\]tests[/\\]lua[/\\]run%.lua$") or ".")
package.path = root .. "/auto-stacker.lrdevplugin/?.lua;" .. package.path
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

local function names(frames)
    local list = {}
    for i, frame in ipairs(frames) do list[i] = frame["System:FileName"] end
    return list
end

-- Groups as lines of comma-separated file names, sorted so that group order does not matter.
local function describe(groups)
    local lines = {}
    for i, group in ipairs(groups) do lines[i] = table.concat(group, ", ") end
    table.sort(lines)
    return table.concat(lines, "\n")
end

local function checkFixture(path)
    local fixture = json.decode(readFile(path))
    local groups = Grouping.group(fixture.frames)
    local actual = {}
    for i, group in ipairs(groups) do actual[i] = names(group.frames) end
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
