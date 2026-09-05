#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 AIPDF contributors
set -euo pipefail
PROJECT_DIR="${0:A:h:h}"
cd "$PROJECT_DIR"
if [[ ! -x .venv/bin/python ]]; then
  python3 -m venv .venv
fi
.venv/bin/python -m pip install -r requirements.lock.txt
.venv/bin/python backend/catalog.py
swift build -c release --disable-sandbox --scratch-path .build --cache-path .build/cache
.venv/bin/python scripts/package_app.py
printf '应用已生成：%s/dist/AIPDF.app\n' "$PROJECT_DIR"
