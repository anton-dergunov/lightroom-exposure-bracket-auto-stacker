--[[
Decides what an import does, from the frames exiftool read and the groups Grouping found. Pure Lua 5.1, so the
same decisions are tested outside Lightroom.

ImportPlan.build(frames, groups, options) with options:
  onlyBrackets  true: import only the photos in bracketed sequences; false: every photo in the folder
  inCatalog     function(path) returning true for photos already in the catalog
  kinds         optional { exposure = true, focus = false }: which kinds of bracket to stack (default: all). With
                onlyBrackets, a bracket of another kind is left out; otherwise its photos are imported unstacked.
returns {
  stacks        list of { paths = {...}, group = group }: paths[1] is the base exposure, the rest follow in shot order
  singles       paths to import on their own
  skippedStacks groups left out because some of their photos are already in the catalog
  skippedPhotos number of single photos left out because they are already in the catalog
  leftOut       number of brackets not stacked because their kind was not chosen
  kinds         number of stacks per kind, e.g. { exposure = 8, focus = 2 }
  photoCount    number of photos the plan imports
  folders       folders the photos go to, in first-seen order: { path, stacks, singles, photos }
}
Lightroom can only stack photos while importing them, so a bracket with any photo already in the catalog is left
out whole rather than imported as a broken stack.
]]

local ImportPlan = {}

local function path(frame)
    return frame.SourceFile or frame["System:FileName"]
end

function ImportPlan.directory(file)
    return file:match("^(.*)[/\\][^/\\]*$") or ""
end

-- Adds `count` photos (as a stack or as single photos) to the folder that holds `file`.
local function countIn(plan, index, file, count, isStack)
    local dir = ImportPlan.directory(file)
    local folder = index[dir]
    if not folder then
        folder = { path = dir, stacks = 0, singles = 0, photos = 0 }
        index[dir] = folder
        plan.folders[#plan.folders + 1] = folder
    end
    folder.photos = folder.photos + count
    if isStack then folder.stacks = folder.stacks + 1 else folder.singles = folder.singles + count end
end

function ImportPlan.build(frames, groups, options)
    local inCatalog = options.inCatalog or function() return false end
    local plan = { stacks = {}, singles = {}, skippedStacks = {}, skippedPhotos = 0, photoCount = 0, folders = {},
        leftOut = 0, kinds = {}, onlyBrackets = options.onlyBrackets }
    local grouped, folderIndex = {}, {}

    local function addStack(group)
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
            plan.kinds[group.kind] = (plan.kinds[group.kind] or 0) + 1
            countIn(plan, folderIndex, paths[1], #paths, true)
        end
    end

    for _, group in ipairs(groups) do
        if options.kinds and not options.kinds[group.kind] then
            plan.leftOut = plan.leftOut + 1
            -- Importing only brackets: leave its photos out. Importing everything: they become single photos.
            if options.onlyBrackets then
                for _, frame in ipairs(group.frames) do grouped[frame] = true end
            end
        else
            addStack(group)
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
                    countIn(plan, folderIndex, path(frame), 1, false)
                end
            end
        end
    end

    return plan
end

return ImportPlan
