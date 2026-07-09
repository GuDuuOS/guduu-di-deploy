# 企业内系统对接 Guduu — 实操教程

> **文档版本**：2026-06-24  
> **适用对象**：企业信息化人员、数据分析师、业务系统管理员  
> **目标**：在企业侧完成 Guduu DI 部署与对接，使 Guduu 内 AI 可查询企业业务数据。

---

## 你将完成什么

完成本教程后，企业将具备：

1. 自建 **Guduu DI** 服务，连接企业数据库并完成语义建模  
2. 自建 **企业对接服务**（Bot 或 API 网关），对外提供问数能力  
3. Guduu 用户在频道中通过 Bot 或对话提问，由企业侧服务调用 DI 返回答案  

```
Guduu 用户提问
    → 企业 Bot / 对接网关（企业自建，本教程第 6 步）
    → Guduu DI（企业部署，第 1–5 步）
    → 企业数据库
    → 结果回到 Guduu 频道
```

---

## 第 0 步：准备清单

### 0.1 角色分工（均为企业侧）

| 角色 | 负责内容 |
|------|----------|
| **运维** | 部署 Guduu DI、对接网关/Bot 服务器 |
| **DBA** | 只读库账号、视图、网络放通 |
| **业务分析师** | MDL 建模、指标口径、Instructions |
| **开发** | 企业 Bot 或对接网关（调用 DI API） |

### 0.2 软件依赖

| 软件 | 版本 |
|------|------|
| Node.js | 20.x 推荐 |
| Python | 3.11 + 3.12 |
| Poetry | 1.8.x |
| JDK | ≥ 21 |
| Yarn | 1.x / 4.x |
| Git / rsync | 任意 |
| **Guduu DI 源码** | SVN：`.../2026/Guduu-DI` |

> Guduu DI **仅支持源码部署**（`scripts/setup.sh`）。

### 0.3 网络规划

```
Guduu 服务器  ──能访问──▶  企业对接网关/Bot（企业机房）
企业对接服务      ──能访问──▶  Guduu DI :3100（企业机房）
Guduu DI          ──能访问──▶  企业数据库
```

Guduu DI 与对接服务建议部署在 **企业内网**，不对公网暴露。

---

## 第 1 步：部署 Guduu DI（源码安装）

完整说明见 [DEPLOY.md](../DEPLOY.md)。

### 1.1 获取源码

```bash
svn checkout \
  "http://192.168.42.7:13690/svn/zft/黄安其团队/2026/Guduu-DI" \
  /opt/guduu-di

cd /opt/guduu-di
```

### 1.2 初始化

```bash
export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash scripts/setup.sh
```

### 1.3 配置密钥

```bash
vim /var/guduu-di/env/.env
```

```bash
OPENAI_API_KEY=sk-xxxxxxxx
GUDUU_UI_PORT=3100
GUDUU_HTTP_PROXY=http://127.0.0.1:10808          # 可选
GUDUU_YARN_REGISTRY=https://registry.npmmirror.com  # 可选
```

### 1.4 启动与验证

```bash
export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash scripts/start.sh
bash scripts/status.sh

curl -sf http://127.0.0.1:3100/ | head -3
curl -sf http://127.0.0.1:5555/health
```

管理界面：`http://<DI服务器IP>:3100`

---

## 第 2 步：连接企业数据库

### 2.1 在 Guduu DI 界面配置

1. 打开 `http://<DI>:3100/setup/connection`  
2. 选择数据库类型（PostgreSQL、MySQL、ClickHouse 等）  
3. 填写 **只读账号** 连接信息  

### 2.2 DBA 授权示例（PostgreSQL）

```sql
CREATE USER guduu_readonly WITH PASSWORD '强密码';
GRANT CONNECT ON DATABASE erp_prod TO guduu_readonly;
GRANT USAGE ON SCHEMA public TO guduu_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO guduu_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT ON TABLES TO guduu_readonly;
```

### 2.3 推荐：使用视图

```sql
CREATE VIEW v_guduu_orders AS
SELECT order_id, region, amount, order_date, customer_name
FROM orders
WHERE deleted_at IS NULL;
```

建模时只选择 `v_guduu_*` 视图，不暴露敏感基表。

---

## 第 3 步：建模与发布（MDL）

### 3.1 选表与建模

1. 进入 **Modeling** 页面，勾选开放给 AI 的表/视图  
2. 表/字段改为业务中文名（如 `销售额`、`客户`）  
3. 配置表关联、计算指标  

### 3.2 发布（Deploy）

点击 **Deploy**。未发布前 API 无法问数。

验证：

```bash
curl -s http://127.0.0.1:3100/api/v1/models | head -50
```

