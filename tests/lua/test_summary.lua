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

local function plan(stacks, singles, skippedStacks, skippedPhotos)
    local p = { stacks = {}, singles = {}, skippedStacks = {}, skippedPhotos = skippedPhotos or 0, photoCount = 0 }
    for i = 1, stacks do p.stacks[i] = { paths = { "a", "b", "c" } }; p.photoCount = p.photoCount + 3 end
    for i = 1, singles do p.singles[i] = "s" .. i; p.photoCount = p.photoCount + 1 end
    for i = 1, (skippedStacks or 0) do p.skippedStacks[i] = {} end
    return p
end

function tests.confirmation_counts_stacks_and_singles()
    local headline = Summary.confirmation(plan(2, 0), "")
    contains(headline, "Import 6 photos as 2 stacks?")
    headline = Summary.confirmation(plan(1, 1), "")
    contains(headline, "Import 4 photos as 1 stack and 1 single photo?")
end

function tests.confirmation_explains_skipped_photos()
    local _, details = Summary.confirmation(plan(1, 0, 2, 3), "Sony: 3 exposure brackets")
    contains(details, "2 bracketed sequences left out because some of their photos are already in the catalog")
    contains(details, "3 single photos already in the catalog left out.")
    contains(details, "Sony: 3 exposure brackets")
end

function tests.import_result_reports_failures_and_next_step()
    local headline, details = Summary.importResult(plan(2, 0), {
        stacks = 2, singles = 0, photos = 5, failures = { "/p/c.ARW: file not found" }, canceled = false,
    })
    contains(headline, "Imported 5 photos as 2 stacks.")
    contains(details, "Could not import /p/c.ARW: file not found")
    contains(details, "Photo > Photo Merge > HDR")
end

function tests.import_result_when_canceled()
    local _, details = Summary.importResult(plan(2, 0), { stacks = 1, singles = 0, photos = 3, failures = {}, canceled = true })
    contains(details, "stopped before it finished")
end

return tests
