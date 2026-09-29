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

   *Done (2026-09-29).* `Grouping.lua` and `Vendors.lua` cover Sony, Canon, Nikon, Panasonic, Pentax, OM System /
   Olympus and Fujifilm. `tests/lua/run.lua` checks every fixture plus synthetic cases for rules without real test
   data; CI runs it on Lua 5.1. Found along the way: `SubSecTime` belongs to the modification time, so only
   `SubSecTimeOriginal` is used; Sony's Single Bracket mode reports a sequence length of 1.
2. **exiftool inside the plugin.** Bundle exiftool 13.x with its license (the Windows build includes its own Perl;
   on macOS it uses the Perl that ships with the system). Run it once per folder with
   `-j -n -G1 -a -r -@ tags.args`, writing to a temporary file. Handle Windows quoting, missing files and exiftool
   errors.

   *Done (2026-09-29).* `tools/fetch-exiftool.sh` downloads exiftool 13.59 (checksums pinned) into the plugin's
   `exiftool/` folder, which git ignores; a plugin release zip will include it. `ExifToolCommand.lua` builds the
   command (folder and options go through a temporary argument file, so unusual paths survive), `ExifTool.lua` runs
   it inside Lightroom, and `Summary.lua` writes the result text, including the request for sample photos. The
   tag list moved to the plugin (`auto-stacker.lrdevplugin/tags.args`). A new menu item, *Preview Brackets in
   Folder…*, reports what would be stacked without importing. `tests/lua/test_photos.lua` runs the same command on
   the test photos and matches the fixtures. Checked in Lightroom Classic on macOS: the test photos (10 brackets
   in 34 photos) and a 364-photo folder on a network drive (122 brackets). Not yet checked on Windows.
3. **One-step import, two menu items.** The wording that differs comes first:
   - *Import Only Bracketed Photos, as Stacks…*: only frames in detected sequences (the current behaviour).
   - *Import Entire Folder, Brackets as Stacks…*: every photo; single shots are imported as normal, and photos
     already in the catalog are skipped.

   Both show a folder picker and progress, then a summary. When a brand's rules have not been tested on real photos,
   the summary says so and asks the user to share sample photos (anonymised is fine), pointing to the README's Help
   Wanted section. The `groups.txt` file goes away.

   *Done (2026-09-29), checked in Lightroom Classic on macOS* with the test photos and a network-drive folder.
   `Import.lua` runs both menu items: folder picker, metadata read,
   a confirmation with what will be imported, a cancellable progress bar, and a report ending with how to merge the
   stacks. `ImportPlan.lua` decides what to import: brackets whose photos are partly in the catalog already are
   left out whole, since Lightroom cannot add to an existing stack. Each stack has its base exposure on top (the
   middle exposure; the brighter middle frame for a bracket stopped early). `tests/lua/lightroom_fake.lua` stands
   in for the SDK so `test_lightroom_import.lua` runs the real import code on the test photos. The old
   *Import from Groups File* item stays until step 4, because the cleanup script still reads `groups.txt`.

   After the first Lightroom test: counts across subfolders (RAW/ and JPEG/) were confusing, so the confirmation
   now lists each folder when there are several. Photos a plug-in adds do not appear in Lightroom's *Previous
   Import*, and it was not obvious where they went, so after importing the plugin switches the Library to the
   folders it imported into (`catalog:setActiveSources`) and the report names them.
4. **Cleanup in the plugin.** Port "remove redundant exposures after HDR merge". First check what the SDK allows for
   removing photos from the catalog; if it cannot, document the manual step.
5. **Remove Python.** Delete the scripts, `requirements.txt` and the pytest suite (fixture checks move to Lua); CI runs
   the Lua tests only. Update the README install and usage sections.
6. **Merge trigger research.** Can the plugin start HDR merge, or can the headless Shift+Cmd+H merge be scripted? If
   not, document the shortcut prominently. Known so far:
   - The SDK cannot collapse or expand stacks, so "Collapse All Stacks" stays a manual step.
   - Selecting the stack leaders for the user is risky: if the stacks are expanded, HDR merge would combine the
     selected leaders of different scenes into one image. Only worth doing if collapsed state can be checked first
     (`photo:getRawMetadata("stackInFolderIsCollapsed")` is readable).
   - After importing, the Library already shows the imported folders; with several folders it shows all of them.
7. **Rename** the project, based on what focus-bracket support turns out to cover.
8. **Benchmark** time-based, visual-similarity and metadata grouping on labelled photos.

## Test data

- Metadata fixtures: [tests/fixtures/](../../tests/fixtures/).
- Photos for testing in Lightroom: the `test-photos-v1` release asset, downloaded with `tests/photos/fetch.sh`.
- Shoot list for missing Sony cases: [sony-test-shoot.md](sony-test-shoot.md).
