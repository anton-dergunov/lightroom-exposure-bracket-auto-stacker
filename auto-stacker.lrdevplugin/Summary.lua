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

return Summary
