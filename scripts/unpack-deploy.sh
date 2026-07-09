#!/usr/bin/env bash
# Guduu DI — 从 pack-deploy.sh 生成的 tarball 解压并启动
set -euo pipefail

ARCHIVE="${1:?用法: bash unpack-deploy.sh /path/to/guduu-di-deploy.tar.gz [目标目录]}"
TARGET="${2:-/var/guduu-di}"

log() { echo "[Guduu DI unpack] $*"; }
die() { echo "[Guduu DI unpack] ERROR: $*" >&2; exit 1; }

[[ -f "$ARCHIVE" ]] || die "找不到归档: $ARCHIVE"

PARENT="$(dirname "$TARGET")"
NAME="$(basename "$TARGET")"
mkdir -p "$PARENT"

log "解压到 $TARGET ..."
tar -xzf "$ARCHIVE" -C "$PARENT"
[[ -d "$TARGET" ]] || die "解压后未找到 $TARGET"

export GUDUU_DEPLOY_ROOT="$TARGET"
SETUP="$TARGET/app/scripts/setup.sh"
START="$TARGET/app/scripts/start.sh"

if [[ -x "$SETUP" ]]; then
  log "增量 setup（同步源码变更）..."
  bash "$SETUP" "$TARGET"
fi

log "启动服务 ..."
bash "$START" "$TARGET"

log "✓ 部署就绪: http://127.0.0.1:$(grep GUDUU_UI_PORT "$TARGET/env/.env" 2>/dev/null | cut -d= -f2 || echo 3100)"
