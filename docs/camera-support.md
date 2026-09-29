# Camera support

Which cameras the plugin can group, based on the metadata each camera writes, and how much of that is backed by
real test data.

- **Expected**: what the camera's metadata makes possible, from exiftool's tag documentation and the samples below.
- **Test data**: fixtures in [tests/fixtures/](../tests/fixtures/). *Real* sets are the camera's own metadata;
  *derived* sets keep every bracket tag but replace file names and dates, because the originals may not be
  redistributed; *negatives* are frames that must not be grouped.
- **Validated**: *Fixtures* when the grouping passes that brand's fixture tests; *Lightroom* when a full import
  has been checked in Lightroom with real photos; *Synthetic only* when only tests built from exiftool's
  documentation cover it.

| Camera | Expected | Test data | Validated |
|---|---|---|---|
| **Sony** Alpha, ZV, RX | Exposure brackets: kind, length and position are all tagged. White-balance and DRO brackets are tagged separately. Focus brackets (A7C II): tagged like a Single Bracket, told apart by EXIF exposure mode; length and position tagged, but the length is one byte (a 299-shot bracket reads 43). | Real: A7C II (S, M, A and P mode, base compensation, both orders, back to back, stopped brackets; focus brackets of 4, 5, 9, 10 and 258 shots; WB and DRO brackets; self-timer bursts), RX100 VII (A, P, S and M mode, base compensation, 9 frames at 0.3 EV; bursts, WB and DRO brackets; RAW+JPEG), ZV-1 (stopped Single Bracket; RAW+JPEG). Negatives: A7 IV, A7R V, A6700, ZV-E1 burst. | Exposure brackets: Fixtures; Lightroom (import and cleanup, macOS). Focus brackets: Fixtures (A7C II). |
| **Canon** EOS DSLR and R-series | Exposure brackets: flagged on every frame; the length is a camera setting on mid and pro bodies; the position has to be inferred from the EV pattern and timing. Focus brackets: flagged, with the frame count on newer R bodies. | Real: EOS Rebel T8i (CR3), 6D, 450D, 1D Mark IV (3 and 7 frames). Derived: 70D (three brackets back to back), 1D Mark II. Negatives: 16 bodies including R, RP, R5, R6 Mark II, R7, R8, R10. No R-series bracket yet. | Exposure brackets: Fixtures |
| **Canon** PowerShot (older) | Exposure brackets: only an on/off flag and the EV offset. | One single frame (G1 X Mark III), one 400D frame. | Synthetic only |
| **Nikon** DSLR | Exposure brackets: flagged per frame with the EV offset; no length on older bodies; order from the shutter count. | Real: D80, D7000; D5200 exported without maker notes. Negative: D7100 manual series. | Exposure brackets: Fixtures |
| **Nikon** Z | As DSLR; Z 8, Z 9 and Z 6III also record the bracket length. Focus shift: an on/off flag. | Negatives: Z 6, Z 8. | Negatives only |
| **Fujifilm** X | Exposure brackets: an on/off flag and probably the position; no length. Focus brackets: no known tag. | Negatives: X-S10, X-T3 (derived). | Synthetic only |
| **OM System / Olympus** | Brackets: kind and position tagged, length not. Focus brackets tagged; the camera's own stacked result is marked. | One focus-bracket frame, two camera-made focus stacks. Negatives: E-M5 Mark III, OM-5 Mark II. | Synthetic only |
| **Panasonic** Lumix | Kind, length and position all tagged, for exposure and focus brackets. | Real: DMC-TZ3; DMC-G1 (two incomplete 7-frame sets). Negatives: DC-G9. | Exposure brackets: Fixtures. Focus brackets: synthetic only |
| **Pentax** | Newer bodies: only the EV step, so frames are grouped by shutter count and timing. Older bodies (K10D to K-5) also tag the position and length. | Derived: K-50. Negatives: K-1, KP, K-3 Mark III. | Exposure brackets: Fixtures |

Panoramas shot by hand carry no sequence metadata on any camera, so they cannot be grouped this way.

## Wanted

Complete bracketed sequences, straight from the camera, for:

- Fujifilm X-series: exposure and focus brackets
- OM System / Olympus: exposure brackets and a complete focus bracket
- Canon R-series: exposure and focus brackets
- Nikon Z: exposure brackets and a focus-shift sequence
- Pentax: any exposure bracket
- Panasonic Lumix: focus bracket or Post Focus
- Any brand: brackets of 5 or more frames; white-balance, DRO or ISO brackets; fast bursts
