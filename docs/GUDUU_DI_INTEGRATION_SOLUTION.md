# Guduu DI × Guduu 平台 — 企业侧对接方案

> **文档版本**：2026-06-24  
> **适用对象**：企业架构师、信息化负责人  
> **目标**：说明企业如何部署 Guduu DI 并对接 Guduu 协作平台，使 Guduu 内 AI 可查询企业业务数据。

---

## 1. 背景与定位

### 1.1 问题

企业已有 SaaS 或自建系统（ERP、CRM、OA、数仓等），希望员工在 **Guduu 协作平台** 中用自然语言查询业务数据，并由 **Guduu 内 AI** 调用查询能力。

Guduu 主 AI **不直接连接**企业数据库。企业需自行部署 **Guduu DI**，将业务库映射为语义层，并对外提供 **标准 HTTP API**，供 AI 或企业对接服务调用。

### 1.2 Guduu DI 的角色

**Guduu DI** 部署在 **企业侧**，职责：

| 能力 | 说明 |
|------|------|
| **语义层（MDL）** | 业务术语 ↔ 数据库表/字段 |
| **自然语言问数** | NL → SQL → 执行 → 摘要/图表 |
| **多数据源** | 通过 Guduu DI 数据连接器连接主流数据库 |
| **开放 API** | REST `/api/v1/*`，供企业对接网关或 AI 编排调用 |

Guduu DI **不替代**企业原系统，是企业自建的 **数据语义网关**。

### 1.3 对接总览

```
┌──────────────────────────────────────────────────────────────┐
│  Guduu 协作平台                                               │
│  用户提问 · 主 AI · 频道 · Bot API / Webhook                   │
└────────────────────────────┬─────────────────────────────────┘
                             │ 标准 HTTP / Bot API（企业侧调用）
┌────────────────────────────▼─────────────────────────────────┐
│  【企业自建】对接网关 / 频道机器人服务                           │
│  · 鉴权 · 用户映射 · 审计 · 转发请求                           │
└────────────────────────────┬─────────────────────────────────┘
                             │ REST :3100
┌────────────────────────────▼─────────────────────────────────┐
│  【企业部署】Guduu DI                                           │
│  Web 服务 + AI 服务 + 语义引擎 + 数据连接器                     │
└────────────────────────────┬─────────────────────────────────┘
                             │ SQL（只读）
┌────────────────────────────▼─────────────────────────────────┐
│  【企业已有】ERP / CRM / 数仓 / 报表库                          │
└──────────────────────────────────────────────────────────────┘
```

**要点**：企业通过 Bot Token、入站 Webhook 等 Guduu 标准接口完成对接；DI 与对接服务部署在企业侧服务器。

---

## 2. 架构原则

### 2.1 职责划分

| 层级 | 归属 | 职责 |
|------|------|------|
| **协作入口** | Guduu 平台 | 用户对话、AI 交互、Bot / Webhook |
| **企业对接层** | **企业自建** | 接收/发起 HTTP、鉴权、格式转换、审计 |
| **数据智能层** | **企业部署 Guduu DI** | 语义建模、NL→SQL、查询执行 |
| **数据层** | **企业已有** | 业务库（只读账号） |

### 2.2 企业侧集成约束

1. 对接网关与 Guduu DI 之间走 **内网 HTTP**  
2. Guduu DI 默认 **无 API 登录**，须由企业对接网关或 API 网关加 **Token / mTLS**  
3. 数据库使用 **只读账号**；写操作走企业业务系统 API，不经 DI  
4. 对接日志在企业侧记录：`question`、`sql`、`user_id`、`trace_id`

### 2.3 安全模型

| 措施 | 实施方 |
|------|--------|
| DI 不对公网暴露 | 企业运维 |
| API 网关鉴权 | 企业对接网关 |
| 库只读 + 视图脱敏 | 企业 DBA |
| 用户级数据域 | 企业对接网关按用户注入过滤条件 |

---

## 3. 三种企业侧对接模式

企业可按场景任选或组合使用以下模式。

### 模式 A：企业频道机器人（推荐）

**思路**：企业在自有服务器运行 **频道机器人服务**，通过 Guduu **Bot API** 收发消息，内部调用 Guduu DI。

```
用户在 Guduu 频道 @企业数据助手
    → Guduu 将消息推送给企业 Bot（WebSocket / Outgoing Webhook）
    → 企业 Bot 服务 POST Guduu DI /api/v1/ask
    → Bot 将 summary 发回频道（Create Post API）
```

