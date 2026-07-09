# Guduu DI — 外网在线部署指南

> **Guduu DI** 企业级数据智能平台。本文档适用于 **`guduu-di-online`**：面向**国外服务器**的纯源码包（约 **90 MB**），`setup.sh` 在线下载/编译全部运行时依赖。

---

## 0. setup 阶段在线获取的组件

| 组件 | 方式 | 来源 |
|------|------|------|
| Java 引擎 JAR | Maven 编译 | Maven Central |
| wren_core | Rust 编译 | crates.io + GitHub |
| Qdrant | 二进制下载 | GitHub Releases |
| Node.js 20 | 二进制下载 | nodejs.org |
| Python 依赖 | Poetry install | PyPI |
| web-ui | yarn install + build | npm registry |

交付包**仅含源码**，不含上述预编译产物。

---

## 1. 架构概览

```
浏览器 ──▶ web-ui :3100
              ├──▶ ai-service :5555 ──▶ qdrant :6333
              ├──▶ 语义引擎 Java :8080
              └──▶ ibis-server :8000
```

| 组件 | 技术栈 | 默认端口 |
|------|--------|----------|
| web-ui | Next.js + Yarn | 3100 |
| ai-service | Python 3.12 + Poetry | 5555 |
| ibis-server | Python 3.11 + Poetry | 8000 |
| 语义引擎 | Java 21 + Maven | 8080 |
| Qdrant | 向量数据库 | 6333 |

---

## 2. 服务器要求

### 硬件（建议）

| 资源 | 最低 | 建议 |
|------|------|------|
| CPU | 4 核 | 8 核 |
| 内存 | 8 GB | 16 GB |
| 磁盘 | 30 GB 可用 | 50 GB+ |

首次 `setup` 会下载 npm/PyPI 缓存并构建 web-ui，磁盘占用约 **10–15 GB**（含部署目录）。**首次 setup 约 20–35 分钟**（web-ui yarn 编译占主要时间）。

### 操作系统

- **Linux x86_64** 或 **aarch64**（Ubuntu 22.04/24.04、Debian 12 等）
- 需能直连：PyPI、registry.yarnpkg.com / npm、Maven Central、nodejs.org、GitHub（setup 下载 Node 20 时）

### 软件依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| Python | **3.12** + **3.11** | ai-service / ibis-server |
| Poetry | 1.8.x | Python 依赖管理 |
| JDK | >= 21 | 编译/运行 Java 语义引擎 |
| Node.js | **20 LTS**（脚本会自动下载；勿用 21/22 编译 web-ui） | 构建 web-ui |
| Yarn | 1.x / 3.x | web-ui 包管理 |
| build-essential, python3-dev | — | web-ui 原生模块编译 |
| Rust + cargo | stable | 编译 wren_core（`install-prereqs.sh` 自动安装） |
| rsync, curl | 任意 | 部署脚本 |

> 无 Rust 时：可安装 Docker，setup 会尝试从镜像提取 wren_core。

---

## 3. 一键预装依赖（Ubuntu/Debian）

```bash
cd guduu-di-online
sudo bash scripts/install-prereqs.sh
```

手动安装 Poetry：

```bash
curl -sSL https://install.python-poetry.org | python3 - --version 1.8.3
export PATH="$HOME/.local/bin:$PATH"
```

---

## 4. 部署步骤

### 4.1 上传源码

将 `guduu-di-online` 目录上传至服务器，例如 `/opt/guduu-di-online`。

```bash
cd /opt/guduu-di-online
```

### 4.2 初始化

```bash
export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash scripts/setup.sh
```

`setup.sh` 会：

1. 将源码 rsync 到 `$GUDUU_DEPLOY_ROOT/app`
2. 复制 `semantic-engine` 到部署目录
3. **Maven** 编译 Java 语义引擎（若无预编译 JAR）
4. **Poetry** 安装 ai-service、ibis-server（ibis 需编译或注入 wren_core）
5. **yarn install + yarn build** 构建 web-ui
6. 从 **GitHub Releases** 下载 Qdrant 二进制