---

## 第 4 步：配置查询知识（强烈建议）

### 4.1 Instructions（口径规则）

界面：**Knowledge → Instructions**

| 规则 | 示例 |
|------|------|
| 全局 | 销售额不含退货单，status 须为 completed |
| 区域 | 华东区 = 沪苏浙皖 |

API 方式：

```bash
curl -X POST http://127.0.0.1:3100/api/v1/knowledge/instructions \
  -H "Content-Type: application/json" \
  -d '{"instruction": "销售额排除 status=cancelled", "isGlobal": true}'
```

### 4.2 Question-SQL 对

| 问题 | SQL 示例 |
|------|----------|
| 本月销售额 | `SELECT SUM(amount) FROM 销售订单 WHERE …` |
| 各区域客户数 | `SELECT region, COUNT(*) FROM 客户 GROUP BY region` |

---

## 第 5 步：自测 Guduu DI API

对接服务开发前，确认 DI 本身正常。

```bash
# 一站式问数
curl -X POST http://127.0.0.1:3100/api/v1/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "本月销售额是多少", "language": "zh-CN"}'

# 仅生成 SQL
curl -X POST http://127.0.0.1:3100/api/v1/generate_sql \
  -H "Content-Type: application/json" \
  -d '{"question": "各区域销售额排名"}'

# 多轮（带上次 threadId）
curl -X POST http://127.0.0.1:3100/api/v1/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "那华东区呢？", "threadId": "<上一步返回>"}'
```

期望：`sql`、`summary`、`threadId` 字段合理。

---

## 第 6 步：对接 Guduu

以下三种方式均在 **企业服务器** 上实现，通过 Guduu 提供的 Bot API、Webhook 等标准接口完成对接。

---

### 方式 A：企业频道机器人（推荐）

**原理**：在 Guduu 管理后台创建 Bot 账号，企业服务器运行 Bot 程序，监听消息后调用 DI，再将结果发回频道。

#### A.1 Guduu 管理后台配置

1. 系统控制台 → 集成 → **Bot 账户** → 创建 Bot（如「企业数据助手」）  
2. 记录 **Bot Token**、将 Bot 加入目标频道  
3. 如需 Outgoing Webhook：配置回调 URL 指向企业 Bot 服务（`https://bot.enterprise.com/guduu/hook`）

#### A.2 企业 Bot 服务逻辑

```
收到用户消息（含 @企业数据助手 或关键词）
  → 解析 question
  → POST http://127.0.0.1:3100/api/v1/ask  （内网 DI）
  → 用 Bot Token 调用 Guduu API CreatePost，回复 summary
```

#### A.3 Python 示例（企业侧）

```python
import requests

DI_URL = "http://10.0.1.100:3100/api/v1/ask"
GUDUU_API = "https://guduu.company.com/api/v4"
BOT_TOKEN = "企业 Bot Token"
CHANNEL_ID = "频道 ID"

def handle_question(question: str, thread_id: str | None = None):
  body = {"question": question, "language": "zh-CN"}
  if thread_id:
    body["threadId"] = thread_id
  r = requests.post(DI_URL, json=body, timeout=120)
  data = r.json()
  post = {
    "channel_id": CHANNEL_ID,
    "message": f"**{question}**\n\n{data.get('summary', '')}\n\n```sql\n{data.get('sql', '')}\n```"
  }
  requests.post(
    f"{GUDUU_API}/posts",
    headers={"Authorization": f"Bearer {BOT_TOKEN}"},
    json=post,
  )
  return data.get("threadId")
```

> Bot 服务部署在企业机房，通过 Guduu REST API（`/api/v4/posts`）将问数结果回复到频道。

---

### 方式 B：企业对接 API 网关

适合：企业已有 API 网关，或希望多个系统统一调用问数能力。

#### B.1 网关对外接口（企业定义）

```http
POST https://api.enterprise.com/v1/data/ask
Authorization: Bearer <企业颁发给用户或系统的 Token>
Content-Type: application/json

{
  "question": "本月销售额",
  "user_id": "zhangsan",
  "thread_id": "可选"
}
```

#### B.2 网关内部转发

```python
# 企业网关内部
def ask_proxy(question, user_id=None, thread_id=None):
    # 可选：按 user_id 做行级权限
    r = requests.post(
        "http://10.0.1.100:3100/api/v1/ask",
        json={"question": question, "threadId": thread_id, "language": "zh-CN"},
        headers={"Authorization": "Bearer <网关到DI的内部Token>"},  # 若 DI 前有 Nginx 鉴权
    )
    return r.json()
```

#### B.3 与 Guduu 的连接

