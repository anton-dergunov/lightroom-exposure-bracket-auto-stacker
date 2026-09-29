--[[
Menu item: after HDR merging, flag the source photos of the merged stacks as rejected, so that Lightroom's own
Photo > Delete Rejected Photos can remove them. Works on the selected photos, or on all photos in view when
nothing is selected. Plug-ins cannot remove photos from the catalog themselves.
]]

local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrFunctionContext = import 'LrFunctionContext'

local Cleanup = require 'Cleanup'

local function plural(count, word)
    return count .. " " .. word .. (count == 1 and "" or "s")
end

-- The stacks that contain any of `photos`, each once, with their source photos and whether they were merged.
local function stacksOf(catalog, photos)
    local stacks, seen = {}, {}
    for _, photo in ipairs(photos) do
        if photo:getRawMetadata("isInStackInFolder") then
            local top = photo:getRawMetadata("topOfStackInFolderContainingPhoto")
            if not seen[top.localIdentifier] then
                seen[top.localIdentifier] = true
                local stack = { sources = {}, hdr = false }
                for _, member in ipairs(top:getRawMetadata("stackInFolderMembers")) do
                    local path = member:getRawMetadata("path")
                    if Cleanup.isHdrResult(path) then
                        stack.hdr = true
                    else
                        stack.sources[#stack.sources + 1] = {
                            photo = member,
                            path = path,
                            exposureBias = member:getRawMetadata("exposureBias"),
                            shutterSpeed = member:getRawMetadata("shutterSpeed"),
                        }
                    end
                end
                -- Merged without "Create Stack": the HDR image sits next to the sources instead.
                for _, source in ipairs(stack.sources) do
                    if stack.hdr then break end
                    if catalog:findPhotoByPath(Cleanup.hdrPathFor(source.path)) then stack.hdr = true end
                end
                stacks[#stacks + 1] = stack
            end
        end
    end
    return stacks
end

LrFunctionContext.postAsyncTaskWithContext("Reject extra exposures", function(context)
    LrDialogs.attachErrorDialogToFunctionContext(context)
    local catalog = LrApplication.activeCatalog()

    local stacks = stacksOf(catalog, catalog:getTargetPhotos())
    local preview = Cleanup.plan(stacks, true)
    if preview.merged == 0 then
        LrDialogs.message("No merged stacks found",
            "Select the stacks whose HDR images you have already made (or show their folder with nothing selected), "
            .. "then try again." .. (#stacks > 0 and ("\n\n" .. plural(#stacks, "stack") .. " found, none with an HDR image yet.") or ""),
            "info")
        return
    end

    local details = "Rejected photos stay in the catalog until you choose Photo > Delete Rejected Photos."
    if preview.unmerged > 0 then
        details = plural(preview.unmerged, "stack") .. " without an HDR image will be left alone.\n\n" .. details
    end
    local choice = LrDialogs.confirm(
        string.format("Reject photos in %s that have an HDR image?", plural(preview.merged, "stack")),
        details, "Reject Extra Exposures", "Cancel", "Reject All Source Photos")
    if choice ~= "ok" and choice ~= "other" then return end

    local plan = Cleanup.plan(stacks, choice == "other")
    catalog:withWriteAccessDo("Reject extra exposures", function()
        for _, photo in ipairs(plan.reject) do photo:setRawMetadata("pickStatus", -1) end
    end, { timeout = 60 })

    LrDialogs.message(
        string.format("Rejected %s in %s.", plural(#plan.reject, "photo"), plural(plan.merged, "stack")),
        "To remove them, choose Photo > Delete Rejected Photos. Remove takes them out of the catalog; Delete from Disk "
        .. "also moves the files to the Trash.",
        "info")
end)
