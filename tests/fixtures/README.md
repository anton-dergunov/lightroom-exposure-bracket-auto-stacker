# Camera metadata fixtures

Each file here describes a set of real photos by their metadata only, with no image data: which camera took them, how the
camera tagged them, and which of them belong to the same bracketed sequence. They are the ground truth the grouping
logic is tested against.

## Format

```json
{
  "id": "canon-eos-6d-peter",
  "kind": "exposure",
  "complete": true,
  "exiftool": "12.97",
  "source": {"url": "...", "license": "CC0 1.0", "author": "...", "files": {"IMG_1.CR2": "..."}},
  "groups": [["20240507_MG_2373.CR2", "20240507_MG_2374.CR2", "20240507_MG_2375.CR2"]],
  "notes": "What this fixture shows and why it is here.",
  "frames": [{"System:FileName": "20240507_MG_2373.CR2", "Canon:BracketMode": 1, "...": "..."}]
}
```

- `kind`: `exposure` or `focus` for a camera-made sequence, `none` for negatives (frames that must not be grouped).
- `complete`: `false` when some frames of a sequence were never published.
- `groups`: the true grouping, labelled by hand. Each group lists two or more file names in shot order. Frames that
  belong to no group are left out.
- `expected`: optional. What the plugin should find when that differs from `groups`, for example when an editor
  stripped the maker notes (`nikon-d5200-no-makernotes`). The Lua tests compare against `expected` if present,
  otherwise `groups`.
- `source.files`: optional per-file links when the source has one page per photo.
- `derived`: present when the originals' license does not allow redistribution (non-commercial or all rights
  reserved). File names, dates and shutter counts are replaced; times of day, intervals and every bracket tag are
  kept as the camera wrote them. The field says exactly what was changed.
- `frames`: exiftool output (`-j -n -G1 -a`), keeping only the tags in [tags.args](tags.args). Keys are
  `Group:Tag`, because the same tag often appears in several groups (for example `ExifIFD:ExposureCompensation` and
  `Canon:ExposureCompensation`). Values are numeric (`-n`); exiftool's tag documentation explains them.

## Adding a fixture

1. Shoot or find a complete sequence. Only use photos you took yourself, or ones published under an open license
   (CC0, CC BY, CC BY-SA or public domain). Straight-from-camera files are needed: exports from Lightroom or
   Photoshop usually lose the maker notes.
2. Run `tests/fixtures/make-fixture.sh <id> <photos...> > tests/fixtures/<brand>/<id>.json`.
3. Fill in `kind`, `source`, `groups` and `notes`.

The tag list in `tags.args` is what keeps serial numbers, owner names, GPS and file paths out: nothing else is
stored. If your camera records its bracket in a tag that is not listed, add it to `tags.args` first.

## Running the tests

```sh
lua tests/lua/run.lua tests/fixtures/*/*.json tests/lua/test_*.lua
```

The grouping code must stay compatible with Lua 5.1, the version Lightroom runs; CI tests it on 5.1.

## Photos for testing in Lightroom

A few of the owner's own sequences, as the original RAW and JPEG files, are published as the `test-photos-v1`
release rather than committed. `tests/photos/fetch.sh` downloads and unpacks them into `tests/photos/`. They match
the `sony-a7c-ii-greenwich` and `sony-zv-1-chiltern` fixtures frame for frame.

## Coverage

| Brand | Complete sequences | Negatives and edge cases |
|---|---|---|
| Canon | 8 exposure brackets (EOS Rebel T8i CR3; 6D, 450D, 1D Mark IV CR2); derived: 70D (three back to back), 1D Mark II ×2 | manual series, interval series, 16 bodies with bracketing off, single AEB frames |
| Nikon | 3 exposure brackets (D80, D7000, D5200 without maker notes) | manual EV series that looks like a bracket, Z 6, Z 8 |
| Panasonic | 1 exposure bracket (DMC-TZ3), 2 partial 7-frame brackets (DMC-G1) | DC-G9 same-second frames |
| Olympus / OM System | none: 1 focus-bracket frame and 2 camera-made focus stacks | E-M5 Mark III, OM-5 Mark II |
| Fujifilm | none | X-S10, X-T3 (derived) |
| Pentax | derived: K-50 | K-1, KP, consecutive K-3 Mark III frames |
| Sony | 2 exposure brackets shot RAW+JPEG (A7C II, ZV-1) | A7 IV, A7R V, A6700, ZV-E1 continuous burst |
