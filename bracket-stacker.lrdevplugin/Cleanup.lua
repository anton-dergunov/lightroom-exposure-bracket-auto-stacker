--[[
Decides which photos to reject once bracketed stacks have been merged into HDR images. Pure Lua 5.1, shared by the
plugin (RejectExposures.lua) and the tests.

Lightroom names a merged image after one of its source photos, "DSC01234-HDR.dng" (with "-2", "-3"... added when
that name is taken), and puts it next to the sources; with "Create Stack" on, it also joins their stack.
]]

local Grouping = require 'Grouping'

local Cleanup = {}

function Cleanup.isHdrResult(path)
    return path:lower():match("%-hdr[%-%d]*%.dng$") ~= nil
end

-- Where Lightroom puts the HDR image merged with `path` as its first photo.
function Cleanup.hdrPathFor(path)
    return (path:gsub("%.[^./\\]+$", "")) .. "-HDR.dng"
end

--[[
`stacks`: list of { sources = { { photo, exposureBias, shutterSpeed } ... }, hdr = true if merged }
`rejectAll`: reject every source photo, rather than all but the base exposure.
Returns { reject = { photo ... }, merged = number of stacks with an HDR image, unmerged = number without }.
]]
function Cleanup.plan(stacks, rejectAll)
    local plan = { reject = {}, merged = 0, unmerged = 0 }
    for _, stack in ipairs(stacks) do
        if stack.hdr and #stack.sources > 0 then
            plan.merged = plan.merged + 1
            local keep = not rejectAll and Grouping.middleIndex(stack.sources, {
                function(source) return source.exposureBias end,
                function(source) return source.shutterSpeed end,
            })
            for i, source in ipairs(stack.sources) do
                if i ~= keep then plan.reject[#plan.reject + 1] = source.photo end
            end
        else
            plan.unmerged = plan.unmerged + 1
        end
    end
    return plan
end

return Cleanup
