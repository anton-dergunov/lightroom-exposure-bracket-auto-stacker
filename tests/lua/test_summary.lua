local Summary = require 'Summary'

local function group(vendor, kind, validated, complete)
    return { vendor = vendor, kind = kind, validated = validated, complete = complete, frames = {} }
end

local function contains(text, part)
    if not text:find(part, 1, true) then
        error(string.format("expected to find %q in:\n%s", part, text), 2)
    end
end

local tests = {}

function tests.counts_per_brand_and_kind()
    local headline, details = Summary.describe(20, {
        group("Sony", "exposure", true, true), group("Sony", "exposure", true, false), group("Canon", "exposure", true, nil),
    }, {})
    contains(headline, "Found 3 bracketed sequences in 20 photos.")
    contains(details, "Sony: 2 exposure brackets (1 incomplete)")
    contains(details, "Canon: 1 exposure bracket")
    assert(not details:find(Summary.HELP_URL, 1, true), "no request for samples when every brand is tested")
end

function tests.asks_for_samples_for_untested_brands()
    local _, details = Summary.describe(3, { group("Fujifilm", "exposure", false, nil) }, {})
    contains(details, "The rules for Fujifilm have not been tested on real photos yet")
    contains(details, Summary.HELP_URL)
end

function tests.asks_for_samples_for_unknown_makes()
    local headline, details = Summary.describe(2, {}, { "No grouping rules for camera make 'Hasselblad'" })
    contains(headline, "No bracketed sequences found in 2 photos.")
    contains(details, "Hasselblad")
    contains(details, Summary.HELP_URL)
end

return tests
