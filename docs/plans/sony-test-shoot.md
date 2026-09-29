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

- [ ] **Cont. Bracket in S mode and in M mode** (any step, 3 or 5 images). The library's brackets are all from A or
      P mode; in M mode the EXIF exposure fields may look different.
- [ ] **Cont. Bracket with a base exposure compensation**, e.g. +0.7 EV, in A mode.
- [ ] **Bracket order -→0→+**: one Cont. Bracket after switching Bracket order (and switch it back afterwards).
- [ ] **Back to back**: three Cont. Brackets a few seconds apart, with one normal single shot between two of them.

## Focus brackets (should be grouped, for focus stacking outside Lightroom)

- [ ] **Focus Bracket, 5 shots** and **10 shots**, Focus Bracket Order [0→+]. Autofocus lens, tripod.
- [ ] **Focus Bracket Order [0→-→+]**: always 3 shots.
- [ ] **Focus Brckt Saving Dest [New Folder]**: one short focus bracket saved to its own folder.

exiftool may not decode Sony's focus-bracket tags yet, so these frames show what the camera actually writes.

## Not brackets (must not be grouped as exposure brackets)

- [ ] **WB bracket** Lo and Hi, and **DRO Bracket** Lo and Hi: one exposure saved as three differently processed
      images. If they are greyed out, set the file format to JPEG.
- [ ] **Self-timer(Cont)**: several frames from one release.
- ISO and flash brackets do not exist on Sony; skip.

## Other bodies

- [ ] **ZV-E10**: **MENU → Camera Settings1 → Drive Mode**: one WB bracket and one DRO Bracket.
- [ ] **RX100 VII**: **MENU → Camera Settings1 → Drive Mode**: one WB bracket and one DRO Bracket. (Its exposure
      bracket mode is called **Cont. Bracket** or **Bracket** depending on firmware.)

## Afterwards

Tell Claude the folder and the file ranges of each item; each becomes a metadata-only fixture in
`tests/fixtures/sony/`, and what each mode writes goes into [camera-support.md](../camera-support.md).
