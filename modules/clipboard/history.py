"""Local clipboard history for the Omashell picker (no daemon or pip dependencies)."""

import base64
import hashlib
import json
import os
from pathlib import Path
import signal
import sqlite3
import struct
import subprocess
import sys
from contextlib import closing, contextmanager
from urllib.parse import unquote, urlsplit

TEXT = "text/plain;charset=utf-8"
FILES = "text/uri-list"
IMAGE = "image/png"
WATCH_TYPES = ("text", FILES, IMAGE)
MAX_ENTRIES = 100
MAX_BYTES = 32 * 1024 * 1024
MAX_TEXT = 512 * 1024
MAX_IMAGE = 8 * 1024 * 1024
PREVIEW_CHARS = 8192


@contextmanager
def database():
    base = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
    directory = base / "omashell" / "clipboard"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    path = directory / "history.sqlite3"
    # The CLI uses a private umask for both the database and SQLite journal.
    with closing(sqlite3.connect(path, timeout=4)) as db, db:
        db.execute("PRAGMA secure_delete = ON")
        db.execute("""CREATE TABLE IF NOT EXISTS entry (
            id INTEGER PRIMARY KEY AUTOINCREMENT, digest BLOB UNIQUE NOT NULL,
            mime TEXT NOT NULL, payload BLOB NOT NULL, preview TEXT NOT NULL
        )""")
        yield db


def file_preview(text):
    paths = []
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        try:
            uri = urlsplit(line)
        except ValueError:
            uri = None
        if uri and uri.scheme == "file" and uri.netloc in ("", "localhost"):
            paths.append(unquote(uri.path))
        else:
            paths.append(line)
    return "\n".join(paths) or text


def record(db, kind, data):
    if kind == IMAGE:
        if not (24 <= len(data) <= MAX_IMAGE and data.startswith(b"\x89PNG\r\n\x1a\n")
                and data[12:16] == b"IHDR"):
            return False
        width, height = struct.unpack(">II", data[16:24])
        if not (width and height and width * height <= 40_000_000):
            return False
        mime, preview = IMAGE, "PNG image"
    else:
        if not data or len(data) > MAX_TEXT:
            return False
        encoding = "utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8"
        text = data.decode(encoding, errors="replace")
        if not text.strip() or "\x00" in text:
            return False
        mime = FILES if kind == FILES else TEXT
        # Keep URI-list bytes intact for file-manager paste.
        if mime == TEXT:
            data = text.encode("utf-8")
            if len(data) > MAX_TEXT:
                return False
        preview = (file_preview(text[:PREVIEW_CHARS]) if mime == FILES else text)[:PREVIEW_CHARS]

    digest = hashlib.sha256(mime.encode() + b"\0" + data).digest()
    if db.execute("SELECT digest FROM entry ORDER BY id DESC LIMIT 1").fetchone() == (digest,):
        return False
    db.execute("INSERT OR REPLACE INTO entry (digest, mime, payload, preview) VALUES (?, ?, ?, ?)",
               (digest, mime, data, preview))
    db.execute("""DELETE FROM entry WHERE id IN (
        SELECT id FROM (SELECT id, row_number() OVER recent AS count,
          sum(length(payload)) OVER recent AS bytes FROM entry
          WINDOW recent AS (ORDER BY id DESC)) WHERE count > ? OR bytes > ?
    )""", (MAX_ENTRIES, MAX_BYTES))
    return True


def capture(kind):
    if os.environ.get("CLIPBOARD_STATE", "data") != "data":
        return
    offered = os.environ.get("CLIPBOARD_TYPE")
    if kind == "text" and offered == FILES:
        return  # The exact-MIME watcher handles this offer.
    if not offered:
        # Older wl-clipboard does not expose the chosen MIME to its callback.
        types = subprocess.run(["wl-paste", "--list-types"], capture_output=True, timeout=2, check=True)
        available = types.stdout.splitlines()
        if b"x-kde-passwordManagerHint" in available or (kind == "text" and FILES.encode() in available):
            return
    signal.signal(signal.SIGALRM, lambda *_: sys.exit(0))
    signal.alarm(3)
    limit = MAX_IMAGE if kind == IMAGE else MAX_TEXT
    payload = sys.stdin.buffer.read(limit + 1)
    signal.alarm(0)
    with database() as db:
        # Serialize concurrent callbacks (including two MIME types for one offer).
        db.execute("BEGIN IMMEDIATE")
        changed = record(db, kind, payload)
    if changed:
        print("changed", flush=True)


def main(action, *args):
    os.umask(0o077)
    if action == "watch" and args[0] in WATCH_TYPES:
        # Tie wl-paste to this shell instance, even on a crash; no global pkill.
        import ctypes

        parent = os.getppid()
        if ctypes.CDLL(None).prctl(1, signal.SIGTERM, 0, 0, 0) != 0 or parent == 1 or os.getppid() != parent:
            raise RuntimeError("could not bind watcher lifetime to the shell")
        os.execvp("wl-paste", ["wl-paste", "--type", args[0], "--watch",
                               sys.executable, __file__, "capture", args[0]])
    if action == "capture" and args[0] in WATCH_TYPES:
        capture(args[0])
        return
    if action == "paste":
        # Shift+Insert mirrors the reference picker. Copy-only still works
        # when wtype is missing or the target doesn't handle that shortcut.
        try:
            subprocess.run(["wtype", "-s", "150", "-M", "shift", "-k", "Insert", "-m", "shift"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=2)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass
        return
    with database() as db:
        if action == "list":
            rows = db.execute("SELECT id, mime, preview FROM entry ORDER BY id DESC")
            print(json.dumps([{"id": str(key), "mime": mime, "preview": preview} for key, mime, preview in rows]))
            return
        if action == "clear":
            db.execute("DELETE FROM entry")
            return
        key = int(args[0])
        if action == "delete":
            db.execute("DELETE FROM entry WHERE id = ?", (key,))
            return
        entry = db.execute("SELECT mime, payload FROM entry WHERE id = ?", (key,)).fetchone()
    if entry is None:
        raise ValueError("entry no longer exists")
    mime, payload = entry
    if action == "preview" and mime == IMAGE:
        print("data:image/png;base64," + base64.b64encode(payload).decode("ascii"))
    elif action == "copy":
        subprocess.run(["wl-copy", "--type", mime], input=payload, check=True, timeout=4,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        raise ValueError("invalid action")


if __name__ == "__main__":
    try:
        main(*sys.argv[1:])
    except (ValueError, OSError, RuntimeError, sqlite3.Error, subprocess.SubprocessError):
        # Never include clipboard content in shell logs.
        sys.exit("omashell clipboard: operation failed")
