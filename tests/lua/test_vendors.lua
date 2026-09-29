-- Synthetic cases for rules that no complete real sequence in tests/fixtures covers yet.
-- Tag values follow exiftool's documentation for each brand.

local Grouping = require 'Grouping'

local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what, tostring(expected), tostring(actual)), 2)
    end
end

-- Frames one tenth of a second apart, named IMG_0001.ARW and so on, with `tags` merged into each.
local function frames(make, perFrame, extra)
    local list = {}
    for i, tags in ipairs(perFrame) do
        local frame = {
            ["System:FileName"] = string.format("IMG_%04d.ARW", i),
            ["IFD0:Make"] = make,
            ["IFD0:Model"] = "Test",
            ["Composite:SubSecDateTimeOriginal"] = string.format("2020:01:01 12:00:%05.2f", i / 10),
        }
        for key, value in pairs(extra or {}) do frame[key] = value end
        for key, value in pairs(tags) do frame[key] = value end
        list[i] = frame
    end
    return list
end

local function sizes(groups)
    local list = {}
    for i, group in ipairs(groups) do list[i] = #group.frames end
    return table.concat(list, ",")
end

local tests = {}

function tests.fujifilm_bracket_is_grouped_but_not_validated()
    local groups = Grouping.group(frames("FUJIFILM", {
        { ["FujiFilm:SequenceNumber"] = 1 }, { ["FujiFilm:SequenceNumber"] = 2 }, { ["FujiFilm:SequenceNumber"] = 3 },
    }, { ["FujiFilm:AutoBracketing"] = 1 }))
    eq(sizes(groups), "3", "groups")
    eq(groups[1].validated, false, "validated")
end

function tests.sony_white_balance_and_dro_brackets_are_not_grouped()
    for _, mode in ipairs({ 6, 8 }) do
        local groups = Grouping.group(frames("SONY", {
            { ["Sony:SequenceImageNumber"] = 1 }, { ["Sony:SequenceImageNumber"] = 2 }, { ["Sony:SequenceImageNumber"] = 3 },
        }, { ["Sony:ReleaseMode"] = mode, ["Sony:SequenceLength"] = 3 }))
        eq(sizes(groups), "", "groups for ReleaseMode " .. mode)
    end
end

