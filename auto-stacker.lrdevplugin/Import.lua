--[[
Imports a folder's photos into the catalog with each bracketed sequence as a stack, the base exposure on top.
Import.run(onlyBrackets) is started by the two import menu items.
]]

local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'
local LrProgressScope = import 'LrProgressScope'
local LrTasks = import 'LrTasks'

local ExifTool = require 'ExifTool'
local Grouping = require 'Grouping'
local ImportPlan = require 'ImportPlan'
local Summary = require 'Summary'

local Import = {}

-- Single photos are added in batches, one catalog transaction each, so progress and cancelling stay responsive.
local SINGLES_PER_BATCH = 25

local function chooseFolder(onlyBrackets)
    local folders = LrDialogs.runOpenPanel({
        title = onlyBrackets
            and "Choose a folder: its bracketed photos are imported as stacks (subfolders included)"
            or "Choose a folder: all its photos are imported, bracketed ones as stacks (subfolders included)",
        canChooseFiles = false,
        canChooseDirectories = true,
        allowsMultipleSelection = false,
    })
    return folders and folders[1]
end

-- Adds one photo, returning it, or nil and a message. `leader` stacks it below that photo.
local function addPhoto(catalog, path, leader)
    local ok, photo = LrTasks.pcall(function()
        if leader then return catalog:addPhoto(path, leader, "below") end
        return catalog:addPhoto(path)
    end)
    if ok and photo then return photo end
    return nil, tostring(photo or "unknown error")
end

-- Runs `work` in one catalog transaction; records the photos as failed if Lightroom gives up waiting for the catalog
-- ("aborted"). "queued" means the work runs a little later, which is fine.
local function withCatalog(catalog, result, paths, work)
    local status = catalog:withWriteAccessDo("Import and stack brackets", work, { timeout = 60 })
    if status == "aborted" then
        for _, path in ipairs(paths) do
            result.failures[#result.failures + 1] = path .. ": the catalog was busy (" .. tostring(status) .. ")"
        end
    end
end

-- The keywords for each kind of stack, created on first use; hidden from exports.
local function stackKeywords(catalog)
    local keywords
    catalog:withWriteAccessDo("Create bracket keywords", function()
        local parent = catalog:createKeyword(Summary.KEYWORDS.parent, {}, false, nil, true)
        keywords = {
            exposure = catalog:createKeyword(Summary.KEYWORDS.exposure, {}, false, parent, true),
            focus = catalog:createKeyword(Summary.KEYWORDS.focus, {}, false, parent, true),
        }
    end, { timeout = 60 })
    return keywords or {}
end

local function importPlan(catalog, plan, progress, result)
    local keywords = #plan.stacks > 0 and stackKeywords(catalog) or {}
    local total, done = plan.photoCount, 0
    local function advance(count)
        done = done + count
        progress:setPortionComplete(done, total)
    end

    for _, stack in ipairs(plan.stacks) do
        if progress:isCanceled() then result.canceled = true return end
        withCatalog(catalog, result, stack.paths, function()
            local leader, message = addPhoto(catalog, stack.paths[1])
            if not leader then
                result.failures[#result.failures + 1] = stack.paths[1] .. ": " .. message
                return
            end
            local keyword = keywords[stack.group.kind]
            if keyword then leader:addKeyword(keyword) end
            result.stacks = result.stacks + 1
            result.photos = result.photos + 1
            for i = 2, #stack.paths do
                local photo, failure = addPhoto(catalog, stack.paths[i], leader)
                if photo then
                    if keyword then photo:addKeyword(keyword) end
                    result.photos = result.photos + 1
                else
                    result.failures[#result.failures + 1] = stack.paths[i] .. ": " .. failure
                end
            end
        end)
        advance(#stack.paths)
    end

    for first = 1, #plan.singles, SINGLES_PER_BATCH do
        if progress:isCanceled() then result.canceled = true return end
        local last = math.min(first + SINGLES_PER_BATCH - 1, #plan.singles)
        local batch = {}
        for i = first, last do batch[#batch + 1] = plan.singles[i] end
        withCatalog(catalog, result, batch, function()
            for i = first, last do
                local photo, message = addPhoto(catalog, plan.singles[i])
                if photo then
                    result.singles = result.singles + 1
                    result.photos = result.photos + 1
                else
                    result.failures[#result.failures + 1] = plan.singles[i] .. ": " .. message
                end
            end
        end)
        advance(last - first + 1)
    end
end

-- Switches the Library to the folders the photos went to, as selecting them in the Folders panel would.
-- Returns true if Lightroom accepted them.
local function showFolders(catalog, plan)
    local folders = {}
    for _, folder in ipairs(plan.folders) do
        local found = catalog:getFolderByPath(folder.path)
        if found then folders[#folders + 1] = found end
    end
    if #folders == 0 then return false end
    local ok, shown = LrTasks.pcall(function() return catalog:setActiveSources(folders) end)
    return ok and shown ~= false
end

function Import.run(onlyBrackets)
    LrFunctionContext.postAsyncTaskWithContext("Import and stack brackets", function(context)
        LrDialogs.attachErrorDialogToFunctionContext(context)

        local folder = chooseFolder(onlyBrackets)
        if not folder then return end

        local reading = LrProgressScope({ title = "Reading photo metadata", functionContext = context })
        local frames, message = ExifTool.readFolder(folder, true)
        reading:done()
        if not frames then
            LrDialogs.message("Could not read the photos", message, "critical")
            return
        end

        local catalog = LrApplication.activeCatalog()
        local groups, warnings = Grouping.group(frames)
        local function planFor(kinds)
            return ImportPlan.build(frames, groups, {
                onlyBrackets = onlyBrackets,
                kinds = kinds,
                inCatalog = function(path) return catalog:findPhotoByPath(path) ~= nil end,
            })
        end
        local plan = planFor(nil)
        local found, detection = Summary.describe(#frames, groups, warnings)

        if plan.photoCount == 0 then
            local _, details = Summary.confirmation(plan, detection, folder)
            LrDialogs.message("Nothing to import. " .. found, details, "info")
            return
        end

        -- Focus brackets must stay out of a batch HDR merge, so offer to leave them unstacked.
        local question, details = Summary.confirmation(plan, detection, folder)
        local withoutFocus = nil
        if (plan.kinds.focus or 0) > 0 then
            withoutFocus = onlyBrackets and "Leave Out Focus Brackets" or "Don't Stack Focus Brackets"
        end
        local choice = LrDialogs.confirm(question, details, "Import", "Cancel", withoutFocus)
        if choice == "other" then
            plan = planFor({ exposure = true })
            if plan.photoCount == 0 then
                LrDialogs.message("Nothing to import", "The folder has only focus brackets.", "info")
                return
            end
        elseif choice ~= "ok" then
            return
        end

        local progress = LrProgressScope({ title = "Importing photos", functionContext = context })
        progress:setCancelable(true)
        local result = { stacks = 0, singles = 0, photos = 0, failures = {}, canceled = false }
        importPlan(catalog, plan, progress, result)
        progress:done()
        if result.photos > 0 then result.shown = showFolders(catalog, plan) end

        local headline, report = Summary.importResult(plan, result, folder)
        LrDialogs.message(headline, report, #result.failures > 0 and "warning" or "info")
    end)
end

return Import
