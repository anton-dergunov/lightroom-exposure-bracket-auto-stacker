--[[
Decides what an import does, from the frames exiftool read and the groups Grouping found. Pure Lua 5.1, so the
same decisions are tested outside Lightroom.

ImportPlan.build(frames, groups, options) with options:
  onlyBrackets  true: import only the photos in bracketed sequences; false: every photo in the folder
  inCatalog     function(path) returning true for photos already in the catalog
returns {
  stacks        list of { paths = {...}, group = group }: paths[1] is the base exposure, the rest follow in shot order
  singles       paths to import on their own
  skippedStacks groups left out because some of their photos are already in the catalog
  skippedPhotos number of single photos left out because they are already in the catalog
  photoCount    number of photos the plan imports
}
Lightroom can only stack photos while importing them, so a bracket with any photo already in the catalog is left
out whole rather than imported as a broken stack.
]]

local ImportPlan = {}

local function path(frame)
    return frame.SourceFile or frame["System:FileName"]
end

function ImportPlan.build(frames, groups, options)
    local inCatalog = options.inCatalog or function() return false end
    local plan = { stacks = {}, singles = {}, skippedStacks = {}, skippedPhotos = 0, photoCount = 0 }
    local grouped = {}

    for _, group in ipairs(groups) do
        local paths, known = {}, false
        local base = group.frames[group.base or 1]
        paths[1] = path(base)
        for _, frame in ipairs(group.frames) do
            grouped[frame] = true
            if frame ~= base then paths[#paths + 1] = path(frame) end
            if inCatalog(path(frame)) then known = true end
        end
        if known then
            plan.skippedStacks[#plan.skippedStacks + 1] = group
        else
            plan.stacks[#plan.stacks + 1] = { paths = paths, group = group }
            plan.photoCount = plan.photoCount + #paths
        end
    end

    if not options.onlyBrackets then
        for _, frame in ipairs(frames) do
            if not grouped[frame] then
                if inCatalog(path(frame)) then
                    plan.skippedPhotos = plan.skippedPhotos + 1
                else
                    plan.singles[#plan.singles + 1] = path(frame)
                    plan.photoCount = plan.photoCount + 1
                end
            end
        end
    end

    return plan
end

return ImportPlan
