#!/usr/bin/env bash
# 在独立目录验证外网在线部署，不修改源码仓库
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_ROOT="/tmp/guduu-di-online-test-$$"
export GUDUU_DEPLOY_ROOT="$TEST_ROOT"
export GUDUU_UI_PORT=13100
export GUDUU_AI_PORT=15555
export GUDUU_ENGINE_PORT=18080
export GUDUU_IBIS_PORT=18000
export GUDUU_QDRANT_PORT=16333
export GUDUU_PARALLEL_SETUP=0
rm -rf "$TEST_ROOT"

log() { echo "[Guduu DI verify] $*"; }
fail() { echo "[Guduu DI verify] FAIL: $*" >&2; exit 1; }
pass() { echo "[Guduu DI verify] PASS: $*"; }

cleanup() {
  log "清理测试部署 ..."
  GUDUU_DEPLOY_ROOT="$TEST_ROOT" bash "$SCRIPT_DIR/stop.sh" "$TEST_ROOT" 2>/dev/null || true
}
trap cleanup EXIT

log "源码仓库: $SOURCE_ROOT"
log "测试部署目录: $TEST_ROOT"

for artifact in runtime scripts/.env web-ui/node_modules web-ui/.next; do
  [[ ! -e "$SOURCE_ROOT/$artifact" ]] || fail "源码仓库存在部署产物: $artifact"
done
[[ -d "$SOURCE_ROOT/semantic-engine/ibis-server" ]] || fail "缺少 semantic-engine/"
[[ -d "$SOURCE_ROOT/vendor/prebuilt" ]] && fail "在线版不应包含 vendor/prebuilt/"
[[ -d "$SOURCE_ROOT/vendor/python/wren_core" ]] && fail "精简包不应含 vendor/python/（由 setup 在线编译）"
[[ -x "$SOURCE_ROOT/vendor/bin/qdrant" ]] && fail "精简包不应含 vendor/bin/qdrant（由 setup 在线下载）"
jar=$(find "$SOURCE_ROOT/semantic-engine/wren-core-legacy/wren-server/target" -name '*-executable.jar' 2>/dev/null | head -1)
[[ -z "$jar" ]] || fail "精简包不应含预编译 JAR（由 setup Maven 编译）"
pass "精简源码包结构正确"

mkdir -p "$TEST_ROOT/env"
cp "$SOURCE_ROOT/scripts/env.example" "$TEST_ROOT/env/.env"
for key in GUDUU_UI_PORT GUDUU_AI_PORT GUDUU_ENGINE_PORT GUDUU_IBIS_PORT GUDUU_QDRANT_PORT; do
  val="${!key}"
  if grep -q "^${key}=" "$TEST_ROOT/env/.env"; then
    sed -i "s/^${key}=.*/${key}=${val}/" "$TEST_ROOT/env/.env"
  else
    echo "${key}=${val}" >> "$TEST_ROOT/env/.env"
  fi
done

log "开始 setup（需联网，可能耗时较长）..."
if ! bash "$SCRIPT_DIR/setup.sh" 2>&1 | tee "$TEST_ROOT-setup.log"; then
  fail "setup.sh 失败，详见 $TEST_ROOT-setup.log"
fi
pass "setup 完成"

for artifact in runtime scripts/.env web-ui/node_modules web-ui/.next; do
  [[ ! -e "$SOURCE_ROOT/$artifact" ]] || fail "setup 后源码仓库被污染: $artifact"
done
pass "setup 未污染源码仓库"

log "开始 start ..."
if ! bash "$SCRIPT_DIR/start.sh" 2>&1 | tee "$TEST_ROOT-start.log"; then
  fail "start.sh 失败，详见 $TEST_ROOT-start.log"
fi
pass "start 完成"

UI_PORT=$(grep '^GUDUU_UI_PORT=' "$TEST_ROOT/env/.env" 2>/dev/null | tail -1 | cut -d= -f2)
AI_PORT=$(grep '^GUDUU_AI_PORT=' "$TEST_ROOT/env/.env" 2>/dev/null | tail -1 | cut -d= -f2)

curl -sf "http://127.0.0.1:${UI_PORT}/" >/dev/null || fail "Web UI 无响应 (:${UI_PORT})"
pass "Web UI HTTP 200 (:${UI_PORT})"

curl -sf "http://127.0.0.1:${AI_PORT}/health" >/dev/null || fail "AI Service /health 无响应 (:${AI_PORT})"
pass "AI Service /health OK (:${AI_PORT})"

log "=========================================="
log " 外网在线部署验证通过"
log " 测试目录: $TEST_ROOT"
log "=========================================="
