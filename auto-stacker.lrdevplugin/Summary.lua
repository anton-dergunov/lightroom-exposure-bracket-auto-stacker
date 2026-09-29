--[[
Text shown to the user after bracket detection. Pure Lua 5.1, shared by the plugin's menu items and the tests.
]]

local Summary = {}

Summary.HELP_URL = "https://github.com/anton-dergunov/lightroom-exposure-bracket-auto-stacker#help-wanted-sample-photos"

local MAX_WARNINGS = 10

local function plural(count, word)
    return count .. " " .. word .. (count == 1 and "" or "s")
end

-- Returns a one-line headline and the detailed text.
-- `photoCount` is the number of photos read, `groups` and `warnings` come from Grouping.group.
function Summary.describe(photoCount, groups, warnings)
    local lines = {}

    -- Counts per brand and kind, in the order they first appear.
    local order, counts = {}, {}
    local untested, untestedSeen = {}, {}
    for _, group in ipairs(groups) do
        local key = group.vendor .. "|" .. group.kind
        if not counts[key] then
            counts[key] = { vendor = group.vendor, kind = group.kind, total = 0, incomplete = 0 }
            order[#order + 1] = key
        end
        counts[key].total = counts[key].total + 1
        if group.complete == false then counts[key].incomplete = counts[key].incomplete + 1 end
        if not group.validated and not untestedSeen[group.vendor] then
            untestedSeen[group.vendor] = true
            untested[#untested + 1] = group.vendor
        end
    end

    local headline
    if #groups == 0 then
        headline = "No bracketed sequences found in " .. plural(photoCount, "photo") .. "."
    else
        headline = string.format("Found %s in %s.", plural(#groups, "bracketed sequence"), plural(photoCount, "photo"))
        for _, key in ipairs(order) do
            local c = counts[key]
            local line = string.format("%s: %s", c.vendor, plural(c.total, c.kind .. " bracket"))
            if c.incomplete > 0 then line = line .. string.format(" (%d incomplete)", c.incomplete) end
            lines[#lines + 1] = line
        end
    end

    local unknownMakes = false
    if #warnings > 0 then
        lines[#lines + 1] = ""
        for i, warning in ipairs(warnings) do
            if i > MAX_WARNINGS then
                lines[#lines + 1] = string.format("... and %d more", #warnings - MAX_WARNINGS)
                break
            end
            lines[#lines + 1] = warning
        end
        for _, warning in ipairs(warnings) do
            if warning:match("^No grouping rules") then unknownMakes = true end
        end
    end

    if #untested > 0 or unknownMakes then
        lines[#lines + 1] = ""
        if #untested > 0 then
            lines[#lines + 1] = string.format(
                "The rules for %s have not been tested on real photos yet, so please check these stacks.",
                table.concat(untested, ", "))
        end
        lines[#lines + 1] = "Sample photos from your camera would help confirm and extend camera support. "
            .. "Anonymised files are fine; see " .. Summary.HELP_URL
    end

    return headline, table.concat(lines, "\n")
end

local function counts(stacks, singles)
    local parts = { plural(stacks, "stack") }
    if singles > 0 then parts[#parts + 1] = plural(singles, "single photo") end
    return table.concat(parts, " and ")
end

local function skippedLines(plan)
    local lines = {}
    if #plan.skippedStacks > 0 then
        lines[#lines + 1] = plural(#plan.skippedStacks, "bracketed sequence")
            .. " left out because some of their photos are already in the catalog (Lightroom can only stack photos while importing them)."
    end
    if plan.skippedPhotos > 0 then
        lines[#lines + 1] = plural(plan.skippedPhotos, "single photo") .. " already in the catalog left out."
    end
    return lines
end

-- A folder's name relative to the folder the user chose: "RAW" for <root>/RAW, the root's own name for the root.
function Summary.folderName(path, root)
    if not root then return path end
    root = root:gsub("[/\\]+$", "")
    if path == root then return root:match("[^/\\]+$") or root end
    if path:sub(1, #root) == root and path:sub(#root + 1, #root + 1):match("[/\\]") then
        return path:sub(#root + 2)
    end
    return path
end

local function folderNames(plan, root)
    local names = {}
    for i, folder in ipairs(plan.folders) do names[i] = Summary.folderName(folder.path, root) end
    table.sort(names)
    return names
end

-- Question asked before importing: headline and details. `detection` is the details text from Summary.describe,
-- `root` the folder the user chose.
function Summary.confirmation(plan, detection, root)
    local fromFolders = #plan.folders > 1 and (" from " .. #plan.folders .. " folders") or ""
    local headline = string.format("Import %s%s as %s?", plural(plan.photoCount, "photo"), fromFolders,
        counts(#plan.stacks, #plan.singles))
    local lines = {}
    if #plan.folders > 1 then
        local perFolder = {}
        for _, folder in ipairs(plan.folders) do
            perFolder[#perFolder + 1] = string.format("%s: %s, %s", Summary.folderName(folder.path, root),
                plural(folder.photos, "photo"), counts(folder.stacks, folder.singles))
        end
        table.sort(perFolder)
        for _, line in ipairs(perFolder) do lines[#lines + 1] = line end
    end
    local skipped = skippedLines(plan)
    if #skipped > 0 and #lines > 0 then lines[#lines + 1] = "" end
    for _, line in ipairs(skipped) do lines[#lines + 1] = line end
    if detection and detection ~= "" then
        if #lines > 0 then lines[#lines + 1] = "" end
        lines[#lines + 1] = detection
    end
    return headline, table.concat(lines, "\n")
end

--[[
Report after importing. `result`:
  stacks, singles, photos   numbers imported
  failures                  list of "path: message" strings
  canceled                  true if the user stopped the import
  shown                     true if the Library now shows the folders the photos went to
`root` is the folder the user chose.
]]
function Summary.importResult(plan, result, root)
    local headline = string.format("Imported %s as %s.", plural(result.photos, "photo"),
        counts(result.stacks, result.singles))
    local lines = {}
    if result.canceled then lines[#lines + 1] = "The import was stopped before it finished." end
    for i, failure in ipairs(result.failures) do
        if i > MAX_WARNINGS then
            lines[#lines + 1] = string.format("... and %d more photos could not be imported", #result.failures - MAX_WARNINGS)
            break
        end
        lines[#lines + 1] = "Could not import " .. failure
    end
    for _, line in ipairs(skippedLines(plan)) do lines[#lines + 1] = line end
    if result.photos > 0 then
        if #lines > 0 then lines[#lines + 1] = "" end
        local names = table.concat(folderNames(plan, root), ", ")
        local where = #plan.folders > 1 and "The photos are in these folders" or "The photos are in the folder"
        lines[#lines + 1] = string.format("%s under Library > Folders: %s.%s", where, names,
            result.shown and " The Library is now showing them." or "")
        lines[#lines + 1] = "Lightroom's Previous Import collection does not list photos added by a plug-in."
    end
    if result.stacks > 0 then
        if #lines > 0 then lines[#lines + 1] = "" end
        lines[#lines + 1] = "To merge the stacks into HDR images: in the Library, choose Photo > Stacking > Collapse All "
            .. "Stacks, select the stacks, then choose Photo > Photo Merge > HDR. Lightroom merges each stack in turn."
    end
    return headline, table.concat(lines, "\n")
end

return Summary
