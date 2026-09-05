"""Assemble the local .app without modifying system applications or input files."""
import plistlib
from pathlib import Path
import shutil
import subprocess
import os
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
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
    "CFBundleIconFile": "AppIcon", "AIPDFProjectPath": str(ROOT),
    "CFBundleDocumentTypes": [{"CFBundleTypeName": "PDF document", "LSItemContentTypes": ["com.adobe.pdf"],
                               "CFBundleTypeRole": "Viewer", "LSHandlerRank": "Alternate"}],
}
with (APP / "Contents/Info.plist").open("wb") as stream:
    plistlib.dump(info, stream)
subprocess.run(["/usr/bin/codesign", "--force", "--deep", "--sign", "-", str(APP)], check=True)
print(APP)
