#!/usr/bin/env bash
# Guduu DI — 打包国外服务器在线版，供交付给客户
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="${1:-guduu-di-online-$(date +%Y%m%d).tar.gz}"
PARENT="$(dirname "$SOURCE_ROOT")"
NAME="$(basename "$SOURCE_ROOT")"

log() { echo "[pack-online] $*"; }
die() { echo "[pack-online] ERROR: $*" >&2; exit 1; }

[[ -d "$SOURCE_ROOT/semantic-engine/ibis-server" ]] || die "缺少 semantic-engine/"
[[ ! -d "$SOURCE_ROOT/vendor/prebuilt" ]] || die "在线版不应含 vendor/prebuilt/（请用 guduu-di 离线包）"

log "打包: $SOURCE_ROOT -> $OUT"
tar -czf "$OUT" -C "$PARENT" \
  --exclude="$NAME/runtime" \
  --exclude="$NAME/web-ui/node_modules" \
  --exclude="$NAME/web-ui/.next" \
  --exclude="$NAME/**/.venv" \
  --exclude="$NAME/**/target" \
  --exclude="$NAME/vendor/prebuilt" \
  --exclude="$NAME/vendor/bin" \
  --exclude="$NAME/vendor/python" \
  --exclude="$NAME/.svn" \
  --exclude="$NAME/.git" \
  "$NAME"

SIZE=$(du -h "$OUT" | cut -f1)
log "✓ 完成: $OUT ($SIZE)"
log "客户解压后:"
log "  sudo bash scripts/install-prereqs.sh"
log "  export PATH=\"\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH\""
log "  export GUDUU_DEPLOY_ROOT=/var/guduu-di && bash scripts/setup.sh"
