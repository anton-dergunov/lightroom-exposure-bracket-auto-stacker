--[[
Compares the plugin's grouping with time-based stacking on whole shoots from tests/fixtures, and prints the results
as Markdown (docs/benchmark.md is this output).

  lua tools/benchmark.lua > docs/benchmark.md

Time-based stacking works like Lightroom's Auto-Stack by capture time: within a folder, photos sorted by capture time
go into one stack as long as each is taken no more than the chosen gap after the previous one. "Seconds" compares
whole-second capture times, like the classic Auto-Stack by Capture Time; "milliseconds" uses sub-second times, like
the Auto Stack added in Lightroom Classic 15 and Lightroom 9 (October 2025).

The correct groups are each fixture's "groups": the sequences the camera itself recorded (the owner's shoots were
checked against what was shot).
]]

local root = (arg[0]:match("^(.*)[/\\]tools[/\\]benchmark%.lua$") or ".")
package.path = root .. "/bracket-stacker.lrdevplugin/?.lua;" .. package.path

local json = require 'Json'
local Grouping = require 'Grouping'

-- Whole shoots: every photo of a folder or memory card, in the order the camera wrote them.
local DATASETS = {
    { name = "Greenwich Park (A7C II, daylight, handheld)", fixtures = { "sony/sony-a7c-ii-greenwich-shoot" } },
    { name = "Chiltern Open Air Museum (ZV-1)", fixtures = { "sony/sony-zv-1-chiltern-shoot" } },
    { name = "A7C II test card", fixtures = {
        "sony/sony-a7c-ii-exposure-modes", "sony/sony-a7c-ii-back-to-back", "sony/sony-a7c-ii-focus-brackets",
        "sony/sony-a7c-ii-focus-long", "sony/sony-a7c-ii-focus-brackets-2", "sony/sony-a7c-ii-other-modes" } },
    { name = "RX100 VII test card (RAW only)", fixtures = {
        "sony/sony-rx100-vii-exposure-brackets", "sony/sony-rx100-vii-other-modes" }, extension = "ARW" },
    { name = "ZV-E10 test card (RAW only)", fixtures = {
        "sony/sony-zv-e10-exposure-brackets", "sony/sony-zv-e10-other-modes" }, extension = "ARW" },
    { name = "Canon EOS 70D, three brackets 11-15 s apart", fixtures = { "canon/canon-eos-70d-three-brackets" } },
    { name = "Canon EOS-1D Mark IV at night, long exposures", fixtures = { "canon/canon-eos-1d-mark-iv-zurich-pair" } },
}

local GAPS = { 0, 0.25, 0.5, 1, 2, 5, 10, 30, 60 }

local function readFixture(id)
    local file = assert(io.open(root .. "/tests/fixtures/" .. id .. ".json", "rb"))
    local fixture = json.decode(file:read("*a"))
    file:close()
    return fixture
end

local function name(frame) return frame.SourceFile or frame["System:FileName"] end

local function folderOf(frame)
    local n = name(frame)
    return (n:match("^(.*)/") or "") .. "|" .. (n:match("%.(%w+)$") or ""):upper()
end

-- Capture time in seconds of the day, with or without its fraction.
local function captureTime(frame, wholeSeconds)
    local text = frame["Composite:SubSecDateTimeOriginal"] or frame["ExifIFD:DateTimeOriginal"] or ""
    local d, h, m, s, frac = text:match("^%d+:%d+:(%d+) (%d+):(%d+):(%d+)(%.?%d*)")
    if not d then return 0 end
    local t = ((tonumber(d) * 24 + tonumber(h)) * 60 + tonumber(m)) * 60 + tonumber(s)
    if not wholeSeconds and #frac > 1 then t = t + tonumber("0" .. frac) end
    return t
end

