--[[
Runs the plugin's import menu items against stand-ins for Lightroom (lightroom_fake.lua), with the real exiftool on
the test photos. Checks what ends up in the "catalog": which photos, which stacks, and which photo leads each stack.
Needs the photos (tests/photos/fetch.sh) and the bundled exiftool (tools/fetch-exiftool.sh).
]]

local fake = dofile(TEST_ROOT .. "/tests/lua/lightroom_fake.lua")
local Import = require 'Import'

local photos = TEST_ROOT .. "/tests/photos/test-photos-v1"

local function available()
    local file = io.open(photos .. "/sony-a7c-ii-greenwich/RAW/DSC02108.ARW", "rb")
    local tool = io.open(TEST_ROOT .. "/auto-stacker.lrdevplugin/exiftool/mac/exiftool", "rb")
    if file then file:close() end
    if tool then tool:close() end
    if not (file and tool) then
        print("skipped test_lightroom_import.lua: run tests/photos/fetch.sh and tools/fetch-exiftool.sh to enable it")
    end
    return file and tool
end

local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what, tostring(expected), tostring(actual)), 2)
    end
end

local function name(photo) return photo.path:match("[^/]+/[^/]+$") end

-- "RAW/DSC02108.ARW: DSC02109.ARW DSC02110.ARW" per stack, sorted.
local function stacks()
    local byLeader, order = {}, {}
    for _, photo in ipairs(fake.catalog.photos) do
        if photo.leader then
            table.insert(byLeader[photo.leader], photo.path:match("[^/]+$"))
            eq(photo.position, "below", "stack position")
        else
            byLeader[photo] = {}
            order[#order + 1] = photo
        end
    end
    local lines = {}
    for _, leader in ipairs(order) do
        if #byLeader[leader] > 0 then
            lines[#lines + 1] = name(leader) .. ": " .. table.concat(byLeader[leader], " ")
        end
    end
    table.sort(lines)
    return lines
end

local tests = {}

function tests.import_only_bracketed_photos()
    if not available() then return end
    fake.reset(photos .. "/sony-zv-1-chiltern")
    Import.run(true)
    eq(#fake.catalog.photos, 16, "photos imported (8 bracketed frames, RAW and JPEG)")
    eq(table.concat(stacks(), "\n"), table.concat({
        "JPEG/DSC03152.JPG: DSC03153.JPG",
        "JPEG/DSC03154.JPG: DSC03155.JPG DSC03156.JPG",
        "JPEG/DSC03157.JPG: DSC03158.JPG DSC03159.JPG",
        "RAW/DSC03152.ARW: DSC03153.ARW",
        "RAW/DSC03154.ARW: DSC03155.ARW DSC03156.ARW",
        "RAW/DSC03157.ARW: DSC03158.ARW DSC03159.ARW",
    }, "\n"), "stacks")
    for _, photo in ipairs(fake.catalog.photos) do
        eq(photo.keywords and table.concat(photo.keywords, ","), "Exposure bracket", photo.path .. " keywords")
    end
    eq(fake.otherVerb, nil, "no focus brackets, so no third button")
    local report = fake.messages[#fake.messages]
    eq(report.title, "Imported 16 photos as 6 stacks.", "report")
    assert(report.text:find('keyword "Exposure bracket" or "Focus bracket"', 1, true), report.text)
    assert(report.text:find("The photos are in these folders under Library > Folders: JPEG, RAW. The Library is now showing them.", 1, true), report.text)
    eq(table.concat(fake.sources, " "), photos .. "/sony-zv-1-chiltern/JPEG " .. photos .. "/sony-zv-1-chiltern/RAW", "folders shown")
end

function tests.import_entire_folder_then_again()
    if not available() then return end
    fake.reset(photos .. "/sony-a7c-ii-greenwich")
    Import.run(false)
    eq(#fake.catalog.photos, 14, "every photo imported")
    eq(#stacks(), 4, "stacks")
    eq(fake.messages[#fake.messages].title, "Imported 14 photos as 4 stacks and 2 single photos.", "report")

    -- Running it again finds everything already in the catalog.
    Import.run(false)
    eq(#fake.catalog.photos, 14, "nothing added the second time")
    local last = fake.messages[#fake.messages]
    assert(last.title:find("^Nothing to import"), "second report: " .. last.title)
    assert(last.text:find("4 bracketed sequences left out"), "second report details: " .. last.text)
end

function tests.reject_extra_exposures_after_merging()
    if not available() then return end
    fake.reset(photos .. "/sony-zv-1-chiltern")
    Import.run(true)
    -- EV values as Lightroom reads them (from the fixture), then HDR images for the two complete RAW brackets:
    -- one merged with "Create Stack" (inside the stack), one without (next to it).
    local ev = { ["03152"] = 0, ["03153"] = -1, ["03154"] = 0, ["03155"] = -1, ["03156"] = 1,
                 ["03157"] = 0, ["03158"] = -1, ["03159"] = 1 }
    for _, photo in ipairs(fake.catalog.photos) do
        photo.exposureBias = ev[photo.path:match("DSC(%d+)")]
        photo.shutterSpeed = 1 / 100
    end
    local raw = photos .. "/sony-zv-1-chiltern/RAW/"
    local catalog = import('LrApplication').activeCatalog()
    catalog:addPhoto(raw .. "DSC03154-HDR.dng", fake.catalog.byPath[raw .. "DSC03154.ARW"], "above")
    catalog:addPhoto(raw .. "DSC03157-HDR.dng")

    fake.confirm = "ok"
    dofile(TEST_ROOT .. "/auto-stacker.lrdevplugin/RejectExposures.lua")

    local rejected = {}
    for _, photo in ipairs(fake.catalog.photos) do
        if photo.pickStatus == -1 then rejected[#rejected + 1] = photo.path:match("[^/]+$") end
    end
    table.sort(rejected)
    eq(table.concat(rejected, " "), "DSC03155.ARW DSC03156.ARW DSC03158.ARW DSC03159.ARW", "rejected photos")
    eq(fake.messages[#fake.messages].title, "Rejected 4 photos in 2 stacks.", "report")
end

-- Runs an import on frames from fixtures instead of reading a folder with exiftool.
local function importFixtures(onlyBrackets, choice, ...)
    local json = require 'Json'
    local ExifTool = require 'ExifTool'
    local frames = {}
    for _, id in ipairs({ ... }) do
        local file = assert(io.open(TEST_ROOT .. "/tests/fixtures/sony/" .. id .. ".json", "rb"))
        for _, frame in ipairs(json.decode(file:read("*a")).frames) do
            frame.SourceFile = "/card/" .. frame["System:FileName"]
            frames[#frames + 1] = frame
        end
        file:close()
    end
    local readFolder = ExifTool.readFolder
    ExifTool.readFolder = function() return frames end
    fake.reset("/card")
    fake.confirm = choice
    local ok, err = pcall(Import.run, onlyBrackets)
    ExifTool.readFolder = readFolder
    assert(ok, err)
end

local function keywordCounts()
    local counts = {}
    for _, photo in ipairs(fake.catalog.photos) do
        local keyword = photo.keywords and table.concat(photo.keywords, ",") or "none"
        counts[keyword] = (counts[keyword] or 0) + 1
    end
    return string.format("exposure=%d focus=%d none=%d",
        counts["Exposure bracket"] or 0, counts["Focus bracket"] or 0, counts.none or 0)
end

function tests.focus_brackets_are_tagged_and_can_be_left_out()
    -- 14 focus frames (5 + 9) and, in other-modes, one 2-frame exposure bracket among 27 other photos.
    importFixtures(true, "ok", "sony-a7c-ii-focus-brackets", "sony-a7c-ii-other-modes")
    eq(fake.otherVerb, "Leave Out Focus Brackets", "third button")
    eq(keywordCounts(), "exposure=2 focus=14 none=0", "keywords")
    local report = fake.messages[#fake.messages].text
    assert(report:find('filter by the keyword "Exposure bracket"', 1, true), report)
    assert(report:find("Open as Layers in Photoshop", 1, true), report)

    importFixtures(true, "other", "sony-a7c-ii-focus-brackets", "sony-a7c-ii-other-modes")
    eq(keywordCounts(), "exposure=2 focus=0 none=0", "focus brackets left out")
    assert(fake.messages[#fake.messages].text:find("2 focus brackets left out, as chosen.", 1, true))

    importFixtures(false, "other", "sony-a7c-ii-focus-brackets", "sony-a7c-ii-other-modes")
    eq(fake.otherVerb, "Don't Stack Focus Brackets", "third button when importing everything")
    eq(keywordCounts(), "exposure=2 focus=0 none=41", "focus frames imported as single photos")
    eq(#stacks(), 1, "stacks")
end

function tests.cancel_at_confirmation_imports_nothing()
    if not available() then return end
    fake.reset(photos .. "/sony-a7c-ii-greenwich")
    fake.confirm = "cancel"
    Import.run(true)
    eq(#fake.catalog.photos, 0, "photos imported")
end

return tests
