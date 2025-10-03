import os
import shutil
import stat
import tempfile
import builtins
import importlib
import pytest

import cleanup_sony_bracketed_photos as cleanup

# A small fake ExifToolHelper to monkeypatch into modules.
class FakeExifToolHelper:
    """
    Fake ExifToolHelper context manager for tests.
    Initialize with a mapping: path -> metadata dict (with 'SourceFile' key).
    get_metadata(files) returns list-of-dicts matching files order.
    """
    def __init__(self, mapping):
        self._mapping = mapping

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def get_metadata(self, files):
        out = []
        for f in files:
            # copy to avoid accidental mutation
            md = dict(self._mapping.get(f, {}))
            if "SourceFile" not in md:
                md["SourceFile"] = f
            out.append(md)
        return out


def create_files(tmp_path, filenames):
    paths = []
    for name in filenames:
        p = tmp_path / name
        p.write_bytes(b"")  # empty file content is fine
        # ensure that file is readable/writable
        p.chmod(p.stat().st_mode | stat.S_IWUSR | stat.S_IRUSR)
        paths.append(str(p))
    return paths


def test_detect_and_move_group(tmp_path, monkeypatch):
    # Arrange: three files in a group (sequence length 3)
    files = create_files(tmp_path, ["DSC0001.ARW", "DSC0002.ARW", "DSC0003.ARW"])
    # Also create an HDR file matching the first base name (so expected_hdr_file finds it)
    hdr_path = tmp_path / "DSC0001-HDR.dng"
    hdr_path.write_bytes(b"hdr")

    # Create fake metadata mapping
    mapping = {
        files[0]: {
            "SourceFile": files[0],
            "MakerNotes:SequenceLength": 3,
            "MakerNotes:SequenceImageNumber": 1,
            "EXIF:ExposureCompensation": -1,
        },
        files[1]: {
            "SourceFile": files[1],
            "MakerNotes:SequenceLength": 3,
            "MakerNotes:SequenceImageNumber": 2,
            "EXIF:ExposureCompensation": 0,
        },
        files[2]: {
            "SourceFile": files[2],
            "MakerNotes:SequenceLength": 3,
            "MakerNotes:SequenceImageNumber": 3,
            "EXIF:ExposureCompensation": 1,
        },
    }

    # Monkeypatch the ExifToolHelper used in cleanup module
    monkeypatch.setattr(cleanup, "ExifToolHelper", lambda: FakeExifToolHelper(mapping))

    # Parse groups - emulate a groups.txt content with a single group
    groups = [files]  # groups is list of groups where each group is list of file paths

    # Test detect_properly_exposed
    keep = cleanup.detect_properly_exposed(groups[0], cleanup.load_metadata([f for g in groups for f in g]))
    assert keep == files[1]  # middle exposure (0 EV) should be chosen

    # Do a dry-run move and ensure nothing moved
    safety_dir = os.path.join(os.path.dirname(files[0]), "_over_under_exposed")
    assert not os.path.exists(safety_dir)

    moved = cleanup.move_or_delete_files(groups[0], keep, "move", safety_dir, dry_run=True)
    moved_expected = [f for f in groups[0] if f != keep]
    # move_or_delete_files returns list of files that would be processed
    assert set(moved) == set(moved_expected)
    assert not os.path.exists(safety_dir)
    # Ensure original files still exist
    for f in files:
        assert os.path.exists(f)

    # Now perform the actual move
    moved_real = cleanup.move_or_delete_files(groups[0], keep, "move", safety_dir, dry_run=False)
    # All non-kept files should be moved into safety_dir
    assert os.path.exists(safety_dir)
    dests = [os.path.join(safety_dir, os.path.basename(f)) for f in groups[0] if f != keep]
    for dest in dests:
        assert os.path.exists(dest)
    # kept file remains in place
    assert os.path.exists(keep)
    # move_or_delete_files returns list of files that were processed
    assert set(moved_real) == set(moved_expected)

def test_delete_action(tmp_path, monkeypatch):
    files = create_files(tmp_path, ["A1.ARW", "A2.ARW", "A3.ARW"])
    # create HDR for first file
    (tmp_path / "A1-HDR.dng").write_bytes(b"hdr")

    mapping = {}
    # All sequence length 3
    mapping[files[0]] = {
        "SourceFile": files[0],
        "MakerNotes:SequenceLength": 3,
        "MakerNotes:SequenceImageNumber": 1,
        "EXIF:ExposureCompensation": -1,
    }
    mapping[files[1]] = {
        "SourceFile": files[1],
        "MakerNotes:SequenceLength": 3,
        "MakerNotes:SequenceImageNumber": 2,
        "EXIF:ExposureCompensation": 0,
    }
    mapping[files[2]] = {
        "SourceFile": files[2],
        "MakerNotes:SequenceLength": 3,
        "MakerNotes:SequenceImageNumber": 3,
        "EXIF:ExposureCompensation": 1,
    }

    monkeypatch.setattr(cleanup, "ExifToolHelper", lambda: FakeExifToolHelper(mapping))

    grp = [files]
    keep = cleanup.detect_properly_exposed(grp[0], cleanup.load_metadata([f for g in grp for f in g]))
    assert keep == files[1]

    safety_dir = os.path.join(os.path.dirname(files[0]), "_over_under_exposed")
    # Delete non-kept files
    removed = cleanup.move_or_delete_files(grp[0], keep, "delete", safety_dir, dry_run=False)
    # The two others should be removed
    assert not os.path.exists(files[0])
    assert not os.path.exists(files[2])
    # kept file remains
    assert os.path.exists(keep)
    # removed list should contain two original paths
    assert len(removed) == 2
