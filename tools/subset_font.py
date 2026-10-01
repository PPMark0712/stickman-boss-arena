"""Rebuild the bundled UI subset. Requires fonttools; pass the original Noto Sans SC TTF."""
from pathlib import Path
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

root = Path(__file__).resolve().parents[1]
text = "".join(chr(i) for i in range(32, 127))
text += "←→↑↓■□▰▱·—"
for source in (root / "scripts").glob("*.gd"):
    text += source.read_text()
font = TTFont(sys.argv[1])
font = instantiateVariableFont(font, {"wght": 450}, inplace=True)
options = subset.Options()
options.name_IDs = ["*"]
worker = subset.Subsetter(options=options)
worker.populate(text=text)
worker.subset(font)
font.save(root / "assets/fonts/ArenaSans.ttf")
print("Saved assets/fonts/ArenaSans.ttf")
