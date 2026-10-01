"""Download only the Web templates from the official release ZIP using HTTP ranges.

No dependencies. Files stay under .tools/ instead of modifying a global Godot install.
"""
from __future__ import annotations

import io
from pathlib import Path
import urllib.request
import zipfile

VERSION = "4.7.2"
ROOT = Path(__file__).resolve().parents[1]
URL = (
    "https://github.com/godotengine/godot-builds/releases/download/"
    f"{VERSION}-stable/Godot_v{VERSION}-stable_export_templates.tpz"
)


class RemoteZip(io.RawIOBase):
    def __init__(self, url: str):
        request = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(request, timeout=30) as response:
            self.url = response.url
            self.length = int(response.headers["Content-Length"])
        self.position = 0

    def seekable(self):
        return True

    def readable(self):
        return True

    def tell(self):
        return self.position

    def seek(self, offset, whence=0):
        base = [0, self.position, self.length][whence]
        self.position = base + offset
        return self.position

    def read(self, size=-1):
        size = self.length - self.position if size < 0 else size
        size = min(size, self.length - self.position)
        if size <= 0:
            return b""
        end = self.position + size - 1
        request = urllib.request.Request(
            self.url, headers={"Range": f"bytes={self.position}-{end}"}
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            if response.status != 206:
                raise RuntimeError("Server must support byte ranges; use Godot's template manager.")
            data = response.read()
        if len(data) != size:
            raise RuntimeError(f"Unexpected range length: {len(data)} vs {size}")
        self.position += len(data)
        return data


def main():
    destination = ROOT / ".tools/templates"
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(RemoteZip(URL)) as archive:
        names = [
            name for name in archive.namelist()
            if Path(name).name in {"web_nothreads_debug.zip", "web_nothreads_release.zip"}
        ]
        for name in names:
            target = destination / Path(name).name
            if target.exists() and zipfile.is_zipfile(target):
                print("Already available:", target.name, flush=True)
                continue
            print("Downloading", name, flush=True)
            target.write_bytes(archive.read(name))
            print("Saved", target.name, target.stat().st_size, "bytes", flush=True)
    if not names:
        raise RuntimeError("No Web templates found in official release.")


if __name__ == "__main__":
    main()
