# Changelog

## 1.0.0 (2026-09-29)

The plugin is now called **Bracket Stacker** (formerly Auto Stacker) and works entirely inside Lightroom Classic.
When upgrading, remove the old Auto Stacker plugin in the Plug-in Manager, add the new one and restart Lightroom.

### New

- Import and stack in one step: choose a folder and the plugin finds its bracketed sequences and imports each one as a
  stack. Nothing needs to be installed besides the plugin, and there is no separate script to run first.
- Two ways to import: **Import Only Bracketed Photos, as Stacks** for when Lightroom Classic is used only for HDR
  merging, and **Import Entire Folder, Brackets as Stacks** to import every photo with the brackets stacked.
- Canon, Nikon, Panasonic and Pentax exposure brackets are recognised, in addition to Sony. OM System / Olympus and
  Fujifilm are supported too but not yet tested on real photos; the plugin says so when it finds them and explains how
  to share sample photos.
- Focus brackets are recognised and stacked. Every stack gets the keyword *Exposure bracket* or *Focus bracket*, so
  focus stacks can be filtered out before merging HDR images, and the import can leave focus brackets out.
- Each stack has its normal exposure on top.
- Before importing, the plugin shows what it found, per folder when there are several, and asks for confirmation;
  the import can be cancelled while it runs, and the report says which folders the photos were added to. The
  Library then shows those folders.
- **Reject Extra Exposures After HDR Merge** flags the over- and under-exposed photos of merged stacks as rejected,
  so Lightroom's *Delete Rejected Photos* can remove them from the catalog or move them to the Trash.

### Improved

- Brackets are found from what the camera recorded rather than from timing, so brackets shot seconds apart stay
  separate, long exposures stay together, and brackets stopped early are recognised and reported.
- RAW and JPEG copies of the same shots are stacked separately, photos in subfolders are included, and photos
  already in the catalog are skipped.

### Removed

- The separate grouping and cleanup scripts, and the menu item that imported from their groups file.

## 0.0.1

The first version, not published as a release: a script found Sony exposure brackets and wrote them to a groups
file, which the plugin imported as stacks; a second script removed the extra exposures after HDR merging.
