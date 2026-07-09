#!/usr/bin/env bash
# Guduu DI — 外网在线部署初始化（运行目录与源码仓库分离）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/setup-steps.sh
source "$SCRIPT_DIR/lib/setup-steps.sh"

guduu_paths "${1:-}"

log() { echo "[Guduu DI setup] $*"; }
die() { echo "[Guduu DI setup] ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "缺少命令: $1"
}

log "源码仓库: $GUDUU_SOURCE_ROOT"
log "部署目录: $GUDUU_DEPLOY_ROOT"
log "部署模式: 国外服务器在线安装（直连官方源）"
if guduu_parallel_enabled; then
  log "并行安装: 开启（GUDUU_PARALLEL_SETUP=1）"
else
  log "并行安装: 关闭（串行安装）"
fi

guduu_setup_mirrors
mkdir -p "$GUDUU_DEPLOY_ROOT/env" "$GUDUU_RUNTIME"/{bin,logs,pids,etc/mdl}

[[ -d "$GUDUU_SOURCE_ROOT/semantic-engine/ibis-server" ]] || die "缺少 semantic-engine/"

jar_preflight=$(guduu_engine_jar_path "$GUDUU_SOURCE_ROOT/semantic-engine" 2>/dev/null || true)
if [[ -n "$jar_preflight" ]]; then
  log "已包含预编译 Java 引擎: $(basename "$jar_preflight")"
elif [[ -d "$GUDUU_SOURCE_ROOT/vendor/prebuilt" ]]; then
  die "在线版不应包含 vendor/prebuilt/（体积过大），请使用 guduu-di 离线包"
else
  log "Java 引擎: Maven 在线编译"
fi
if [[ -d "$GUDUU_SOURCE_ROOT/vendor/python/wren_core" ]]; then
  log "已包含预编译 wren_core（vendor/python/）"
else
  log "wren_core: Rust 在线编译（需 cargo）"
fi
if [[ -x "$GUDUU_SOURCE_ROOT/vendor/bin/qdrant" ]]; then
  log "已包含 Qdrant 二进制（vendor/bin/qdrant）"
else
  log "Qdrant: 从 GitHub Releases 在线下载"
fi

if [[ ! -d "$GUDUU_SOURCE_ROOT/vendor/python/wren_core" ]] \
  && ! command -v cargo >/dev/null 2>&1 \
  && ! guduu_docker_available; then
  die "缺少 wren_core 构建能力：请运行 bash scripts/install-prereqs.sh 安装 Rust，或安装 Docker"
fi

if [[ ! -f "$GUDUU_ENV_FILE" ]]; then
  cp "$GUDUU_SOURCE_ROOT/scripts/env.example" "$GUDUU_ENV_FILE"
  log "已创建 $GUDUU_ENV_FILE，请填入 OPENAI_API_KEY 后重新运行 setup"
fi
guduu_load_env "$GUDUU_DEPLOY_ROOT"

# ── 1. 同步源码到部署目录 ─────────────────────────
log "同步源码到部署目录 ..."
guduu_sync_source

# ── 2. 检查运行时 ────────────────────────────────
require_cmd java
require_cmd poetry
require_cmd curl
export PY_AI
PY_AI=$(guduu_python 3.12) || die "ai-service 需要 Python 3.12（python3.12）"
export PY_IBIS
PY_IBIS=$(guduu_python 3.11) || die "ibis-server 需要 Python 3.11（python3.11）"
require_cmd rsync

if [[ -x "$GUDUU_SOURCE_ROOT/vendor/bin/just" ]]; then
  cp "$GUDUU_SOURCE_ROOT/vendor/bin/just" "$GUDUU_RUNTIME/bin/just" 2>/dev/null || true
  chmod +x "$GUDUU_RUNTIME/bin/just" 2>/dev/null || true
fi
export PATH="$GUDUU_RUNTIME/bin:$PATH"

if guduu_has_prebuilt_web_ui; then
  guduu_export_node_path || true
  log "web-ui 使用预构建包 vendor/prebuilt/（可选）"
else
  log "web-ui 将使用 Node.js 20 在线 yarn install + build（首次约 10–20 分钟）"
  command -v yarn >/dev/null 2>&1 || die "缺少 yarn（在线构建 web-ui 时需要）"
fi

JAVA_MAJOR=$(java -version 2>&1 | head -1 | sed -E 's/.*"([0-9]+).*/\1/')
[[ "$JAVA_MAJOR" -ge 21 ]] || die "需要 JDK >= 21，当前: $(java -version 2>&1 | head -1)"

if ! command -v cargo >/dev/null 2>&1; then
  if [[ -d "$GUDUU_SOURCE_ROOT/vendor/python/wren_core" ]]; then
    log "未检测到 Rust/cargo（已含 vendor/python/wren_core）"
  elif guduu_docker_available; then
    log "未检测到 Rust/cargo（将尝试 Docker 提取 wren_core）"
  else
    die "缺少 Rust/cargo，请运行: bash scripts/install-prereqs.sh"
  fi
fi

# ── 3. 获取语义引擎（必须先于并行步骤） ───────────
guduu_step_engine_clone || die "语义引擎获取失败"
guduu_step_engine_config

# ── 4. 并行 / 串行安装各组件 ─────────────────────
if guduu_parallel_enabled; then
  log "并行安装: engine-jar / ibis / ai-service / web-ui / qdrant ..."
  guduu_parallel_begin
  guduu_parallel_run engine-jar guduu_step_engine_jar
  guduu_parallel_run ibis guduu_step_ibis
  guduu_parallel_run ai guduu_step_ai_service
  guduu_parallel_run web-ui guduu_step_web_ui
  guduu_parallel_run qdrant guduu_step_qdrant
  guduu_parallel_wait || die "并行安装失败，请查看 $GUDUU_LOG_DIR/setup-*.log"
else
  guduu_step_engine_jar || die "Java 引擎安装失败"
  guduu_step_ibis || die "ibis-server 安装失败"
  guduu_step_ai_service || die "ai-service 安装失败"
  guduu_step_web_ui || die "web-ui 安装失败"
  guduu_step_qdrant || die "Qdrant 安装失败"
fi

log "✓ 部署环境初始化完成"
log "部署目录: $GUDUU_DEPLOY_ROOT"
log "下一步: 编辑 $GUDUU_ENV_FILE 填入 OPENAI_API_KEY"
log "启动: GUDUU_DEPLOY_ROOT='$GUDUU_DEPLOY_ROOT' bash scripts/start.sh"
log "提示: 再次部署只需增量 setup，请勿删除部署目录"
