-- The base-exposure frame of each group, checked on real fixtures. It becomes the top of the stack in Lightroom.

local json = require 'Json'
local Grouping = require 'Grouping'

local function bases(fixture)
    local file = assert(io.open(TEST_ROOT .. "/tests/fixtures/" .. fixture .. ".json", "rb"))
    local frames = json.decode(file:read("*a")).frames
    file:close()
    local names = {}
    for _, group in ipairs(Grouping.group(frames)) do
        names[#names + 1] = group.frames[group.base]["System:FileName"]
    end
    table.sort(names)
    return table.concat(names, ",")
end

local function eq(actual, expected, what)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", what, expected, actual), 2)
    end
end

local tests = {}

function tests.canon_order_minus_zero_plus()
    eq(bases("canon/canon-eos-1d-mark-iv-cafe"), "AH7C0639.CR2", "Cafe")
end

function tests.canon_manual_mode_uses_bracket_offset()
    -- In M mode EXIF exposure compensation is 0 on every frame.
    eq(bases("canon/canon-eos-1d-mark-iv-zurich-pair"), "AH7C6918.CR2,AH7C6932.CR2", "Zurich")
end

function tests.sony_with_base_compensation()
    eq(bases("sony/sony-a7c-ii-greenwich"), "DSC02108.ARW,DSC02108.JPG,DSC02111.ARW,DSC02111.JPG", "Greenwich")
end

function tests.nikon_file_names_out_of_shot_order()
    eq(bases("nikon/nikon-d7000-nuernberg"), "Nuernberg_UBahn_Friedrich-Ebert-Platz_Belichtungsreihe_A3.jpg", "D7000")
end

function tests.pentax_uses_exif_compensation()
    eq(bases("pentax/pentax-k-50-bracket"), "IMGP0001.DNG", "K-50")
end

return tests
