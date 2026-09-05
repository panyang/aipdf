"""Build a per-user runtime and safely install AIPDF without retaining source paths."""
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 AIPDF contributors
from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
import venv

ROOT = Path(__file__).resolve().parent.parent
SUPPORT = Path.home() / "Library/Application Support/AIPDF"
APP_ID = "local.aipdf.desktop"


def run(args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def runtime_identity(lock_data, base_prefix, python_version, machine):
    digest = hashlib.sha256(lock_data + str(base_prefix).encode() + python_version.encode()).hexdigest()[:16]
    return "py" + python_version.replace(".", "-") + "-" + machine + "-" + digest


def runtime_is_ready(directory, expected):
    try:
        if json.loads((directory / "aipdf-runtime.json").read_text()) != expected:
            return False
        run([directory / "bin/python", "-I", "-c",
             "import pymupdf, PIL, docx, pptx, openpyxl, pypdf, pdfplumber; import importlib.metadata"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except (OSError, ValueError, subprocess.CalledProcessError):
        return False


def prepare_runtime():
    lock_data = (ROOT / "requirements.lock.txt").read_bytes()
    identity = runtime_identity(lock_data, Path(sys.base_prefix).resolve(), platform.python_version(), platform.machine())
    expected = {"lock_sha256": hashlib.sha256(lock_data).hexdigest(), "python": platform.python_version(),
                "base_prefix": str(Path(sys.base_prefix).resolve()), "machine": platform.machine()}
    runtimes = SUPPORT / "Runtimes"
    runtimes.mkdir(parents=True, exist_ok=True, mode=0o700)
    for candidate in [runtimes / identity, *sorted(runtimes.glob(identity + "-*"))]:
        if runtime_is_ready(candidate, expected):
            print("已有可用运行环境，直接复用。", flush=True)
            return candidate
    directory = runtimes / identity
    if directory.exists():
        directory = runtimes / (identity + "-" + uuid.uuid4().hex[:8])
    directory.mkdir(mode=0o700)
    print("正在创建独立运行环境并安装锁定的 PDF 依赖，首次需要联网…", flush=True)
    venv.EnvBuilder(with_pip=True, symlinks=True).create(directory)
    python = directory / "bin/python"
    run([python, "-m", "pip", "--isolated", "--disable-pip-version-check", "install", "--no-input",
         "--only-binary=:all:", "--cache-dir", SUPPORT / "Cache/pip", "-r", ROOT / "requirements.lock.txt"])
    run([python, "-c", "from collect_licenses import collect; collect()"], cwd=ROOT / "scripts")
    (directory / "aipdf-runtime.json").write_text(json.dumps(expected, sort_keys=True) + "\n")
    if not runtime_is_ready(directory, expected):
        raise RuntimeError("新运行环境验证失败，请重试安装。")
    return directory


def choose_destination(explicit=None):
    if explicit:
        folder = Path(explicit).expanduser().absolute()
    else:
        folder = Path("/Applications")
        if not os.access(folder, os.W_OK | os.X_OK):
            folder = Path.home() / "Applications"
            print("系统应用程序目录不可写，改为当前用户的“应用程序”。", flush=True)
    folder.mkdir(parents=True, exist_ok=True)
    return folder / "AIPDF.app"


def validate_existing(target):
    if target.is_symlink():
        raise RuntimeError("目标 AIPDF.app 是符号链接，请先手动选择安装位置。")
    if target.exists():
        try:
            info = plistlib.loads((target / "Contents/Info.plist").read_bytes())
        except (OSError, ValueError):
            raise RuntimeError("目标位置已有无法识别的文件，不会覆盖。")
        if info.get("CFBundleIdentifier") != APP_ID:
            raise RuntimeError("目标位置已有其他应用，不会覆盖。")


def deploy_app(source, target, verify=None):
    validate_existing(target)
    staging = Path(tempfile.mkdtemp(prefix=".aipdf-install-", dir=target.parent))
    staged_app = staging / "AIPDF.app"
    shutil.copytree(source, staged_app, symlinks=True)
    if verify:
        verify(staged_app)
    backup = None
    if target.exists():
        backup = target.parent / (".AIPDF-backup-" + time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6] + ".app")
        target.rename(backup)
    try:
        staged_app.rename(target)
    except OSError:
        if backup is not None:
            backup.rename(target)
        raise
    staging.rmdir()
    return backup


def verify_bundle(app):
    run(["/usr/bin/codesign", "--verify", "--deep", "--strict", app])
    info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
    if info.get("CFBundleIdentifier") != APP_ID or "AIPDFProjectPath" in info or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", info.get("AIPDFRuntimeID", "")):
        raise RuntimeError("安装包仍引用源码目录，已停止安装。")


def preflight():
    if platform.system() != "Darwin" or int(platform.mac_ver()[0].split(".")[0]) < 14:
        raise RuntimeError("需要 macOS 14 或更新版本。")
    if not (3, 12) <= sys.version_info[:2] <= (3, 14):
        raise RuntimeError("需要 Python 3.12—3.14，推荐 3.14。")
    run(["/usr/bin/xcrun", "--find", "swift"], stdout=subprocess.DEVNULL)
    for path in ["Package.swift", "requirements.lock.txt", "LICENSE", "scripts/package_app.py"]:
        if not (ROOT / path).is_file():
            raise RuntimeError("源码不完整，请下载整个仓库并解压后重试。")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Only check prerequisites; do not install")
    parser.add_argument("--no-launch", action="store_true", help="Install without opening the app")
    parser.add_argument("--applications-dir", help="Override the application folder")
    args = parser.parse_args()
    os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
    try:
        preflight()
        if args.check:
            print("环境检查通过，可构建安装。运行时仍需保留基础 Python；Office 转换需另装 LibreOffice。")
            return 0
        SUPPORT.mkdir(parents=True, exist_ok=True, mode=0o700)
        with (SUPPORT / "install.lock").open("a") as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise RuntimeError("另一个 AIPDF 安装任务正在运行，请等待它完成。")
            destination = choose_destination(args.applications_dir)
            validate_existing(destination)
            runtime = prepare_runtime()
            print("正在编译 Mac 应用…", flush=True)
            swift = ["/usr/bin/xcrun", "swift", "build", "-c", "release", "--disable-sandbox",
                     "--scratch-path", ROOT / ".build", "--cache-path", ROOT / ".build/cache"]
            run(swift, cwd=ROOT)
            binaries = Path(subprocess.check_output([str(a) for a in swift] + ["--show-bin-path"], cwd=ROOT).decode().strip())
            work = Path(tempfile.mkdtemp(prefix="install-build-", dir=SUPPORT))
            built_app = work / "AIPDF.app"
            run([runtime / "bin/python", ROOT / "scripts/package_app.py", "--runtime-id", runtime.name,
                 "--output", built_app, "--binary-dir", binaries])
            verify_bundle(built_app)
            health_environment = dict(os.environ, AIPDF_VISION=str(built_app / "Contents/Resources/VisionHelper"))
            health = run([runtime / "bin/python", built_app / "Contents/Resources/backend/engine.py"],
                         input=json.dumps({"operation": "health"}), capture_output=True, text=True, env=health_environment)
            status = json.loads(health.stdout)
            if not status.get("ok") or not status.get("vision"):
                raise RuntimeError("处理引擎健康检查失败。")
            print("正在安装到“应用程序”…", flush=True)
            backup = deploy_app(built_app, destination, verify=verify_bundle)
            receipt = {"application": str(destination), "runtime_id": runtime.name,
                       "backup": str(backup) if backup else None, "built_app": str(built_app)}
            (SUPPORT / "last-install.json").write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
            print(f"\n安装完成：{destination}\n可删除下载的源码目录；请保留已安装的 Python 和 AIPDF 用户运行环境。", flush=True)
            if backup:
                print(f"旧版本备份：{backup}", flush=True)
            if not status.get("office"):
                print("Office/PDF-A 转换尚需 LibreOffice，其余工具可使用。下载：https://www.libreoffice.org/download/download-libreoffice/", flush=True)
            if not args.no_launch:
                run(["/usr/bin/open", "-n", destination])
        return 0
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as error:
        print(f"安装未完成：{error}\n请参阅源码中的 docs/构建与安装.md。已有输出文档不会被修改。", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