| 项 | 说明 |
|----|------|
| Guduu 配置 | 创建 Bot 账号、配置 Token（管理后台） |
| 企业侧 | 开发/部署 Bot 服务 + Guduu DI |
| 优点 | 体验接近原生对话、可多轮 `threadId` |
| 适用 | 长期使用、需要频道内问答 |

---

### 模式 B：企业对接网关（Open API）

**思路**：企业部署 **统一数据查询 API**（BFF），内部转发 Guduu DI；任何能发 HTTP 的 AI 编排（含 Guduu 工作流、企业自研调度）均可调用。

```
调用方（Guduu HTTP 工作流 / 企业调度 / 其他 AI）
    → POST https://api.enterprise.com/guduu-di/query
    → 企业网关鉴权后转发 DI /api/v1/ask
    → 返回 JSON（sql、summary、data）
```

**企业网关示例接口**：

```http
POST /guduu-di/query
Authorization: Bearer <企业颁发>
Content-Type: application/json

{
  "question": "本月各区域销售额",
  "user_id": "可选-用于行级权限",
  "thread_id": "可选-多轮对话"
}
```

| 项 | 说明 |
|----|------|
| Guduu 配置 | 工作流或 Webhook 中填写企业网关 URL |
| 企业侧 | 网关 + Guduu DI + 鉴权 |
| 优点 | 与 Guduu 解耦，可被多种 AI 复用 |
| 适用 | 已有 API 网关、多系统统一问数 |

---

### 模式 C：企业自动化编排（n8n / 自研调度）

**思路**：在企业内网用 **n8n、Make、自研任务服务** 编排：接收触发 → 调 Guduu DI → 将结果推到 Guduu 频道（Bot API）或企业 IM。

```
触发源（定时 / 企业 OA Webhook / Guduu 入站 Webhook）
    → 企业 n8n 工作流
    → HTTP 调 Guduu DI /api/v1/ask
    → 结果写入 Guduu 频道或企业系统
```

| 项 | 说明 |
|----|------|
| Guduu 配置 | 可选配置入站 Webhook 指向企业 n8n |
| 企业侧 | n8n + Guduu DI |
| 优点 | 快速试点、可视化编排 |
| 适用 | 报表推送、定时问数 |

---

## 4. Guduu DI API（企业对接面）

对接时，企业侧服务只需调用 **Guduu DI Web 服务** `http://<di-host>:3100`。

### 4.1 前置条件

已完成：数据源连接 → 建模 → **Deploy**（语义发布）。

### 4.2 核心端点

| 方法 | 路径 | 场景 |
|------|------|------|
| POST | `/api/v1/ask` | 一站式问数（生成 SQL + 执行 + 摘要） |
| POST | `/api/v1/generate_sql` | 仅生成 SQL |
| POST | `/api/v1/run_sql` | 执行 SQL |
| POST | `/api/v1/generate_summary` | 生成文字摘要 |
| POST | `/api/v1/generate_vega_chart` | 生成图表 spec |
| POST | `/api/v1/stream/ask` | SSE 流式问数 |
| GET | `/api/v1/models` | 已部署语义模型 |
| GET/POST | `/api/v1/knowledge/instructions` | 查询规则 |
| GET/POST | `/api/v1/knowledge/sql_pairs` | 示例问法 |

规范详见：`web-ui/openapi.yaml`

### 4.3 典型响应

```json
{
  "id": "response-uuid",
  "sql": "SELECT region, SUM(amount) FROM orders GROUP BY region",
  "summary": "本月华东区销售额最高……",
  "threadId": "conversation-uuid"
}
```

多轮对话：请求携带上次返回的 `threadId`。

### 4.4 Guduu DI 内部组件（企业部署脚本自动安装）

| 组件 | 端口 | 说明 |
|------|------|------|
| Guduu DI Web 服务 | 3100 | **对外对接入口** |
| Guduu DI AI 服务 | 5555 | 内部 LLM 管道 |
| Guduu DI 语义引擎 | 8080 | MDL 查询 |
| Guduu DI 数据连接器 | 8000 | 外部库连接 |
| Guduu DI 向量库 | 6333 | 语义索引 |

外部系统 **只需访问 3100**，其余端口不对 Guduu 平台暴露。

---

## 5. 企业实施范围

### 5.1 企业需完成的工作