- 通过 Guduu 工作流或 Webhook 调用企业网关 URL（`https://api.enterprise.com/v1/data/ask`）  
- 或由 **方式 A 的 Bot** 内部调用本网关，统一鉴权  

---

### 方式 C：企业 n8n / 自动化编排

适合：快速试点、定时报表推送。

1. 在企业内网部署 **n8n**  
2. 工作流：Webhook 触发 → HTTP 调 `DI /api/v1/ask` → 结果通过 Bot API 发到 Guduu 频道  
3. 在 Guduu 管理后台配置 **入站 Webhook** 指向企业 n8n 地址

---

## 第 7 步：安全加固（企业侧）

### 7.1 网络

- Guduu DI `:3100` 仅内网可达  
- 对接网关对外 HTTPS，对内访问 DI  

### 7.2 API 网关（Nginx 保护 DI）

```nginx
location / {
    allow 10.0.1.0/24;   # 仅企业内网 / Bot 服务器
    deny all;
    proxy_pass http://127.0.0.1:3100/;
}
```

### 7.3 数据库

- 只读账号  
- 敏感字段不进 MDL  
- 大查询加 `LIMIT`  

---

## 第 8 步：验收

### 8.1 Guduu DI 验收

| # | 项 | 标准 |
|---|-----|------|
| 1 | 服务状态 | `status.sh` 全部 running |
| 2 | 数据源 | 界面可预览数据 |
| 3 | Deploy | `/api/v1/models` 有内容 |
| 4 | 问数 | `/api/v1/ask` 返回合理结果 |
| 5 | 口径 | Instructions 生效 |

### 8.2 端到端验收（Guduu + 企业对接）

| # | 项 | 标准 |
|---|-----|------|
| 1 | 频道提问 | @企业数据助手 或触发词可问数 |
| 2 | 结果 | 频道出现摘要/SQL |
| 3 | 多轮 | 追问带上下文 |
| 4 | 安全 | 外网无法直接访问 DI |
| 5 | 审计 | 企业网关有调用日志 |

---

## 第 9 步：日常运维

```bash
export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash scripts/status.sh
bash scripts/stop.sh
bash scripts/start.sh
tail -f /var/guduu-di/runtime/logs/web-ui.log
```

模型变更后：更新 MDL → 重新 Deploy → 补充 Instructions。

升级 DI：

```bash
cd /opt/guduu-di && svn update
export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash scripts/setup.sh && bash scripts/start.sh
```

---

## 常见问题

### Q1：对接 Guduu 需要哪些准备？

在企业侧完成 Guduu DI 部署后，在 Guduu 管理后台创建 Bot 账号（或使用 Webhook），由企业 Bot/网关服务调用 DI API 并将结果回复到频道。具体步骤见本教程第 6 步。

### Q2：问数返回 500 / 未部署

未完成 Deploy。建模后点击 Deploy，查看 `$GUDUU_DEPLOY_ROOT/runtime/logs/`。

### Q3：SQL 不准确

完善 MDL、Instructions、SQL Pairs。

### Q4：Guduu 访问不到 DI

检查防火墙：Bot/网关服务器 → DI `:3100` 内网放通。

### Q5：能否通过 DI 修改业务数据？

**不建议。** DI 使用只读库。写操作走企业业务系统 API，不经 DI。

### Q6：检出 SVN 后 Web 界面缺 GraphQL 代码

```bash
cd web-ui
yarn install && yarn generate-gql
```

---

## 附录 A：支持的数据源

| 类型 | 连接方式 |
|------|----------|
| PostgreSQL / MySQL / SQL Server / Oracle | Guduu DI 数据连接器 |
| ClickHouse / Trino / BigQuery / Snowflake | Guduu DI 数据连接器 |
| DuckDB / CSV | Guduu DI 语义引擎 |
| 仅 REST 的 SaaS | 先同步到企业只读库 |

---

## 附录 B：URL 速查

| 服务 | URL |
|------|-----|
| Guduu DI 管理界面 | `http://<di>:3100` |
| Guduu DI 问数 API | `POST http://<di>:3100/api/v1/ask` |
| Guduu DI 健康检查 | `http://<di>:5555/health` |
| Guduu API（Bot 发帖） | `POST https://<guduu>/api/v4/posts` |

---

## 附录 C：延伸阅读

| 文档 | 说明 |
|------|------|
| [GUDUU_DI_INTEGRATION_SOLUTION.md](./GUDUU_DI_INTEGRATION_SOLUTION.md) | 架构对接方案 |
| [DEPLOY.md](../DEPLOY.md) | Guduu DI 源码部署 |

---

*企业部署 Guduu DI 并建设对接服务后，即可在 Guduu 频道中实现自然语言问数。*
