"""Usage: python scripts/subset_font.py /path/to/NotoSansSC-VF.ttf

Optional developer tool, requires fonttools. The generated font is committed;
players and CI do not need this tool or the original 17 MB font.
Source: https://github.com/notofonts/noto-cjk/tree/main/Sans/Variable/TTF/Subset
"""
from pathlib import Path
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset

root = Path(__file__).resolve().parents[1]
text = "".join(p.read_text() for p in (root / "scripts").glob("*.gd"))
text += "".join(p.read_text() for p in (root / "launcher").glob("*.gd"))
text += (root / "data/items.json").read_text()
text += "".join(chr(c) for c in range(32, 127))
text += "关闭取消确认是否返回确定警告错误文件存档读取加载·—→▸●×…–"
font = TTFont(sys.argv[1])
instantiateVariableFont(font, {"wght": 400}, inplace=True)
options = subset.Options()
options.name_IDs = ["*"]
worker = subset.Subsetter(options=options)
worker.populate(text=text)
worker.subset(font)
names = {1: "Dungeon Sans", 4: "Dungeon Sans Regular", 6: "DungeonSans-Regular",
         16: "Dungeon Sans", 17: "Regular"}
for record in font["name"].names:
    if record.nameID in names:
        record.string = names[record.nameID].encode(record.getEncoding())
font.save(root / "assets/fonts/DungeonSans.ttf")
