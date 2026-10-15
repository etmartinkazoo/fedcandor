#!/usr/bin/env python3
"""Build public/fonts/fc-icons.woff: just the Nerd Font icon glyphs the site uses.

Scans src/ for Private Use Area characters (plus a few symbols like the power
sign) and subsets 0xProto Nerd Font to those, so the site needn't ship the
full ~2 MB font. Re-run after adding icons:

    pip install fonttools
    python3 scripts/subset-icons.py [path/to/0xProtoNerdFont-Regular.ttf]
"""
import pathlib
import sys

from fontTools import subset

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "public" / "fonts" / "fc-icons.woff"
DEFAULT_FONT = pathlib.Path.home() / ".local/share/fonts/0xProto/0xProtoNerdFont-Regular.ttf"
EXTRA = {0x23FB}  # ⏻ power symbol


def is_icon(cp: int) -> bool:
    return 0xE000 <= cp <= 0xF8FF or 0xF0000 <= cp <= 0xFFFFD or cp in EXTRA


codepoints = set()
for path in SRC.rglob("*"):
    if path.suffix in {".astro", ".md", ".ts", ".css"}:
        codepoints.update(ord(c) for c in path.read_text(encoding="utf-8") if is_icon(ord(c)))

font = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_FONT
options = subset.Options()
options.flavor = "woff"
options.layout_features = []
options.name_IDs = ["*"]  # keep copyright/license names (OFL)
options.notdef_outline = True

f = subset.load_font(str(font), options)
s = subset.Subsetter(options)
s.populate(unicodes=sorted(codepoints))
s.subset(f)
subset.save_font(f, str(OUT), options)
print(f"{len(codepoints)} glyphs -> {OUT.relative_to(ROOT)} ({OUT.stat().st_size} bytes)")