首次运行日志：`$GUDUU_DEPLOY_ROOT/runtime/logs/setup-*.log`

### 4.3 配置环境变量

```bash
vim /var/guduu-di/env/.env
```

必填：

```bash
OPENAI_API_KEY=sk-xxxxxxxx
```

常用项见 `scripts/env.example`。

### 4.4 启动与检查

```bash
export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash scripts/start.sh
bash scripts/status.sh
```

访问：`http://<服务器IP>:3100`

### 4.5 防火墙 / 安全组

对外开放 **GUDUU_UI_PORT**（默认 3100）。ai-service、qdrant、ibis、engine 默认仅监听本机，无需对外暴露。

---

## 5. 部署目录结构

```
/var/guduu-di/
├── app/
│   ├── web-ui/          # node_modules + .next（setup 生成）
│   └── ai-service/      # .venv（setup 生成）
├── semantic-engine/     # ibis-server .venv、Java JAR
├── runtime/
│   ├── bin/qdrant
│   ├── logs/
│   ├── pids/
│   └── qdrant-data/
└── env/.env
```

源码目录 `/opt/guduu-di-online` **不会被写入运行时产物**，可安全保留用于升级。

---

## 6. 环境变量参考

```bash
# 并行安装（首次建议 0，便于排错）
GUDUU_PARALLEL_SETUP=0

# 端口
GUDUU_UI_HOST=0.0.0.0
GUDUU_UI_PORT=3100
GUDUU_AI_PORT=5555
GUDUU_ENGINE_PORT=8080
GUDUU_IBIS_PORT=8000
GUDUU_QDRANT_PORT=6333

# LLM
OPENAI_API_KEY=sk-xxx
GENERATION_MODEL=gpt-4o-mini
TELEMETRY_ENABLED=false

# 强制重建前端（升级 UI 后）
# GUDUU_FORCE_REBUILD=1
```

---

## 7. 升级与回滚

```bash
export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash scripts/stop.sh

# 更新源码目录后
bash scripts/setup.sh      # 增量同步，保留 env 与 runtime 数据
bash scripts/start.sh
```

- 不要删除 `$GUDUU_DEPLOY_ROOT`，除非需要完全重装
- Qdrant 数据在 `runtime/qdrant-data/`，删除会丢失向量索引

---

## 8. 排错

| 现象 | 处理 |
|------|------|
| setup 某步骤失败 | 查看 `runtime/logs/setup-<组件>.log` |
| `wren_core` 导入失败 | 安装 Rust：`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \| sh`，或安装 Docker 后重跑 setup |
| Maven 编译失败（`.git directory is not found`） | 已在 setup 中自动加 `-Dmaven.gitcommitid.skip=true`；仍失败时可安装 Docker 作为 JAR 回退 |
| `better-sqlite3` 编译失败 | web-ui **必须用 Node 20**；setup 会自动下载 Node 20 到 `runtime/node20/` |
| yarn / duckdb 编译失败 | `apt install build-essential python3-dev` |
| web-ui Loading 卡住 | `bash scripts/fix-web-ui.sh` 后 `start.sh` |
| 端口占用 | 修改 `env/.env` 中 `GUDUU_*_PORT` |
| Qdrant 下载失败 | 检查 GitHub 访问；或 `GUDUU_USE_DOCKER=1` 且安装 Docker |

### 常用日志

```bash
tail -f /var/guduu-di/runtime/logs/web-ui.log
tail -f /var/guduu-di/runtime/logs/ai-service.log
tail -f /var/guduu-di/runtime/logs/ibis.log
tail -f /var/guduu-di/runtime/logs/engine.log
```

---

## 9. 验证

```bash
cd /opt/guduu-di-online
export GUDUU_DEPLOY_ROOT=/tmp/guduu-di-verify
bash scripts/verify-deploy.sh
```

---

## 10. 与离线版的关系

- **`guduu-di`**：含 `vendor/prebuilt`，适合内网/无网交付
- **`guduu-di-online`**（本包）：仅源码，适合云服务器、有公网的环境

两者共用同一套 `start.sh` / `stop.sh`，部署目录格式兼容。
