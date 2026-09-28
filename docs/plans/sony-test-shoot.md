# Sony test shoot

Goal: real test data for every Sony drive mode the plugin has to recognise, whether it should group the
frames (exposure and focus brackets) or leave them alone (other brackets and bursts). Main camera: A7C II. The ZV-E10 and
RX100 VII repeat a few items to cover other bodies.

## Setup

- One scene, camera on a tripod or steady surface.
- File format **RAW+JPEG**, except where a step says otherwise.
- Drive modes are under the **Drive Mode** button (left on the control wheel) or **MENU → Shooting → Drive Mode**.
  Menu names below are from memory and may differ slightly by firmware.
- Note the first and last file number of each item, so the frames can be labelled afterwards.

## Exposure brackets (must be grouped)

- [ ] **Cont. Bracket, 5 frames** (e.g. 1.0EV 5), once each in **A**, **S** and **M**. In M with Auto ISO off the
      camera varies shutter speed, and the EXIF exposure fields may look different from A and S.
- [ ] **Cont. Bracket, 9 frames**, if the step size offers it.
- [ ] **Cont. Bracket with a base exposure compensation**, e.g. +0.7 EV.
- [ ] **Single Bracket, 3 frames**: one press per frame, a few seconds between presses. The gaps break time-based
      grouping.
- [ ] **Incomplete Single Bracket**: start one, stop after two presses, switch drive mode.
- [ ] **Bracket order**: under **MENU → Bracket Settings → Bracket Order**, shoot one bracket with 0→−→+ and one
      with −→0→+.
- [ ] **Back to back**: three 3-frame brackets a few seconds apart, with one normal single shot between two of
      them.

## Focus bracket (should be grouped, for focus stacking outside Lightroom)

- [ ] **Focus Bracket**, 5 frames, then 10 frames (count and step in Focus Bracket Settings). Needs an autofocus
      lens. exiftool may not decode Sony's focus-bracket tags yet, so these frames show what the camera actually
      writes.

## Not brackets (must not be grouped as exposure brackets)

- [ ] **WB Bracket** (Lo and Hi) and **DRO Bracket** (Lo and Hi): one exposure saved as three differently processed
      images. If the modes are greyed out, set File Format to JPEG.
- [ ] **Continuous Shooting, Hi**: hold the shutter for about a second.
- [ ] **Self-timer (Cont)**: several frames from one release.
- ISO and flash brackets: not available on Sony, skip.

## Other bodies

- [ ] ZV-E10 and RX100 VII: Cont. Bracket 5 frames, and one WB or DRO bracket.

## Afterwards

Tell Claude the folder and file ranges; it turns each item into a metadata-only fixture in `tests/fixtures/sony/`
and records what each mode writes in [camera-support.md](../camera-support.md). Image files are only committed
after an explicit check.
