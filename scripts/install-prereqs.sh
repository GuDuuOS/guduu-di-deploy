#!/usr/bin/env bash
# Guduu DI — Ubuntu/Debian 国外服务器依赖预装（推荐）
set -euo pipefail

log() { echo "[install-prereqs] $*"; }
die() { echo "[install-prereqs] ERROR: $*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || die "请使用 root 运行，或自行安装下列依赖"

log "安装系统依赖 ..."
apt-get update
apt-get install -y \
  python3.11 python3.11-venv python3.11-dev \
  python3.12 python3.12-venv python3-dev \
  default-jdk-headless \
  rsync curl git \
  build-essential pkg-config libssl-dev

if ! command -v yarn >/dev/null 2>&1; then
  if command -v npm >/dev/null 2>&1; then
    npm install -g yarn
  else
    apt-get install -y npm
    npm install -g yarn
  fi
fi

if ! command -v poetry >/dev/null 2>&1; then
  log "安装 Poetry 1.8.3 ..."
  curl -sSL https://install.python-poetry.org | python3 - --version 1.8.3
  log "请将 ~/.local/bin 加入 PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

if ! command -v cargo >/dev/null 2>&1; then
  log "安装 Rust（编译 wren_core 需要）..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  log "请将 ~/.cargo/bin 加入 PATH: export PATH=\"\$HOME/.cargo/bin:\$PATH\""
fi

log "✓ 依赖预装完成"
log "  python3.11: $(command -v python3.11 || echo 缺失)"
log "  python3.12: $(command -v python3.12 || echo 缺失)"
log "  java:       $(java -version 2>&1 | head -1)"
log "  yarn:       $(yarn -v 2>/dev/null || echo 缺失)"
log "  poetry:     $(poetry --version 2>/dev/null || echo 缺失)"
log "  cargo:      $(cargo --version 2>/dev/null || echo 缺失)"
log "  说明: Node.js 20、Qdrant、Java JAR 由 setup.sh 在线下载/编译"
