"""Package tested exports and emit the public update manifest (no credentials)."""
import hashlib
import json
import re
import sys
import zipfile
from pathlib import Path

VERSION_PATTERN = r"(?:0|[1-9][0-9]{0,8})\.(?:0|[1-9][0-9]{0,8})\.(?:0|[1-9][0-9]{0,8})"
GAME_FILES = ["toy-dg.exe", "THIRD_PARTY_NOTICES.md", "OFL.txt"]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def package(version, commit, root=Path(".")):
    if not re.fullmatch(VERSION_PATTERN, version):
        raise ValueError("Invalid release version")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Expected exact source commit")
    target = root / "build/release"
    target.mkdir(parents=True, exist_ok=True)
    records = []
    with zipfile.ZipFile(target / "toy-dg-windows.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for name in GAME_FILES:
            path = root / "build/windows" / name
            if not path.is_file() or not path.stat().st_size:
                raise ValueError(f"Missing export: {name}")
            archive.write(path, name)
            records.append({"name": name, "size_bytes": path.stat().st_size, "sha256": digest(path)})
    archive_path = target / "toy-dg-windows.zip"
    manifest = {
        "schema": 1,
        "version": version,
        "commit": commit,
        "minimum_launcher": 1,
        "windows": {
            "url": f"https://github.com/XiminHu66/toy-dg/releases/download/v{version}/toy-dg-windows.zip",
            "entrypoint": "toy-dg.exe",
            "size_bytes": archive_path.stat().st_size,
            "sha256": digest(archive_path),
            "files": records,
        },
    }
    (target / "update.json").write_text(json.dumps(manifest, indent=2) + "\n")
    with zipfile.ZipFile(target / "toy-dg-launcher.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        archive.write(root / "build/launcher/ToyDG-Launcher.exe", "ToyDG-Launcher.exe")
        archive.write(root / "THIRD_PARTY_NOTICES.md", "THIRD_PARTY_NOTICES.md")
        archive.write(root / "assets/fonts/OFL.txt", "OFL.txt")
        archive.writestr("START-HERE.txt", "Run ToyDG-Launcher.exe. It checks and installs game updates automatically.\n"
                          "Internet is required for the first installation. Later you can play the installed game offline.\n"
                          "Game saves are kept separately from downloaded versions.\n")
    with zipfile.ZipFile(target / "toy-dg-web.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted((root / "build/web").glob("*")):
            if path.is_file() and not path.name.endswith(".import") and not path.name.startswith("."):
                archive.write(path, path.name)
    (target / "release-notes.md").write_text(
        f"# 地城拾遗 {version}\n\n"
        f"源码：{commit}\n\n"
        "首次使用请下载 `toy-dg-launcher.zip`，解压运行 `ToyDG-Launcher.exe`。"
        "之后启动器会自动检查并安装新游戏版本；断网可启动已安装版本。\n\n"
        "`toy-dg-windows.zip` 是可直接运行的单版本包；`toy-dg-web.zip` 是需要HTTP托管的网页包。\n\n"
        "当前仍是占位美术的玩法原型。自动更新保留存档；源码、规则检查与导出通过后才发布。\n",
        encoding="utf-8",
    )
    return manifest


if __name__ == "__main__":
    data = package(sys.argv[1], sys.argv[2])
    print(f"Packaged {data['version']}: {data['windows']['size_bytes']} bytes")
