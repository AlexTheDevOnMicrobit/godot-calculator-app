#!/usr/bin/env python3
"""Packs assets/windows/icon_*.png into assets/windows/icon.ico (PNG-compressed
ICO entries, supported since Windows Vista). No dependency besides Python.

Run after tools/export_icons.gd:  python3 tools/make_ico.py
"""
import struct
from pathlib import Path

DIR = Path(__file__).resolve().parent.parent / "assets" / "windows"
SIZES = [16, 32, 48, 64, 128, 256]

images = [(size, (DIR / f"icon_{size}.png").read_bytes()) for size in SIZES]
header = struct.pack("<HHH", 0, 1, len(images))
offset = 6 + 16 * len(images)
entries, data = b"", b""
for size, png in images:
    dim = 0 if size >= 256 else size  # 0 means 256 in the ICO format
    entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(png), offset + len(data))
    data += png
(DIR / "icon.ico").write_bytes(header + entries + data)
print("wrote", DIR / "icon.ico", len(header + entries + data), "bytes")