function tests.sony_interrupted_single_bracket_then_complete_bracket()
    -- Single Bracket mode: one SequenceLength copy says 1, the other the real length. The user stopped after two.
    local groups, warnings = Grouping.group(frames("SONY", {
        { ["Sony:SequenceImageNumber"] = 1, ["Sony:SequenceLength"] = 1, ["Sony:Copy1:SequenceLength"] = 3 },
        { ["Sony:SequenceImageNumber"] = 2, ["Sony:SequenceLength"] = 1, ["Sony:Copy1:SequenceLength"] = 3 },
        { ["Sony:SequenceImageNumber"] = 1, ["Sony:SequenceLength"] = 3, ["Sony:Copy1:SequenceLength"] = 3 },
        { ["Sony:SequenceImageNumber"] = 2, ["Sony:SequenceLength"] = 3, ["Sony:Copy1:SequenceLength"] = 3 },
        { ["Sony:SequenceImageNumber"] = 3, ["Sony:SequenceLength"] = 3, ["Sony:Copy1:SequenceLength"] = 3 },
    }, { ["Sony:ReleaseMode"] = 5, ["Sony:ReleaseMode2"] = 23, ["ExifIFD:ExposureMode"] = 2 }))
    eq(sizes(groups), "2,3", "groups")
    eq(groups[1].complete, false, "stopped bracket is incomplete")
    eq(groups[2].complete, true, "second bracket is complete")
    eq(#warnings, 1, "warnings")
end

function tests.sony_focus_bracket_length_and_kind()
    local list = {}
    for i = 1, 4 do list[i] = { ["Sony:SequenceImageNumber"] = i, ["Sony:SequenceLength"] = 1, ["Sony:Copy1:SequenceLength"] = 4 } end
    local groups = Grouping.group(frames("SONY", list,
        { ["Sony:ReleaseMode"] = 5, ["Sony:ReleaseMode2"] = 23, ["ExifIFD:ExposureMode"] = 0 }))
    eq(sizes(groups), "4", "groups")
    eq(groups[1].kind, "focus", "kind")
    eq(groups[1].complete, true, "complete")
end

function tests.tagged_sequence_split_by_long_pause()
    local list = frames("SONY", {
        { ["Sony:SequenceImageNumber"] = 1 }, { ["Sony:SequenceImageNumber"] = 2 }, { ["Sony:SequenceImageNumber"] = 3 },
    }, { ["Sony:ReleaseMode"] = 5 })
    list[3]["Composite:SubSecDateTimeOriginal"] = "2020:01:01 12:05:00.00"
    eq(sizes(Grouping.group(list)), "2", "groups")
end

function tests.canon_incomplete_bracket_is_flagged()
    local groups, warnings = Grouping.group(frames("Canon", {
        { ["Canon:AEBBracketValue"] = 0 }, { ["Canon:AEBBracketValue"] = -1 }, { ["Canon:AEBBracketValue"] = 1 },
    }, { ["Canon:BracketMode"] = 1, ["CanonCustom:AEBShotCount"] = "5 0" }))
    eq(sizes(groups), "3", "groups")
    eq(groups[1].complete, false, "completeness")
    eq(#warnings, 1, "warnings")
end

function tests.canon_older_body_flags_only_auto_exposure_bracketing()
    -- The 400D leaves BracketMode at 0 during AEB and sets AutoExposureBracketing instead.
    eq(sizes(Grouping.group(frames("Canon", {
        { ["Canon:AEBBracketValue"] = 0 }, { ["Canon:AEBBracketValue"] = -1 }, { ["Canon:AEBBracketValue"] = 1 },
    }, { ["Canon:BracketMode"] = 0, ["Canon:AutoExposureBracketing"] = -1 }))), "3", "groups")
end

function tests.continuous_brackets_split_by_repeated_offset()
    -- Holding the shutter in continuous AEB fires bracket after bracket with no pause.
    eq(sizes(Grouping.group(frames("NIKON CORPORATION", {
        { ["Nikon:ExposureBracketValue"] = 0 }, { ["Nikon:ExposureBracketValue"] = -1 }, { ["Nikon:ExposureBracketValue"] = 1 },
        { ["Nikon:ExposureBracketValue"] = 0 }, { ["Nikon:ExposureBracketValue"] = -1 }, { ["Nikon:ExposureBracketValue"] = 1 },
    }, { ["Nikon:ShootingMode"] = 17 }))), "3,3", "groups")
end

function tests.brackets_with_new_offsets_split_by_pause()
    -- The second bracket uses a larger step, so no offset repeats until its second frame.
    local list = frames("NIKON CORPORATION", {
        { ["Nikon:ExposureBracketValue"] = 0 }, { ["Nikon:ExposureBracketValue"] = -1 }, { ["Nikon:ExposureBracketValue"] = 1 },
        { ["Nikon:ExposureBracketValue"] = -2 }, { ["Nikon:ExposureBracketValue"] = 0 }, { ["Nikon:ExposureBracketValue"] = 2 },
    }, { ["Nikon:ShootingMode"] = 17 })
    for i = 4, 6 do list[i]["Composite:SubSecDateTimeOriginal"] = string.format("2020:01:01 12:00:%05.2f", 10 + i / 10) end
    eq(sizes(Grouping.group(list)), "3,3", "groups")
end

function tests.sub_seconds_order_frames_when_file_numbers_roll_over()
    local list = frames("SONY", {
        { ["Sony:SequenceImageNumber"] = 1 }, { ["Sony:SequenceImageNumber"] = 2 }, { ["Sony:SequenceImageNumber"] = 3 },
    }, { ["Sony:ReleaseMode"] = 5 })
    list[1]["System:FileName"], list[2]["System:FileName"], list[3]["System:FileName"] = "DSC09998.ARW", "DSC09999.ARW", "DSC00001.ARW"
    for i = 1, 3 do list[i]["Composite:SubSecDateTimeOriginal"] = string.format("2020:01:01 12:00:00.%d", i) end
    eq(sizes(Grouping.group(list)), "3", "groups")
end

function tests.nikon_continuous_without_bracketing_is_not_grouped()
    eq(sizes(Grouping.group(frames("NIKON CORPORATION", {
        { ["Nikon:ExposureBracketValue"] = 0 }, { ["Nikon:ExposureBracketValue"] = 0 },
    }, { ["Nikon:ShootingMode"] = 1 }))), "", "groups")
end

function tests.olympus_exposure_bracket_and_camera_focus_stack()
    local list = frames("OM Digital Solutions", {
        { ["Olympus:DriveMode"] = "5 1 1 0 4" }, { ["Olympus:DriveMode"] = "5 2 1 0 4" }, { ["Olympus:DriveMode"] = "5 3 1 0 4" },
        { ["Olympus:DriveMode"] = "5 1 64 0 4" }, { ["Olympus:DriveMode"] = "5 2 64 0 4" },
        { ["Olympus:DriveMode"] = "0 0 0 0 4", ["Olympus:StackedImage"] = "9 2" },
    })
    local groups = Grouping.group(list)
    eq(sizes(groups), "3,2", "groups")
    eq(groups[1].kind, "exposure", "first kind")
    eq(groups[2].kind, "focus", "second kind")
end

function tests.panasonic_focus_bracket()
    local groups = Grouping.group(frames("Panasonic", {
        { ["Panasonic:SequenceNumber"] = 1 }, { ["Panasonic:SequenceNumber"] = 2 },
    }, { ["Panasonic:BurstMode"] = 3 }))
    eq(sizes(groups), "2", "groups")
    eq(groups[1].kind, "focus", "kind")
end

function tests.same_names_in_different_folders_stay_apart()
    local list = frames("SONY", {
        { ["Sony:SequenceImageNumber"] = 1, SourceFile = "/a/IMG_0001.ARW" },
        { ["Sony:SequenceImageNumber"] = 2, SourceFile = "/b/IMG_0002.ARW" },
    }, { ["Sony:ReleaseMode"] = 5 })
    eq(sizes(Grouping.group(list)), "", "groups")
end

function tests.unknown_make_is_reported_not_grouped()
    local groups, warnings = Grouping.group(frames("Hasselblad", { {}, {} }))
    eq(sizes(groups), "", "groups")
    eq(#warnings, 1, "warnings")
end

return tests
