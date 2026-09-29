--[[
Finds bracketed sequences in exiftool output (-j -n -G1 -a with tags.args).

Grouping.group(frames) takes the decoded list of frames and returns:
  groups    list of { frames, kind, vendor, validated, complete, length }, frames in shot order.
            complete is true or false when the sequence length is known, nil otherwise.
  warnings  list of strings.
Pure Lua 5.1 with no Lightroom dependency, so it runs the same in the plugin and in the tests.
]]

local Vendors = require 'Vendors'

local Grouping = {}

local firstNumber = Vendors.firstNumber

-- A frame more than this many seconds after the previous one starts a new sequence, even if its tags say
-- otherwise (Single Bracket mode leaves a pause between presses).
local TAGGED_MAX_GAP = 60
-- For "inferred" brands: the most a frame may start after the previous frame's exposure ended.
local INFERRED_MAX_GAP = 2

local function fileName(frame)
    return frame["System:FileName"] or (frame.SourceFile and frame.SourceFile:match("[^/\\]+$")) or ""
end

local function directory(frame)
    return frame.SourceFile and frame.SourceFile:match("^(.*)[/\\]") or ""
end

local function extension(name)
    return (name:match("%.([^.]+)$") or ""):upper()
end

-- Days since 1970-01-01 for a proleptic Gregorian date (os.time depends on the local time zone).
local function daysFromCivil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local doy = math.floor((153 * ((m + 9) % 12) + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

-- Capture time in seconds, including fractions when the camera records them.
local function captureTime(frame)
    local text = frame["Composite:SubSecDateTimeOriginal"] or frame["ExifIFD:DateTimeOriginal"]
        or frame["IFD0:DateTimeOriginal"] or frame["XMP-exif:DateTimeOriginal"]
    if type(text) ~= "string" then return nil end
    local y, mo, d, h, mi, s, frac = text:match("^(%d+):(%d+):(%d+) (%d+):(%d+):(%d+)(%.?%d*)")
    if not y then return nil end
    local t = daysFromCivil(tonumber(y), tonumber(mo), tonumber(d)) * 86400
        + tonumber(h) * 3600 + tonumber(mi) * 60 + tonumber(s)
    if #frac > 1 then
        return t + tonumber("0" .. frac)
    end
    -- Not SubSecTime: that belongs to the modification time (the Panasonic TZ3 fixture has it from a re-save).
    local subsec = frame["ExifIFD:SubSecTimeOriginal"]
    if subsec ~= nil then
        return t + (tonumber("0." .. tostring(subsec)) or 0)
    end
    return t
end

local function shutterCount(frame)
    for key, value in pairs(frame) do
        if type(value) == "number" and (key:match(":ShutterCount$") or key:match(":ImageCount$")) then
            return value
        end
    end
end

-- Reads a vendor field: a tag name, a { tag, values } translation, or a function(frame).
local function read(frame, field)
    if field == nil then return nil end
    if type(field) == "function" then return field(frame) end
    if type(field) == "string" then return firstNumber(frame[field]) end
    local value = firstNumber(frame[field.tag])
    if value ~= nil and field.values then return field.values[value] end
    return value
end

-- "exposure", "focus" or nil for a frame that is not part of a sequence to group.
local function frameKind(vendor, frame)
    if vendor.result and (firstNumber(frame[vendor.result]) or 0) ~= 0 then return nil end
    if type(vendor.kind) == "function" then return vendor.kind(frame) end
    for _, rule in ipairs(vendor.kind) do
        local value = firstNumber(frame[rule.tag])
        if value ~= nil then
            if rule.values and rule.values[value] then return rule.values[value] end
            if rule.bit and Vendors.bitSet(value, rule.bit) then return rule.kind end
            if rule.nonzero and value ~= 0 then return rule.nonzero end
        end
    end
end

-- Splits frames by folder, file type and camera, so RAW and JPEG copies are never mixed.
local function partitions(frames, warnings)
    local byKey, order, unknown = {}, {}, {}
    for _, frame in ipairs(frames) do
        local make = frame["IFD0:Make"]
        local vendor = Vendors.forMake(make)
        if vendor then
            local key = table.concat({ directory(frame), extension(fileName(frame)), make, tostring(frame["IFD0:Model"]) }, "|")
            if not byKey[key] then
                byKey[key] = { vendor = vendor, frames = {} }
                order[#order + 1] = key
            end
            table.insert(byKey[key].frames, frame)
        elseif make and not unknown[make] then
            unknown[make] = true
            warnings[#warnings + 1] = "No grouping rules for camera make '" .. tostring(make) .. "'"
        end
    end
    local list = {}
    for _, key in ipairs(order) do list[#list + 1] = byKey[key] end
    return list
end

local function sortByShotOrder(frames)
    local keyed = {}
    for i, frame in ipairs(frames) do
        keyed[i] = { frame = frame, time = captureTime(frame) or -1, count = shutterCount(frame) or -1, name = fileName(frame) }
    end
    table.sort(keyed, function(a, b)
        if a.time ~= b.time then return a.time < b.time end
        if a.count ~= b.count then return a.count < b.count end
        return a.name < b.name
    end)
    return keyed
end

-- Whether `shot` starts a new sequence rather than continuing `current`.
local function startsNew(vendor, current, shot)
    if not current or current.kind ~= shot.kind then return true end
    if current.length and #current.frames >= current.length then return true end
    local last = current.last
    local gap = (shot.time >= 0 and last.time >= 0) and (shot.time - last.time) or 0
    if vendor.strategy == "tagged" then
        if shot.position and (shot.position <= 1 or (last.position and shot.position <= last.position)) then
            return true
        end
        return gap > TAGGED_MAX_GAP
    end
    if gap > (firstNumber(last.frame["ExifIFD:ExposureTime"]) or 0) + INFERRED_MAX_GAP then return true end
    if shot.count >= 0 and last.count >= 0 and shot.count - last.count ~= 1 then return true end
    if shot.offset ~= nil then
        for _, offset in ipairs(current.offsets) do
            if math.abs(offset - shot.offset) < 1e-6 then return true end
        end
    end
    return false
end

function Grouping.group(frames)
    local groups, warnings = {}, {}

    for _, part in ipairs(partitions(frames, warnings)) do
        local vendor, current = part.vendor, nil

        local function close()
            if current and #current.frames >= 2 then
                local length = current.length
                local group = {
                    frames = current.frames,
                    kind = current.kind,
                    vendor = vendor.name,
                    validated = vendor.validated,
                    length = length,
                }
                if length then
                    group.complete = #current.frames == length and current.firstPosition ~= false
                    if not group.complete then
                        warnings[#warnings + 1] = string.format("Incomplete %s bracket starting at %s: %d of %d frames",
                            current.kind, fileName(current.frames[1]), #current.frames, length)
                    end
                end
                groups[#groups + 1] = group
            end
            current = nil
        end

        for _, shot in ipairs(sortByShotOrder(part.frames)) do
            shot.kind = frameKind(vendor, shot.frame)
            if not shot.kind then
                close()
            else
                shot.position = read(shot.frame, vendor.position)
                shot.offset = read(shot.frame, vendor.offset)
                if startsNew(vendor, current, shot) then
                    close()
                    local length = read(shot.frame, vendor.length)
                    current = {
                        kind = shot.kind,
                        frames = {},
                        offsets = {},
                        length = (length and length > 1) and length or nil,
                        -- A tagged sequence is only complete if it starts at position 1.
                        firstPosition = shot.position == nil or shot.position == 1,
                    }
                end
                table.insert(current.frames, shot.frame)
                if shot.offset ~= nil then table.insert(current.offsets, shot.offset) end
                current.last = shot
            end
        end
        close()
    end

    return groups, warnings
end

return Grouping
