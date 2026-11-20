import base64
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

MODULE = Path(__file__).resolve().parents[2] / "modules/clipboard"
sys.path.insert(0, str(MODULE))
import history

PNG = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRhoAAAAASUVORK5CYII=")


class ClipboardHistoryTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.base = Path(tmp.name)
        self.env = {
            **os.environ, "XDG_STATE_HOME": tmp.name, "CLIPBOARD_TYPE": "text/plain", "CLIPBOARD_STATE": "data",
            "PATH": tmp.name + os.pathsep + os.environ["PATH"], "COPY_OUTPUT": str(self.base / "copied"),
        }

    def cli(self, *args, data=b"", **env):
        return subprocess.run([sys.executable, str(MODULE / "history.py"), *args],
                              env={**self.env, **env}, input=data, capture_output=True, check=True, timeout=8).stdout

    def rows(self):
        return json.loads(self.cli("list"))

    def restore(self, key):
        mock_copy = self.base / "wl-copy"
        mock_copy.write_text('#!/bin/sh\nprintf "%s\\n" "$2" > "$COPY_OUTPUT"\ncat >> "$COPY_OUTPUT"\n')
        mock_copy.chmod(0o700)
        self.cli("copy", key)
        return (self.base / "copied").read_bytes()

    def test_text_round_trip_and_deduplication(self):
        text = "  café\n<em>literal</em>\n\n".encode()
        self.cli("capture", "text", data=text)
        self.cli("capture", "text", data=b"second")
        self.cli("capture", "text", data=text)
        self.assertEqual([row["preview"].encode() for row in self.rows()], [text, b"second"])
        key = self.rows()[0]["id"]
        self.assertEqual(self.cli("capture", "text", data=text), b"")
        self.assertEqual(self.rows()[0]["id"], key)
        self.assertEqual(self.restore(key), history.TEXT.encode() + b"\n" + text)
        db = self.base / "omashell/clipboard/history.sqlite3"
        self.assertEqual(stat.S_IMODE(db.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(db.parent.stat().st_mode), 0o700)

    def test_png_and_file_list_keep_original_bytes(self):
        uris = b"file:///tmp/A%20file.txt\r\nfile:///tmp/B.txt\r\n"
        self.cli("capture", "text", data=uris, CLIPBOARD_TYPE=history.FILES)
        self.cli("capture", history.FILES, data=uris, CLIPBOARD_TYPE=history.FILES)
        self.cli("capture", history.IMAGE, data=PNG, CLIPBOARD_TYPE=history.IMAGE)
        image, files = self.rows()
        self.assertEqual(files["preview"], "/tmp/A file.txt\n/tmp/B.txt")
        self.assertEqual(self.restore(files["id"]), b"text/uri-list\n" + uris)
        self.assertEqual(self.cli("preview", image["id"]).strip(), b"data:image/png;base64," + base64.b64encode(PNG))
        self.assertEqual(self.restore(image["id"]), b"image/png\n" + PNG)

    def test_sensitive_blank_and_oversize_offers_are_not_kept(self):
        self.cli("capture", "text", data=b"a secret", CLIPBOARD_STATE="sensitive")
        self.cli("capture", "text", data=b"   \n")
        self.cli("capture", "text", data=b"X" * (history.MAX_TEXT + 1))
        self.cli("capture", history.IMAGE, data=b"not a PNG")
        self.assertEqual(self.rows(), [])

    def test_legacy_sensitive_hint_is_not_kept(self):
        mock_paste = self.base / "wl-paste"
        mock_paste.write_text('#!/bin/sh\nprintf "x-kde-passwordManagerHint\\ntext/plain\\n"\n')
        mock_paste.chmod(0o700)
        self.cli("capture", "text", data=b"a secret", CLIPBOARD_TYPE="")
        self.assertEqual(self.rows(), [])

    def test_delete_and_clear_use_stable_ids(self):
        self.cli("capture", "text", data=b"first")
        key = self.rows()[0]["id"]
        self.cli("capture", "text", data=b"second")
        self.cli("delete", key)
        self.assertEqual([row["preview"] for row in self.rows()], ["second"])
        self.cli("clear")
        self.assertEqual(self.rows(), [])

    def test_count_and_byte_budgets_keep_newest(self):
        with patch.dict(os.environ, self.env), history.database() as db:
            with patch.object(history, "MAX_ENTRIES", 2), patch.object(history, "MAX_BYTES", 10):
                for value in (b"one", b"two", b"three"):
                    history.record(db, "text", value)
                self.assertEqual(db.execute("SELECT payload FROM entry ORDER BY id").fetchall(), [(b"two",), (b"three",)])
                history.record(db, "text", b"12345678")
                self.assertEqual(db.execute("SELECT payload FROM entry").fetchall(), [(b"12345678",)])


if __name__ == "__main__":
    unittest.main()
