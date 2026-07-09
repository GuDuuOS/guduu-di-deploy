#!/usr/bin/env bash
# 修复 web-ui 依赖缺失（如 @apollo/client not found）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

guduu_paths "${1:-}"
guduu_setup_mirrors

log() { echo "[Guduu DI fix-web-ui] $*"; }
die() { echo "[Guduu DI fix-web-ui] ERROR: $*" >&2; exit 1; }

log "部署目录: $GUDUU_DEPLOY_ROOT"
bash "$SCRIPT_DIR/stop.sh" "$GUDUU_DEPLOY_ROOT" 2>/dev/null || true

if [[ -d "$GUDUU_SOURCE_ROOT/vendor/prebuilt/web-ui/node_modules" ]]; then
  log "从 vendor/prebuilt 恢复 web-ui ..."
  rm -rf "$GUDUU_APP_ROOT/web-ui/node_modules" "$GUDUU_APP_ROOT/web-ui/.next"
  guduu_restore_web_ui_prebuilt || die "恢复失败"
else
  log "在线重建 web-ui（yarn install + build）..."
  cd "$GUDUU_APP_ROOT/web-ui"
  local_node=""
  local_node=$(guduu_node_bin_dir) || die "无法准备 Node.js 20"
  export PATH="$local_node:$PATH"
  command -v yarn >/dev/null 2>&1 || die "缺少 yarn"
  rm -rf node_modules .next
  yarn install --frozen-lockfile 2>/dev/null || yarn install
  yarn migrate
  yarn build
fi

guduu_web_ui_deps_ok || die "依赖仍不完整"

log "✓ web-ui 依赖已修复"
log "启动: GUDUU_DEPLOY_ROOT='$GUDUU_DEPLOY_ROOT' bash scripts/start.sh"
