import sys
import os
import stat
import pytest

# Ensure repo root is importable so tests can `import cleanup_sony_bracketed_photos`
# even when pytest is launched without setting PYTHONPATH externally.
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))


class FakeExifToolHelper:
    """
    Fake ExifToolHelper context manager for tests.

    Usage in tests:
        monkeypatch.setattr(module, "ExifToolHelper",
                            lambda mapping=mapping: FakeExifToolHelper(mapping))
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
            md = dict(self._mapping.get(f, {}))
            md.setdefault("SourceFile", f)
            out.append(md)
        return out


@pytest.fixture
def FakeExifToolHelper_cls():
    """Return the FakeExifToolHelper class (so tests can bind it with mapping)."""
    return FakeExifToolHelper


@pytest.fixture
def create_files(tmp_path):
    """
    Returns a factory function that writes empty files in the tmp_path and returns
    their full paths as strings.

    Usage:
        files = create_files(["A1.ARW", "A2.ARW"])
    """
    def _create(names):
        paths = []
        for name in names:
            p = tmp_path / name
            p.write_bytes(b"")  # empty file content is sufficient for these tests
            # make sure the file is readable/writable by the test user
            p.chmod(p.stat().st_mode | stat.S_IWUSR | stat.S_IRUSR)
            paths.append(str(p))
        return paths

    return _create
