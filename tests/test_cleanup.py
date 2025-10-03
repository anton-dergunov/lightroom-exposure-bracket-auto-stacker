import os

import cleanup_sony_bracketed_photos as cleanup


def setup_mapping_for_group(files, evs):
    """
    Helper to build a metadata mapping for a group.
    evs: list of exposure compensation values (same length as files)
    Returns mapping dict for FakeExifToolHelper.
    """
    mapping = {}
    length = len(files)
    for idx, f in enumerate(files, start=1):
        mapping[f] = {
            "SourceFile": f,
            "MakerNotes:SequenceLength": length,
            "MakerNotes:SequenceImageNumber": idx,
            "EXIF:ExposureCompensation": evs[idx - 1],
        }
    return mapping


def test_detect_and_move_group(tmp_path, monkeypatch, create_files, FakeExifToolHelper_cls):
    # Arrange: three files in a group (sequence length 3)
    files = create_files(["DSC0001.ARW", "DSC0002.ARW", "DSC0003.ARW"])
    # create HDR file (so expected_hdr_file finds it)
    (tmp_path / "DSC0001-HDR.dng").write_bytes(b"hdr")

    mapping = setup_mapping_for_group(files, [-1, 0, 1])

    # Monkeypatch ExifToolHelper in the cleanup module to use our fake mapping
    monkeypatch.setattr(
        cleanup,
        "ExifToolHelper",
        lambda mapping=mapping: FakeExifToolHelper_cls(mapping),
    )

    # Load metadata (this uses the patched ExifToolHelper under the hood)
    metadata = cleanup.load_metadata(files)

    # Detect properly exposed (middle exposure should be chosen)
    keep = cleanup.detect_properly_exposed(files, metadata)
    assert keep == files[1]

    # Dry-run move: should report the two redundant files (but not move)
    safety_dir = os.path.join(os.path.dirname(files[0]), "_over_under_exposed")
    assert not os.path.exists(safety_dir)

    moved = cleanup.move_or_delete_files(files, keep, action="move", safety_dir=safety_dir, dry_run=True)
    expected = [f for f in files if f != keep]
    assert set(moved) == set(expected)
    assert not os.path.exists(safety_dir)  # nothing moved on dry-run

    # Actual move
    moved_real = cleanup.move_or_delete_files(files, keep, action="move", safety_dir=safety_dir, dry_run=False)
    # non-kept files should be moved to safety dir
    dests = [os.path.join(safety_dir, os.path.basename(f)) for f in files if f != keep]
    for dest in dests:
        assert os.path.exists(dest)
    # keep remains in original place
    assert os.path.exists(keep)
    # moved_real should contain the original paths that were processed
    assert set(moved_real) == set(expected)


def test_delete_action(tmp_path, monkeypatch, create_files, FakeExifToolHelper_cls):
    # Arrange: three files in a group (sequence length 3)
    files = create_files(["A1.ARW", "A2.ARW", "A3.ARW"])
    (tmp_path / "A1-HDR.dng").write_bytes(b"hdr")

    mapping = setup_mapping_for_group(files, [-1, 0, 1])
    monkeypatch.setattr(
        cleanup,
        "ExifToolHelper",
        lambda mapping=mapping: FakeExifToolHelper_cls(mapping),
    )

    metadata = cleanup.load_metadata(files)
    keep = cleanup.detect_properly_exposed(files, metadata)
    assert keep == files[1]

    safety_dir = os.path.join(os.path.dirname(files[0]), "_over_under_exposed")
    removed = cleanup.move_or_delete_files(files, keep, action="delete", safety_dir=safety_dir, dry_run=False)

    # The two others should be removed
    assert not os.path.exists(files[0])
    assert not os.path.exists(files[2])
    # kept file remains
    assert os.path.exists(keep)
    assert len(removed) == 2


def test_all_mode_removes_everything(tmp_path, monkeypatch, create_files, FakeExifToolHelper_cls):
    # "all" mode: remove (or move) every file in the group if HDR exists.
    files = create_files(["B1.ARW", "B2.ARW", "B3.ARW"])
    (tmp_path / "B1-HDR.dng").write_bytes(b"hdr")

    mapping = setup_mapping_for_group(files, [-1, 0, 1])
    monkeypatch.setattr(
        cleanup,
        "ExifToolHelper",
        lambda mapping=mapping: FakeExifToolHelper_cls(mapping),
    )

    # Dry-run deleting everything
    safety_dir = os.path.join(os.path.dirname(files[0]), "_over_under_exposed")
    moved = cleanup.move_or_delete_files(files, keep_file=None, action="delete", safety_dir=safety_dir, dry_run=True)
    assert set(moved) == set(files)

    # Actual delete
    removed = cleanup.move_or_delete_files(files, keep_file=None, action="delete", safety_dir=safety_dir, dry_run=False)
    for f in files:
        assert not os.path.exists(f)
    assert len(removed) == 3
