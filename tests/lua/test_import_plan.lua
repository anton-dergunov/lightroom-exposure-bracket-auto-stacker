local ImportPlan = require 'ImportPlan'

local function frame(path) return { SourceFile = path } end

local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what, tostring(expected), tostring(actual)), 2)
    end
end

-- An exposure bracket, a focus bracket (with its base frame in the middle) and two single shots.
local function sample()
    local f = {}
    for i = 1, 8 do f[i] = frame("/p/" .. i .. ".ARW") end
    local groups = {
        { frames = { f[2], f[3], f[4] }, base = 1, kind = "exposure" },
        { frames = { f[5], f[6], f[7] }, base = 2, kind = "focus" },
    }
    return f, groups
end

local tests = {}

function tests.only_brackets_imports_stacks_with_the_base_exposure_first()
    local frames, groups = sample()
    local plan = ImportPlan.build(frames, groups, { onlyBrackets = true })
    eq(#plan.stacks, 2, "stacks")
    eq(table.concat(plan.stacks[1].paths, " "), "/p/2.ARW /p/3.ARW /p/4.ARW", "first stack")
    eq(table.concat(plan.stacks[2].paths, " "), "/p/6.ARW /p/5.ARW /p/7.ARW", "second stack, base first")
    eq(#plan.singles, 0, "singles")
    eq(plan.photoCount, 6, "photo count")
end

function tests.entire_folder_also_imports_single_shots()
    local frames, groups = sample()
    local plan = ImportPlan.build(frames, groups, { onlyBrackets = false })
    eq(table.concat(plan.singles, " "), "/p/1.ARW /p/8.ARW", "singles")
    eq(plan.photoCount, 8, "photo count")
end

function tests.photos_already_in_the_catalog_are_skipped()
    local frames, groups = sample()
    local plan = ImportPlan.build(frames, groups, {
        onlyBrackets = false,
        inCatalog = function(path) return path == "/p/6.ARW" or path == "/p/8.ARW" end,
    })
    eq(#plan.stacks, 1, "stacks")
    eq(#plan.skippedStacks, 1, "a bracket with one photo in the catalog is skipped whole")
    eq(table.concat(plan.singles, " "), "/p/1.ARW", "singles")
    eq(plan.skippedPhotos, 1, "skipped singles")
    eq(plan.photoCount, 4, "photo count")
end

function tests.counts_stacks_per_kind()
    local frames, groups = sample()
    local plan = ImportPlan.build(frames, groups, { onlyBrackets = true })
    eq(plan.kinds.exposure, 1, "exposure stacks")
    eq(plan.kinds.focus, 1, "focus stacks")
end

function tests.leaving_out_focus_brackets()
    local frames, groups = sample()
    local plan = ImportPlan.build(frames, groups, { onlyBrackets = true, kinds = { exposure = true } })
    eq(#plan.stacks, 1, "stacks")
    eq(plan.leftOut, 1, "brackets left out")
    eq(#plan.singles, 0, "the focus frames are not imported at all")
    eq(plan.photoCount, 3, "photo count")
end

function tests.not_stacking_focus_brackets_when_importing_everything()
    local frames, groups = sample()
    local plan = ImportPlan.build(frames, groups, { onlyBrackets = false, kinds = { exposure = true } })
    eq(#plan.stacks, 1, "stacks")
    eq(table.concat(plan.singles, " "), "/p/1.ARW /p/5.ARW /p/6.ARW /p/7.ARW /p/8.ARW", "focus frames imported unstacked")
    eq(plan.photoCount, 8, "photo count")
end

return tests
