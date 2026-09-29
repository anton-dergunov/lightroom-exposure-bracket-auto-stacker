# Restructure: one-step import without Python

## Why the plugin works this way

- A shoot produces hundreds of photos, with bracketed sequences mixed among single shots. Finding each bracket by
  hand to merge it does not scale.
- Lightroom's own grouping is time-based (Lightroom Classic's Auto-Stack by Capture Time and its newer variants). In
  testing it kept missing frames that belonged together. The camera's metadata says exactly which frames form a
  sequence, and no other tool was found that uses it.
- Lightroom's HDR merge is good, and no open-source HDR tool matched it, so merging stays in Lightroom Classic.
- The Lightroom Classic SDK can stack photos only while importing them, not photos already in the catalog. So
  grouping and stacking happen in one action: import and stack together.
- Lightroom (the cloud version) has no plugins and only time-based grouping. The intended workflow: edit in
  Lightroom, and use Lightroom Classic only for this HDR step. The goal is a few clicks from a card dump to merged
  HDRs.

## Steps

Each step is its own commit. In [camera-support.md](../camera-support.md), a brand is marked *Fixtures* when its
fixture tests pass and *Lightroom* when the full import has been checked with real photos.

1. **Grouping core in Lua.** Pure-Lua modules that take exiftool output and return the groups, driven by a table of
   camera brands and tested against every fixture. No Lightroom dependency, so the tests run with plain Lua.
2. **exiftool inside the plugin.** Bundle exiftool 13.x with its license (the Windows build includes its own Perl;
   on macOS it uses the Perl that ships with the system). Run it once per folder with
   `-j -n -G1 -a -r -@ tags.args`, writing to a temporary file. Handle Windows quoting, missing files and exiftool
   errors.
3. **One-step import, two menu items.** The wording that differs comes first:
   - *Import Only Bracketed Photos, as Stacks…*: only frames in detected sequences (the current behaviour).
   - *Import Entire Folder, Brackets as Stacks…*: every photo; single shots are imported as normal, and photos
     already in the catalog are skipped.

   Both show a folder picker and progress, then a summary. When a brand's rules have not been tested on real photos,
   the summary says so and asks the user to share sample photos (anonymised is fine), pointing to the README's Help
   Wanted section. The `groups.txt` file goes away.
4. **Cleanup in the plugin.** Port "remove redundant exposures after HDR merge". First check what the SDK allows for
   removing photos from the catalog; if it cannot, document the manual step.
5. **Remove Python.** Delete the scripts, `requirements.txt` and the pytest suite (fixture checks move to Lua); CI runs
   the Lua tests only. Update the README install and usage sections.
6. **Merge trigger research.** Can the plugin start HDR merge, or can the headless Shift+Cmd+H merge be scripted? If
   not, document the shortcut prominently.
7. **Rename** the project, based on what focus-bracket support turns out to cover.
8. **Benchmark** time-based, visual-similarity and metadata grouping on labelled photos.

## Test data

- Metadata fixtures: [tests/fixtures/](../../tests/fixtures/).
- Photos for testing in Lightroom: the `test-photos-v1` release asset, downloaded with `tests/photos/fetch.sh`.
- Shoot list for missing Sony cases: [sony-test-shoot.md](sony-test-shoot.md).
