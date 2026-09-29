# Sony test shoot

Goal: real metadata for the Sony drive modes the photo library does not already cover, so the plugin can be checked
on them: which ones to group (exposure and focus brackets) and which to leave alone (other brackets and bursts).
Main camera: A7C II.

Only the metadata of these photos goes into the repository, as fixtures, so the scene does not matter. A tripod is
only needed for the focus brackets, where camera movement would spoil a later focus stack; handheld is fine for
everything else.

## Already covered by the library scan

5- and 9-frame exposure brackets (ZV-1), Single Bracket (ZV-1, ZV-E10, A7 III), continuous bursts (ZV-E10), and
3-frame brackets from the RX100 VII, ZV-E10 and A7 III. No need to shoot these again.

## Where the settings are (A7C II)

- **Drive mode:** the Drive Mode button (left on the control wheel), or **MENU → Shooting → Drive Mode → Drive
  Mode**. Pick a mode, then press left or right on it to choose its option (for example the EV step and number of
  images of Cont. Bracket, or Lo/Hi for WB and DRO Bracket).
- **Bracket settings:** **MENU → Shooting → Drive Mode → Bracket Settings**: Selftimer during Bracket, Bracket order
  (0→-→+ or -→0→+), Focus Bracket Order ([0→+] or [0→-→+]), Exposure Smoothing, Shooting Interval, Focus Brckt
  Saving Dest ([Current Folder] or [New Folder]).
- **Focus bracket step and count:** in Drive Mode, choose **Focus Bracket** and press left or right to set the step
  width (1-10); the number of shots (2-299) is set in the same place.

## Exposure brackets (must be grouped)

- [x] **Cont. Bracket in S mode and in M mode** (any step, 3 or 5 images). The library's brackets are all from A or
      P mode; in M mode the EXIF exposure fields may look different.
- [x] **Cont. Bracket with a base exposure compensation**, e.g. +0.7 EV, in A mode.
- [x] **Bracket order -→0→+**: one Cont. Bracket after switching Bracket order (and switch it back afterwards).
- [x] **Back to back**: three Cont. Brackets a few seconds apart, with one normal single shot between two of them.
      (Switching modes takes longer than a few seconds; brackets taken one after another are enough.)

## Focus brackets (should be grouped, for focus stacking outside Lightroom)

- [x] **Focus Bracket, 5 shots** and **10 shots** (also 4, 9, and 299 stopped at 258), Focus Bracket Order [0→+]. Autofocus lens, tripod.
- [x] **Focus Bracket Order [0→-→+]**: always 3 shots.
- [x] **Focus Brckt Saving Dest [New Folder]**: one short focus bracket saved to its own folder.

exiftool may not decode Sony's focus-bracket tags yet, so these frames show what the camera actually writes.

## Not brackets (must not be grouped as exposure brackets)

- [x] **WB bracket** Lo and Hi, and **DRO Bracket** Lo and Hi: one exposure saved as three differently processed
      images. If they are greyed out, set the file format to JPEG.
- [x] **Self-timer(Cont)**: several frames from one release.
- ISO and flash brackets do not exist on Sony; skip.

## Other bodies

- [ ] **ZV-E10**: **MENU → Camera Settings1 → Drive Mode**: one WB bracket and one DRO Bracket.
- [x] **RX100 VII**: **MENU → Camera Settings1 → Drive Mode**: one WB bracket and one DRO Bracket. (Its exposure
      bracket mode is called **Cont. Bracket** or **Bracket** depending on firmware.)

## Results (A7C II, 2026-09-29)

381 RAW files, now the `sony-a7c-ii-*` fixtures. What the camera writes:
- Exposure brackets: ReleaseMode 5, EXIF ExposureMode Auto bracket (2) in every exposure mode, including M.
- Focus brackets: the same drive tags as a Single Bracket (ReleaseMode 5, ReleaseMode2 23); EXIF ExposureMode is
  Auto (0) and the exposure stays the same. SequenceLength appears twice: one copy says 1, the other the number of
  shots, stored in one byte (299 reads 43).
- WB bracket ReleaseMode 6, DRO Bracket ReleaseMode 8: three images with one timestamp. Self-timer(Cont):
  ReleaseMode 2, ReleaseMode2 26.

## Results (RX100 VII, 2026-09-29)

136 files (RAW+JPEG), now the `sony-rx100-vii-*` fixtures: exposure brackets in A, P, S and M mode, with base
compensation, and 9 frames at 0.3 EV; continuous burst, Single Burst Shooting (7 frames with a sequence length of 7,
ReleaseMode3 9, not a bracket), self-timer, WB and DRO brackets. The same tags as the A7C II; nothing new needed.

A7C II follow-up (`sony-a7c-ii-focus-order-and-folders`): Focus Bracket Order [0→-→+] writes the same tags as
[0→+]. With Saving Dest [New Folder] each bracket gets its own folder (101MSDCF, 102MSDCF) and file numbers restart
at DSC00001, so folders hold files with the same names; fixtures can now keep paths relative to the card's DCIM
folder for this.

Still open: ZV-E10.

## Afterwards

Tell Claude the folder (the drive-mode tags show which frames belong to which item); each item becomes a metadata-only fixture in
`tests/fixtures/sony/`, and what each mode writes goes into [camera-support.md](../camera-support.md).
