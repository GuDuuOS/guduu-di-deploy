# Guduu DI — 开发指南（外网在线版）

本文档说明如何在 **`guduu-di-online`** 源码上进行本地开发、调试与贡献。

---

## 1. 开发模式概览

Guduu DI 由多个服务组成，开发时可：

- **全栈联调**：`setup.sh` + `start.sh` 启动全部服务
- **单模块热更新**：只启动其他服务，在源码目录单独跑正在开发的模块

部署目录（`GUDUU_DEPLOY_ROOT`）与源码目录分离，避免污染 Git/SVN 工作区。

---

## 2. 环境准备

与 [DEPLOY.md](./DEPLOY.md) 相同，需要：

- Python 3.11 + 3.12、Poetry
- JDK 21+
- Node.js 18–22、Yarn
- Rust（ibis / wren-core-py）
- build-essential

```bash
cd guduu-di-online
bash scripts/install-prereqs.sh   # Ubuntu/Debian
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
```

---

## 3. 首次初始化

```bash
export GUDUU_DEPLOY_ROOT=~/guduu-di-dev
bash scripts/setup.sh
vim ~/guduu-di-dev/env/.env       # OPENAI_API_KEY=...
bash scripts/start.sh
```

开发用部署目录建议使用 `$HOME/guduu-di-dev`，与生产 `/var/guduu-di` 隔离。

---

## 4. 各模块开发

### 4.1 Web UI（Next.js）

```bash
# 确保 backend 已启动
export GUDUU_DEPLOY_ROOT=~/guduu-di-dev
bash scripts/start.sh

# 前端热更新
cd web-ui
cp .env.local.example .env.local
# 编辑 .env.local，endpoint 指向 127.0.0.1 对应端口
yarn dev
```

默认 dev 端口 3000；生产 start 使用 `GUDUU_UI_PORT`（3100）。

修改 UI 后生产构建：

```bash
cd web-ui
yarn build
# 或在部署目录：GUDUU_FORCE_REBUILD=1 bash scripts/setup.sh
```

### 4.2 AI Service（Python / FastAPI）

```bash
cd ai-service
cp tools/config/config.example.yaml config.yaml
cp tools/config/.env.dev.example .env.dev

poetry env use python3.12
poetry install
poetry run python -m src.__main__
```

配置 `config.yaml` 中的 qdrant、UI 地址与 `.env.dev` 中的 `OPENAI_API_KEY`。

### 4.3 语义引擎 — ibis-server

```bash
cd semantic-engine/ibis-server
cp .env.example .env 2>/dev/null || true

# 安装 wren_core（与 setup 相同）
cd ../wren-core-py && poetry install --no-root && poetry run maturin develop
cd ../ibis-server
poetry env use python3.11
poetry install
poetry run pip install ../wren-core-py/target/wheels/wren_core_py-*.whl

poetry run python -m fastapi run --port 8000
```

或使用 `just install`（需安装 [just](https://github.com/casey/just)）。

### 4.4 语义引擎 — Java

```bash
cd semantic-engine/wren-core-legacy
./mvnw clean install -DskipTests -P exec-jar

JAR=$(find wren-server/target -name '*-executable.jar' | head -1)
java -Dconfig=/path/to/config.properties -jar "$JAR"
```

---

## 5. 目录与代码结构

```
guduu-di-online/
├── web-ui/                 # 前端：页面、API 路由、数据源连接器 UI
│   ├── src/
│   └── package.json
├── ai-service/             # LLM 管道、RAG、SQL 生成
│   ├── src/
│   └── pyproject.toml
├── semantic-engine/
│   ├── ibis-server/        # SQL 规划与执行 API
│   ├── wren-core-legacy/   # Java 查询引擎（fallback）
│   ├── wren-core/          # Rust 语义核心
│   └── wren-core-py/       # Python 绑定
└── scripts/                # 部署与运维脚本
```

---

## 6. 常用开发命令

```bash
export GUDUU_DEPLOY_ROOT=~/guduu-di-dev

bash scripts/status.sh          # 查看各服务 PID / 端口
bash scripts/stop.sh            # 停止全部
bash scripts/start.sh           # 启动全部
bash scripts/setup.sh           # 同步源码、增量安装依赖
bash scripts/fix-web-ui.sh      # 修复前端依赖异常
```

---

## 7. 代码规范与贡献

- 遵循 [CONTRIBUTING.md](./CONTRIBUTING.md)
- Python：各子项目 `pyproject.toml` 中的 ruff / pytest 配置
- 前端：`web-ui` 内 ESLint / Prettier
- 提交前在对应模块运行测试（如有）

---

## 8. 调试技巧

### 查看服务日志

```bash
tail -f ~/guduu-di-dev/runtime/logs/*.log
```

### 仅重建某一组件

```bash
# 串行 setup，便于观察单步日志
GUDUU_PARALLEL_SETUP=0 bash scripts/setup.sh
```

### 跳过 web-ui（加快后端调试）

```bash
GUDUU_SKIP_WEB_UI=1 bash scripts/setup.sh
```

---

## 9. 相关文档

- [DEPLOY.md](./DEPLOY.md) — 生产部署
- [docs/GUDUU_DI_INTEGRATION_SOLUTION.md](./docs/GUDUU_DI_INTEGRATION_SOLUTION.md) — 企业集成方案
- [docs/GUDUU_DI_ENTERPRISE_INTEGRATION_TUTORIAL.md](./docs/GUDUU_DI_ENTERPRISE_INTEGRATION_TUTORIAL.md) — 企业集成教程
