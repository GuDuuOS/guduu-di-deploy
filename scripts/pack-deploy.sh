#!/usr/bin/env bash
# Guduu DI — 打包部署目录，供快速迁移到其他机器
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

guduu_paths "${1:-}"

OUT="${2:-${GUDUU_DEPLOY_ROOT}.tar.gz}"
ROOT_PARENT="$(dirname "$GUDUU_DEPLOY_ROOT")"
ROOT_NAME="$(basename "$GUDUU_DEPLOY_ROOT")"

log() { echo "[Guduu DI pack] $*"; }
die() { echo "[Guduu DI pack] ERROR: $*" >&2; exit 1; }

[[ -d "$GUDUU_DEPLOY_ROOT/app" ]] || die "部署目录未初始化: $GUDUU_DEPLOY_ROOT"

log "打包: $GUDUU_DEPLOY_ROOT -> $OUT"
log "排除: runtime/logs, runtime/pids"

tar -czf "$OUT" -C "$ROOT_PARENT" \
  --exclude="$ROOT_NAME/runtime/logs" \
  --exclude="$ROOT_NAME/runtime/pids" \
  --exclude="$ROOT_NAME/runtime/pids/*" \
  "$ROOT_NAME"

SIZE=$(du -h "$OUT" | cut -f1)
log "✓ 完成: $OUT ($SIZE)"
log "迁移: scp $OUT user@host:/var/ && ssh user@host 'tar xzf $(basename "$OUT") -C /var && export GUDUU_DEPLOY_ROOT=/var/$ROOT_NAME && bash /var/$ROOT_NAME/app/scripts/start.sh'"
