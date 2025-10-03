import pytest

import group_sony_bracketed_photos as grouping


def setup_group_mapping(files, start_ev=0):
    """
    Produce a mapping for a group where EVs are symmetric around 0 if possible.
    files: list of file paths (ordered).
    Returns mapping for FakeExifToolHelper.
    """
    mapping = {}
    n = len(files)
    # choose EVs: if n odd, symmetrical around 0
    center = n // 2
    evs = [i - center for i in range(n)]
    for idx, f in enumerate(files, start=1):
        mapping[f] = {
            "SourceFile": f,
            "EXIF:Make": "SONY",
            "EXIF:DateTimeOriginal": f"2025:10:02 12:00:{idx:02d}",
            "EXIF:ExposureMode": 2,
            "EXIF:ExposureCompensation": evs[idx - 1],
            "MakerNotes:ReleaseMode": 5,
            "MakerNotes:SequenceImageNumber": idx,
            "MakerNotes:SequenceLength": n,
        }
    return mapping


def test_grouping_main_creates_groups_file(tmp_path, monkeypatch, create_files, FakeExifToolHelper_cls):
    # Prepare group of 3
    g1 = create_files(["DSC1001.ARW", "DSC1002.ARW", "DSC1003.ARW"])
    # Prepare group of 5
    g2 = create_files(["DSC2001.ARW", "DSC2002.ARW", "DSC2003.ARW", "DSC2004.ARW", "DSC2005.ARW"])
    # Extra files that are not bracket sequences (should be ignored in final groups)
    extras = create_files(["OTHER1.ARW", "OTHER2.ARW"])

    mapping = {}
    mapping.update(setup_group_mapping(g1))
    mapping.update(setup_group_mapping(g2))
    # Extras: mark them as SONY but SequenceLength == 1 (so not treated as bracket)
    for idx, f in enumerate(extras, start=1):
        mapping[f] = {
            "SourceFile": f,
            "EXIF:Make": "SONY",
            "EXIF:DateTimeOriginal": f"2025:10:02 12:05:{idx:02d}",
            "EXIF:ExposureMode": 2,
            "EXIF:ExposureCompensation": 0,
            "MakerNotes:ReleaseMode": 0,
            "MakerNotes:SequenceImageNumber": 1,
            "MakerNotes:SequenceLength": 1,
        }

    # Patch ExifToolHelper in grouping module
    monkeypatch.setattr(
        grouping,
        "ExifToolHelper",
        lambda mapping=mapping: FakeExifToolHelper_cls(mapping),
    )

    out_file = tmp_path / "groups.txt"
    # Simulate CLI args
    monkeypatch.setattr("sys.argv", ["prog", "--input", str(tmp_path), "--output", str(out_file)])
    grouping.main()

    assert out_file.exists()
    lines = out_file.read_text(encoding="utf-8").splitlines()

    # Parse groups: split by '#group' markers and collect group sizes
    groups = []
    current = []
    for line in lines:
        if line.strip() == "#group":
            if current:
                groups.append(current)
            current = []
        else:
            current.append(line.strip())
    if current:
        groups.append(current)

    sizes = sorted([len(g) for g in groups])
    assert sizes == [3, 5]  # one group of 3 and one group of 5 should be present
    # ensure the groups file contains known filenames and does NOT contain extras
    content = "\n".join(lines)
    assert "DSC1001.ARW" in content
    assert "DSC2005.ARW" in content
    assert "OTHER1.ARW" not in content
    assert "OTHER2.ARW" not in content


def test_grouping_skips_non_sony(tmp_path, monkeypatch, create_files, FakeExifToolHelper_cls):
    # Create a non-SONY file; the script should exit with SystemExit
    files = create_files(["X1.ARW"])
    mapping = {
        files[0]: {
            "SourceFile": files[0],
            "EXIF:Make": "CANON",  # not SONY
            "EXIF:DateTimeOriginal": "2025:10:02 12:00:00",
            "EXIF:ExposureMode": 2,
            "EXIF:ExposureCompensation": 0,
            "MakerNotes:ReleaseMode": 5,
            "MakerNotes:SequenceImageNumber": 1,
            "MakerNotes:SequenceLength": 1,
        }
    }
    monkeypatch.setattr(grouping, "ExifToolHelper", lambda mapping=mapping: FakeExifToolHelper_cls(mapping))
    out_file = tmp_path / "outgroups.txt"
    monkeypatch.setattr("sys.argv", ["prog", "--input", str(tmp_path), "--output", str(out_file)])
    with pytest.raises(SystemExit):
        grouping.main()
