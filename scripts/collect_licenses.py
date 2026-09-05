"""Copy shipped license notices from the locked environment without network access."""
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 AIPDF contributors
from __future__ import annotations

import argparse
import hashlib
from importlib import metadata
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
DESTINATION = ROOT / "licenses/third-party"
NOTICE_NAME = re.compile(r"^(?:licen[cs]es?|copying|notice|authors)(?:[._-].*)?$", re.I)


def collect():
    packages = []
    payloads = {}
    for line in (ROOT / "requirements.lock.txt").read_text().splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        match = re.fullmatch(r"([A-Za-z0-9_.-]+)==([A-Za-z0-9_.+-]+)", line)
        if not match:
            raise ValueError("Only exact package==version entries are supported in requirements.lock.txt")
        name, version = match.groups()
        distribution = metadata.distribution(name)
        if distribution.version != version:
            raise ValueError(f"Version mismatch for {name}: expected {version}, installed {distribution.version}")
        package_key = re.sub(r"[-_.]+", "-", name.lower()) + "-" + version
        notices = []
        for record in sorted(distribution.files or [], key=str):
            if ".." in record.parts or record.is_absolute():
                continue
            is_notice = NOTICE_NAME.fullmatch(record.name) or any(
                part.lower() in ("licenses", "licences", "build_licenses") for part in record.parts[:-1]
            )
            if not is_notice:
                continue
            source = distribution.locate_file(record)
            if not source.is_file():
                continue
            relative = Path(package_key).joinpath(*record.parts)
            data = source.read_bytes()
            payloads[relative.as_posix()] = data
            notices.append({"path": relative.as_posix(), "sha256": hashlib.sha256(data).hexdigest()})
        if not notices:
            raise ValueError(f"No shipped license notices found for {name}; review the installed package manually")
        info = distribution.metadata
        declared = info.get("License-Expression") or info.get("License") or "See shipped license text"
        packages.append({
            "name": info["Name"], "version": version,
            "declared_license": declared,
            "project_urls": info.get_all("Project-URL") or [],
            "notices": notices,
        })
    manifest = {
        "schema": 1,
        "scope": "License notices shipped in the installed distributions matching requirements.lock.txt. This is not a complete binary compliance audit.",
        "packages": packages,
    }
    return manifest, payloads


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verify the saved snapshot without modifying it")
    args = parser.parse_args()
    try:
        manifest, payloads = collect()
        manifest_file = DESTINATION / "manifest.json"
        if args.check:
            if json.loads(manifest_file.read_text()) != manifest:
                raise ValueError("License manifest differs from the locked installed environment")
            for relative, data in payloads.items():
                if (DESTINATION / relative).read_bytes() != data:
                    raise ValueError(f"License text differs: {relative}")
        else:
            for relative, data in payloads.items():
                target = DESTINATION / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
            manifest_file.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        print(f"{'Verified' if args.check else 'Collected'} {len(payloads)} notices from {len(manifest['packages'])} locked packages")
        return 0
    except (ValueError, OSError, metadata.PackageNotFoundError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
