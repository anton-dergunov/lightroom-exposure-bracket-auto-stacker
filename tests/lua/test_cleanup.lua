local Cleanup = require 'Cleanup'

local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what, tostring(expected), tostring(actual)), 2)
    end
end

local function stack(hdr, biases)
    local sources = {}
    for i, bias in ipairs(biases) do sources[i] = { photo = "p" .. i, exposureBias = bias, shutterSpeed = 1 } end
    return { sources = sources, hdr = hdr }
end

local tests = {}

function tests.recognises_lightroom_hdr_names()
    eq(Cleanup.isHdrResult("/p/DSC01234-HDR.dng"), true, "plain")
    eq(Cleanup.isHdrResult([[C:\p\DSC01234-HDR-2.DNG]]), true, "numbered, Windows, upper case")
    eq(Cleanup.isHdrResult("/p/DSC01234.dng"), false, "a camera DNG")
    eq(Cleanup.isHdrResult("/p/DSC01234-HDR.jpg"), false, "an export")
    eq(Cleanup.hdrPathFor("/p/DSC01234.ARW"), "/p/DSC01234-HDR.dng", "expected name")
end

function tests.keeps_the_base_exposure_of_merged_stacks()
    local plan = Cleanup.plan({ stack(true, { 0.3, -0.7, 1.3 }), stack(false, { 0, -1, 1 }) }, false)
    eq(table.concat(plan.reject, ","), "p2,p3", "rejected")
    eq(plan.merged, 1, "merged stacks")
    eq(plan.unmerged, 1, "stacks without HDR")
end

function tests.manual_mode_falls_back_to_shutter_speed()
    local s = { sources = {
        { photo = "long", exposureBias = 0, shutterSpeed = 1 },
        { photo = "base", exposureBias = 0, shutterSpeed = 1 / 4 },
        { photo = "short", exposureBias = 0, shutterSpeed = 1 / 15 },
    }, hdr = true }
    eq(table.concat(Cleanup.plan({ s }, false).reject, ","), "long,short", "rejected")
end

function tests.reject_all_sources()
    eq(#Cleanup.plan({ stack(true, { 0, -1, 1 }) }, true).reject, 3, "rejected")
end

return tests
