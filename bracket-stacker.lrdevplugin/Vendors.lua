--[[
Camera brands the grouping understands, and how each one marks a bracketed sequence in its metadata.
Tag names are exiftool's "Group:Tag" keys (see tags.args).

  name       Brand name shown to the user.
  make       Lua patterns, matched against the lowercased Make tag.
  strategy   "tagged":   the camera records each frame's position in the sequence.
             "inferred": the camera only flags bracket frames; sequences are split by timing and EV offsets.
  validated  true once the rules have been checked against real photos from this brand.
  kind       Rules deciding whether a frame belongs to an exposure or a focus bracket. The first match wins:
               { tag = ..., values = { [5] = "exposure" } }   value lookup
               { tag = ..., bit = 16, kind = "exposure" }      bit set in the value
               { tag = ..., nonzero = "exposure" }             any value other than 0
  position   Tag holding the frame's position in the sequence, counting from 1 ("tagged" only).
  length     Tag holding the sequence length, or { tag = ..., values = { ... } } to translate it.
  offset     Tag holding the frame's EV offset from the base exposure ("inferred" only).
  result     Tag that is non-zero on an image the camera made from a sequence, such as its own focus stack.
             Such images are never grouped.

Every value is read as the first number in the tag ("3 0" reads as 3, "6/3 0" as 2). Where one tag packs
several values, a field can be a function(frame) instead.
]]

local Vendors = {}

-- First number in an exiftool value: 5, "3 0", "6/3 0" and "-4/3" read as 5, 3, 2 and -1.333.
function Vendors.firstNumber(value)
    if type(value) == "number" then return value end
    if type(value) ~= "string" then return nil end
    local num, den = value:match("^%s*([-+]?[%d%.]+)/([%d%.]+)")
    if num then return tonumber(num) / tonumber(den) end
    return tonumber(value:match("^%s*([-+]?[%d%.]+)"))
end

local function numbers(value)
    local list = {}
    if type(value) == "number" then
        list[1] = value
    elseif type(value) == "string" then
        for token in value:gmatch("%S+") do list[#list + 1] = tonumber(token) end
    end
    return list
end

-- Largest number among a tag's copies in one group ("Sony:SequenceLength", "Sony:Copy1:SequenceLength", ...).
function Vendors.largest(frame, group, tag)
    local best
    for key, value in pairs(frame) do
        if key:sub(1, #group + 1) == group .. ":" and key:match(":" .. tag .. "$") then
            local number = Vendors.firstNumber(value)
            if number and (not best or number > best) then best = number end
        end
    end
    return best
end

local function bitSet(value, bit)
    return math.floor((value or 0) / bit) % 2 == 1
end

Vendors.bitSet = bitSet

Vendors.list = {
    {
        name = "Sony",
        make = { "^sony" },
        strategy = "tagged",
        validated = true,
        -- ReleaseMode 5 covers exposure brackets and, on bodies that have it, focus brackets. A focus bracket has
        -- the same drive tags as a Single Bracket (ReleaseMode2 23), but EXIF ExposureMode is "Auto bracket" (2) only
        -- on exposure brackets (A7C II, even in M mode). ReleaseMode 6 (white balance) and 8 (DRO) bracket one
        -- exposure, so they are not grouped.
        kind = function(frame)
            if Vendors.firstNumber(frame["Sony:ReleaseMode"]) ~= 5 then return nil end
            if Vendors.firstNumber(frame["Sony:ReleaseMode2"]) == 23
                and Vendors.firstNumber(frame["ExifIFD:ExposureMode"]) ~= 2 then
                return "focus"
            end
            return "exposure"
        end,
        position = "Sony:SequenceImageNumber",
        -- Sony writes SequenceLength twice; in Single Bracket and focus-bracket mode one copy says 1 and the other
        -- the real length, so take the largest. It is a single byte, so a 299-shot bracket reads 43.
        length = function(frame) return Vendors.largest(frame, "Sony", "SequenceLength") end,
    },
    {
        name = "Canon",
        make = { "^canon" },
        strategy = "inferred",
        validated = true,
        kind = {
            { tag = "Canon:BracketMode", values = { [1] = "exposure" } },
            -- Older bodies (400D) leave BracketMode at 0 and set only this.
            { tag = "Canon:AutoExposureBracketing", nonzero = "exposure" },
            { tag = "Canon:FocusBracketing", values = { [1] = "focus" } },
        },
        offset = "Canon:AEBBracketValue",
        -- AEBShotCount is a menu setting, present even when bracketing is off.
        length = function(frame)
            if Vendors.firstNumber(frame["Canon:BracketMode"]) == 1 then
                return Vendors.firstNumber(frame["CanonCustom:AEBShotCount"])
            end
        end,
    },
    {
        name = "Nikon",
        make = { "^nikon" },
        strategy = "inferred",
        validated = true,
        kind = { { tag = "Nikon:ShootingMode", bit = 16, kind = "exposure" } },
        offset = "Nikon:ExposureBracketValue",
    },
    {
        name = "Panasonic",
        make = { "^panasonic" },
        strategy = "tagged",
        validated = true,
        kind = { { tag = "Panasonic:BurstMode", values = { [2] = "exposure", [3] = "focus" } } },
        position = "Panasonic:SequenceNumber",
        length = { tag = "Panasonic:BracketSettings", values = { 3, 3, 5, 5, 7, 7 } },
    },
    {
        name = "Pentax",
        make = { "pentax", "^ricoh" },
        strategy = "inferred",
        validated = true,
        -- AutoBracketing holds the EV step ("0 0" when off); the offset is only in EXIF.
        kind = { { tag = "Pentax:AutoBracketing", nonzero = "exposure" } },
        offset = "ExifIFD:ExposureCompensation",
    },
    {
        name = "OM System / Olympus",
        make = { "^olympus", "^om digital" },
        strategy = "tagged",
        validated = false,
        -- DriveMode is "mode shot bits ...". Mode 2 and 4 are exposure brackets on older bodies; mode 5 uses
        -- bits: 1 AE, 32 AE Auto, 64 focus.
        kind = function(frame)
            local drive = numbers(frame["Olympus:DriveMode"])
            local mode, bits = drive[1], drive[3]
            if mode == 2 or mode == 4 then return "exposure" end
            if mode == 5 then
                if bitSet(bits, 64) then return "focus" end
                if bitSet(bits, 1) or bitSet(bits, 32) then return "exposure" end
            end
        end,
        position = function(frame) return numbers(frame["Olympus:DriveMode"])[2] end,
        result = "Olympus:StackedImage",
    },
    {
        name = "Fujifilm",
        make = { "^fujifilm" },
        strategy = "tagged",
        validated = false,
        kind = { { tag = "FujiFilm:AutoBracketing", values = { [1] = "exposure" } } },
        position = "FujiFilm:SequenceNumber",
    },
}

function Vendors.forMake(make)
    if type(make) ~= "string" then return nil end
    make = make:lower()
    for _, vendor in ipairs(Vendors.list) do
        for _, pattern in ipairs(vendor.make) do
            if make:find(pattern) then return vendor end
        end
    end
end

return Vendors