| 序号 | 工作项 | 负责方 |
|------|--------|--------|
| 1 | 部署 Guduu DI（源码 `scripts/setup.sh`） | 企业运维 |
| 2 | 连接企业数据库（只读账号、视图） | 企业 DBA |
| 3 | MDL 建模与 Deploy | 企业数据分析师 |
| 4 | Instructions / SQL Pairs | 企业业务方 |
| 5 | 开发/部署 **企业对接网关或 Bot 服务** | 企业开发 |
| 6 | API 鉴权、网络放通（Guduu → 企业网关 → DI） | 企业运维 |
| 7 | 联调验收 | 企业项目组 |

### 5.2 数据库准备

| 项 | 说明 |
|----|------|
| 只读账号 | 专供 Guduu DI |
| 视图层 | `v_guduu_*` 隐藏敏感表 |
| 汇总表 | 大表性能优化 |
| 网络 | DI 服务器 → 库端口放通 |

支持：PostgreSQL、MySQL、SQL Server、Oracle、ClickHouse、BigQuery、Snowflake、Trino 等。

### 5.3 SaaS 仅提供 API 时

1. 企业自建同步任务，数据落入只读库/数仓  
2. Guduu DI 连接该只读库  
3. 不对 SaaS 直连（DI 以 SQL 为主）

### 5.4 权限与多租户

| 方案 | 做法 |
|------|------|
| 实例隔离 | 每事业部独立 DI 部署目录 |
| 行级权限 | 企业网关按 `user_id` 注入 SQL 条件或动态视图 |

---

## 6. 部署拓扑

### 6.1 Guduu DI 安装（企业侧）

```bash
cd guduu-di
export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash scripts/setup.sh
vim /var/guduu-di/env/.env    # OPENAI_API_KEY
bash scripts/start.sh
```

详见 [DEPLOY.md](../DEPLOY.md)

### 6.2 推荐拓扑

```
[Guduu 用户] → Guduu 平台 :8066
                    ↓（Bot API / Webhook）
              [企业 Bot / 对接网关]  （企业机房）
                    ↓
              [Guduu DI :3100]       （企业机房）
                    ↓ 只读
              [企业数据库]
```

### 6.3 高可用（可选）

- Guduu DI Web 服务多实例 + 负载均衡  
- 企业库只读副本专供 DI  
- 对接网关无状态水平扩展  

---

## 7. 观测与审计（企业侧）

| 维度 | 记录位置 |
|------|----------|
| API 调用 | 企业对接网关访问日志 |
| 问数明细 | 网关结构化日志 + DI `apiHistory` |
| SQL 审计 | 网关记录 `question` + `sql_hash` |
| 健康检查 | `curl :3100`、`curl :5555/health` |

建议网关日志格式：

```json
{
  "trace_id": "...",
  "user_id": "...",
  "question": "...",
  "di_thread_id": "...",
  "latency_ms": 1200,
  "status": "ok"
}
```

---

## 8. 分阶段路线（企业视角）

| 阶段 | 周期 | 交付 |
|------|------|------|
| **P0** | 1–2 周 | DI 部署 + 单库 MDL + curl 验证 `/api/v1/ask` |
| **P1** | 2–3 周 | 企业对接网关/Bot + Guduu 频道可问数 |
| **P2** | 1–2 月 | Instructions、图表、行级权限、审计 |
| **P3** | 持续 | 多数据源、HA、与更多企业系统联动 |

---

## 9. 风险与对策

| 风险 | 对策 |
|------|------|
| LLM 生成错误 SQL | MDL + 只读库 + SQL Pairs |
| DI 无内置鉴权 | 企业网关强制 Token |
| 大查询影响生产库 | limit、超时、汇总视图 |
| 口径不一致 | Instructions + 业务验收 |
| 对接范围不清晰 | 明确企业侧工作清单（见第 5 节） |

---

## 10. 参考文档

| 文档 | 说明 |
|------|------|
| [DEPLOY.md](../DEPLOY.md) | Guduu DI 源码部署 |
| [GUDUU_DI_ENTERPRISE_INTEGRATION_TUTORIAL.md](./GUDUU_DI_ENTERPRISE_INTEGRATION_TUTORIAL.md) | 企业实操教程 |
| `web-ui/openapi.yaml` | Guduu DI API 规范 |

---

*Guduu DI — 企业自建数据智能层，通过标准接口供 Guduu AI 调用企业数据。*
