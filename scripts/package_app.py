# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 AIPDF contributors
"""Assemble the local .app without modifying system applications or input files."""
import plistlib
from pathlib import Path
import shutil
import subprocess
import os
import json
import sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
subprocess.run([sys.executable, str(ROOT / "scripts/collect_licenses.py"), "--check"], check=True)
APP = ROOT / "dist/AIPDF.app"
MACOS = APP / "Contents/MacOS"
RESOURCES = APP / "Contents/Resources"
MACOS.mkdir(parents=True, exist_ok=True)
RESOURCES.mkdir(parents=True, exist_ok=True)
def replace_executable(source, destination):
    # Replace the inode so an already-open application can finish using its binary.
    staged = destination.with_name(destination.name + ".next")
    shutil.copy2(source, staged)
    os.replace(staged, destination)


replace_executable(ROOT / ".build/release/AIPDF", MACOS / "AIPDF")
replace_executable(ROOT / ".build/release/VisionHelper", RESOURCES / "VisionHelper")
replace_executable(ROOT / ".build/release/WebHelper", RESOURCES / "WebHelper")
(RESOURCES / "backend").mkdir(exist_ok=True)
for name in ("engine.py", "catalog.py", "catalog.json"):
    shutil.copy2(ROOT / "backend" / name, RESOURCES / "backend" / name)
legal = RESOURCES / "Legal"
legal.mkdir(exist_ok=True)
for name in ("LICENSE", "NOTICE", "THIRD_PARTY_NOTICES.md", "SECURITY.md", "docs/分发说明.md"):
    target = legal / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / name, target)
shutil.copytree(ROOT / "licenses", legal / "licenses", dirs_exist_ok=True)
try:
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, stderr=subprocess.DEVNULL).decode().strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=normal"], cwd=ROOT).strip())
except (OSError, subprocess.CalledProcessError):
    revision, dirty = None, True
source_info = {
    "repository": "https://github.com/panyang/aipdf", "revision": revision,
    "working_tree_has_uncommitted_changes": dirty,
    "project_license": "AGPL-3.0-only", "build_kind": "local-development",
    "source_notice": "Distributors must provide the corresponding source for the actual build. A private repository or a commit omitting local changes is insufficient.",
}
(legal / "SOURCE_INFO.json").write_text(json.dumps(source_info, ensure_ascii=False, indent=2) + "\n")
(legal / "README.md").write_text(
    "# AIPDF 许可与源码\n\n"
    "本项目自有内容使用 AGPL-3.0-only，允许按许可条款使用、修改与分发，且不提供适销性或特定用途的担保。\n\n"
    "- [完整许可证](LICENSE)\n- [版权与授权范围](NOTICE)\n"
    "- [第三方声明](THIRD_PARTY_NOTICES.md)\n- [安全说明](SECURITY.md)\n"
    "- [分发说明](docs/分发说明.md)\n- [构建源码信息](SOURCE_INFO.json)\n\n"
    "源码地址：https://github.com/panyang/aipdf\n\n"
    "这是本机开发构建。正式分发时须提供接收者可访问、与实际版本一致的对应源码，含构建材料及未提交修改。\n"
)
icon = ROOT / "assets/AppIcon.icns"
image = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((42, 42, 982, 982), radius=218, fill="#D7664D")
draw.rounded_rectangle((250, 200, 664, 753), radius=44, fill="#ECA58F")
draw.rounded_rectangle((343, 276, 774, 839), radius=46, fill="#FFFDF9")
draw.rounded_rectangle((424, 439, 687, 461), radius=11, fill="#D7664D")
draw.rounded_rectangle((424, 510, 687, 532), radius=11, fill="#D7664D")
draw.rounded_rectangle((424, 581, 604, 603), radius=11, fill="#D7664D")
image.save(icon, format="ICNS")
if icon.exists():
    shutil.copy2(icon, RESOURCES / icon.name)
info = {
    "CFBundleName": "AIPDF", "CFBundleDisplayName": "AIPDF", "CFBundleIdentifier": "local.aipdf.desktop",
    "CFBundleVersion": "1", "CFBundleShortVersionString": "0.1.0", "CFBundleExecutable": "AIPDF",
    "CFBundlePackageType": "APPL", "LSMinimumSystemVersion": "14.0", "NSHighResolutionCapable": True,
    "NSHumanReadableCopyright": "Copyright © 2026 AIPDF contributors. AGPL-3.0-only.",
    "CFBundleIconFile": "AppIcon", "AIPDFProjectPath": str(ROOT),
    "CFBundleDocumentTypes": [{"CFBundleTypeName": "PDF document", "LSItemContentTypes": ["com.adobe.pdf"],
                               "CFBundleTypeRole": "Viewer", "LSHandlerRank": "Alternate"}],
}
with (APP / "Contents/Info.plist").open("wb") as stream:
    plistlib.dump(info, stream)
subprocess.run(["/usr/bin/codesign", "--force", "--deep", "--sign", "-", str(APP)], check=True)
print(APP)
