#!/bin/zsh
# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 AIPDF contributors
set -uo pipefail
INSTALL_SOURCE="${0:A:h}"
cd "$INSTALL_SOURCE" || exit 1
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:${PATH:-}"
export PYTHONDONTWRITEBYTECODE=1

finish() {
  local result="$1"
  if [[ -t 0 ]]; then
    printf '\n按回车键关闭此窗口。'
    read -r
  fi
  exit "$result"
}

printf '\nAIPDF · 构建并安装到应用程序\n\n'
if [[ "$(uname -s)" != Darwin ]]; then
  printf '此安装脚本只支持 macOS。\n'
  finish 1
fi
INSTALL_MAC_VERSION="$(/usr/bin/sw_vers -productVersion)"
if [[ "${INSTALL_MAC_VERSION%%.*}" -lt 14 ]]; then
  printf '需要 macOS 14 或更新版本。\n'
  finish 1
fi
if ! /usr/bin/xcrun --find swift >/dev/null 2>&1; then
  if [[ " $* " == *" --check "* ]]; then
    printf '尚未安装 Apple Command Line Tools。\n'
    finish 1
  fi
  printf '首次构建需要 Apple Command Line Tools。请完成即将弹出的系统安装，再双击此文件。\n'
  /usr/bin/xcode-select --install || true
  finish 1
fi

INSTALL_PYTHON=""
for candidate in python3.14 python3.13 python3.12 python3 \
  /Library/Frameworks/Python.framework/Versions/3.14/bin/python3 \
  /Library/Frameworks/Python.framework/Versions/3.13/bin/python3 \
  /Library/Frameworks/Python.framework/Versions/3.12/bin/python3; do
  candidate_path="$(command -v "$candidate" 2>/dev/null || true)"
  if [[ -n "$candidate_path" ]] && "$candidate_path" -I -c 'import sys; sys.exit(0 if (3,12) <= sys.version_info[:2] <= (3,14) else 1)' >/dev/null 2>&1; then
    INSTALL_PYTHON="$candidate_path"
    break
  fi
done
if [[ -z "$INSTALL_PYTHON" ]]; then
  printf '需要先安装 Python 3.12—3.14（推荐 3.14），然后重新双击此脚本。\n'
  printf '官方下载：https://www.python.org/downloads/macos/\n'
  printf '如果已有 Homebrew，也可以执行：brew install python@3.14\n'
  printf '详细说明：docs/构建与安装.md\n'
  finish 1
fi

"$INSTALL_PYTHON" "$INSTALL_SOURCE/scripts/install.py" "$@"
result=$?
if [[ "$result" -ne 0 ]]; then
  printf '\n安装没有完成。请查看上方错误，按 docs/构建与安装.md 排查后重试。\n'
fi
finish "$result"