-- Lightroom-style stacks: consecutive photos in a folder no more than `gap` seconds apart.
local function timeStacks(frames, gap, wholeSeconds)
    local byFolder, order = {}, {}
    for _, frame in ipairs(frames) do
        local key = folderOf(frame)
        if not byFolder[key] then byFolder[key] = {}; order[#order + 1] = key end
        table.insert(byFolder[key], frame)
    end
    local stacks = {}
    for _, key in ipairs(order) do
        local list = byFolder[key]
        table.sort(list, function(a, b)
            local ta, tb = captureTime(a, false), captureTime(b, false)
            if ta ~= tb then return ta < tb end
            return name(a) < name(b)
        end)
        local current = { list[1] }
        for i = 2, #list do
            if captureTime(list[i], wholeSeconds) - captureTime(list[i - 1], wholeSeconds) <= gap + 1e-9 then
                table.insert(current, list[i])
            else
                stacks[#stacks + 1] = current
                current = { list[i] }
            end
        end
        stacks[#stacks + 1] = current
    end
    local result = {}
    for _, stack in ipairs(stacks) do
        if #stack >= 2 then result[#result + 1] = stack end
    end
    return result
end

local function setKey(names)
    table.sort(names)
    return table.concat(names, "\n")
end

--[[
Scores predicted stacks (lists of frames) against the correct groups (lists of names):
  exact    correct groups that came out as exactly one stack
  wrong    stacks that are not exactly a correct group: brackets merged together, split apart, or singles stacked
]]
local function score(truth, stacks)
    local wanted = {}
    for _, group in ipairs(truth) do
        local copy = {}
        for i, n in ipairs(group) do copy[i] = n end
        wanted[setKey(copy)] = true
    end
    local exact, wrong = 0, 0
    for _, stack in ipairs(stacks) do
        local names = {}
        for i, frame in ipairs(stack) do names[i] = name(frame) end
        if wanted[setKey(names)] then exact = exact + 1 else wrong = wrong + 1 end
    end
    return exact, wrong
end

local function plural(count, word) return count .. " " .. word .. (count == 1 and "" or "s") end

local out = {}
local function line(text) out[#out + 1] = text or "" end

line("# Benchmark: finding bracketed sequences")
line()
line("How well time-based stacking finds bracketed sequences, compared with the plugin, on whole shoots. Generated by")
line("`lua tools/benchmark.lua` from the fixtures in `tests/fixtures`; do not edit by hand.")
line()
line("**Time-based stacking** works like Lightroom's Auto-Stack by capture time: within a folder, photos sorted by")
line("capture time share a stack while each is taken at most *gap* seconds after the previous one. *Seconds* compares")
line("whole-second capture times, as the classic Auto-Stack by Capture Time does; *milliseconds* uses sub-second times,")
line("as the Auto Stack added in Lightroom Classic 15 and Lightroom 9 (October 2025) does. Its other mode, grouping by")
line("visual similarity, is an AI model that only Lightroom can run, so it is not included.")
line()
line("**Right** is the number of bracketed sequences that came out as exactly one stack. **Wrong stacks** are stacks")
line("that are not exactly one sequence: sequences merged together or cut apart, or single shots stacked. The correct")
line("sequences are the ones the camera recorded, which are checked against what was shot; the plugin reads the same")
line("record, which is why it can match it.")

-- Every method: the plugin, then time-based stacking for each gap, in whole seconds and in milliseconds.
local METHODS = { { label = "**This plugin**", plugin = true } }
for _, wholeSeconds in ipairs({ true, false }) do
    for _, gap in ipairs(GAPS) do
        if not (wholeSeconds and gap ~= math.floor(gap)) then
            METHODS[#METHODS + 1] = {
                label = string.format("Time, %s, gap %s s", wholeSeconds and "seconds" or "milliseconds", tostring(gap)),
                gap = gap, wholeSeconds = wholeSeconds,
            }
        end
    end
end

local results = {}
for d, dataset in ipairs(DATASETS) do
    local frames, truth = {}, {}
    for _, id in ipairs(dataset.fixtures) do
        local fixture = readFixture(id)
        local keep = {}
        for _, frame in ipairs(fixture.frames) do
            if not dataset.extension or name(frame):upper():match("%." .. dataset.extension .. "$") then
                frames[#frames + 1] = frame
                keep[name(frame)] = true
            end
        end
        for _, group in ipairs(fixture.groups) do
            if keep[group[1]] then truth[#truth + 1] = group end
        end
    end
    results[d] = { frames = #frames, sequences = #truth, scores = {} }
    for m, method in ipairs(METHODS) do
        local stacks
        if method.plugin then
            stacks = {}
            for i, group in ipairs(Grouping.group(frames)) do stacks[i] = group.frames end
        else
            stacks = timeStacks(frames, method.gap, method.wholeSeconds)
        end
        local exact, wrong = score(truth, stacks)
        results[d].scores[m] = { exact = exact, wrong = wrong }
    end
end

-- Better = more sequences right, then fewer wrong stacks.
local function better(a, b) return a.exact > b.exact or (a.exact == b.exact and a.wrong < b.wrong) end

line()
line("## Summary")
line()
line("Time-based stacking needs a different gap for every shoot: brackets 0.1 s apart in daylight need a gap under")
line("half a second, while long exposures at night need several seconds, and single shots taken in quick succession get")
line("stacked with any gap long enough for either. The best gap for each shoot, chosen with hindsight:")
line()
line("| Shoot | Sequences | This plugin | Best time-based (gap) |")
line("|---|---|---|---|")
for d, dataset in ipairs(DATASETS) do
    local r, best = results[d], nil
    for m = 2, #METHODS do
        if not best or better(r.scores[m], r.scores[best]) then best = m end
    end
    local b = r.scores[best]
    line(string.format("| %s | %d | %d right, %d wrong | %d right, %d wrong (%s) |", dataset.name, r.sequences,
        r.scores[1].exact, r.scores[1].wrong, b.exact, b.wrong, METHODS[best].label:gsub("^Time, ", "")))
end
line()
line("In practice one setting is used for everything. The same gap for all the shoots above, added up:")
line()
line("| Method | Right | Wrong stacks |")
line("|---|---|---|")
local totalSequences = 0
for d = 1, #DATASETS do totalSequences = totalSequences + results[d].sequences end
for m, method in ipairs(METHODS) do
    local exact, wrong = 0, 0
    for d = 1, #DATASETS do
        exact = exact + results[d].scores[m].exact
        wrong = wrong + results[d].scores[m].wrong
    end
    local row = string.format("| %s | %d of %d | %d |", method.label, exact, totalSequences, wrong)
    if method.plugin then row = row:gsub("| (%d+ of %d+) | (%d+) |$", "| **%1** | **%2** |") end
    line(row)
end

for d, dataset in ipairs(DATASETS) do
    local r = results[d]
    line()
    line("## " .. dataset.name)
    line()
    line(string.format("%s, %s.", plural(r.frames, "photo"), plural(r.sequences, "bracketed sequence")))
    line()
    line("| Method | Right | Wrong stacks |")
    line("|---|---|---|")
    for m, method in ipairs(METHODS) do
        local s = r.scores[m]
        local row = string.format("| %s | %d of %d | %d |", method.label, s.exact, r.sequences, s.wrong)
        if method.plugin then row = row:gsub("| (%d+ of %d+) | (%d+) |$", "| **%1** | **%2** |") end
        line(row)
    end
end

io.write(table.concat(out, "\n"), "\n")
