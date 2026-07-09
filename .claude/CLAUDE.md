> ## Guduu DI
>
> **Guduu DI** — 企业级数据智能平台。
>
> 产品名称、Logo 与界面品牌均为 **Guduu DI**。

# CLAUDE.md

Guduu DI is an open-source GenBI (Generative BI) agent that converts natural language questions into SQL queries and charts. It uses a semantic layer (MDL - Metadata Definition Language) to guide LLM-powered text-to-SQL generation via retrieval-augmented generation (RAG).

## Repository Structure

This is a monorepo with two main services:

- **web-ui/** — Next.js 14 frontend + Apollo GraphQL backend (TypeScript, Yarn 4.5.3)
- **ai-service/** — AI/LLM service (Python 3.12, FastAPI, Poetry)
- **scripts/** — Source deployment (setup / start / stop / status)
- **mdl/** — MDL JSON schema definitions

Semantic engine is cloned to `$GUDUU_DEPLOY_ROOT/semantic-engine` at setup time.

## Build, Test, and Lint Commands

### web-ui (TypeScript/Next.js)

```bash
cd web-ui
yarn install
yarn dev                # Dev server on port 3000 (TZ=UTC)
yarn build              # Production build (max-old-space-size=8192)
yarn lint               # TypeScript type check + ESLint
yarn check-types        # tsc --noEmit
yarn test               # Jest unit tests
yarn test:e2e           # Playwright E2E tests (installs chromium)
yarn migrate            # Knex database migrations
yarn rollback           # Knex migration rollback
yarn generate-gql       # GraphQL codegen from codegen.yaml
```

Environment: set `DB_TYPE=sqlite` (default) or `DB_TYPE=pg` with PostgreSQL connection vars. Copy `web-ui/.env.local.example` and point backend endpoints at running services (engine, AI service, ibis-server).

### ai-service (Python/FastAPI)

```bash
cd ai-service
poetry install
just init               # Creates config.yaml and .env.dev from examples
poetry run python -m src.__main__   # Run AI service
just test               # pytest
just test [test_args]   # e.g., just test tests/pytest/pipelines/
just test-usecases      # Run use-case integration tests
just load-test          # Locust load tests
```

For full stack, use `bash scripts/setup.sh && bash scripts/start.sh` from repo root (see DEPLOY.md).

Configuration is via `config.yaml` (multi-document YAML with sections for LLM, embedder, engine, document_store, pipeline, and settings). Environment variables in `.env.dev` (API keys). Settings load order: defaults → env vars → .env.dev → config.yaml.

Pre-commit hooks: `poetry run pre-commit install` then `poetry run pre-commit run --all-files`

### launcher (Go)

Removed — Guduu DI uses source deployment only via `scripts/`.

## Architecture

### Service Communication Flow

```
User → Guduu DI Web UI (Next.js :3000)
         ↓ GraphQL (Apollo Server embedded in Next.js API routes)
       Apollo Server → Guduu DI AI Service (FastAPI :5556) [HTTP REST]
                     → 语义查询引擎 (:8080) [SQL validation/execution]
                     → Ibis Server (:8000) [SQL abstraction for data sources]
       Guduu DI AI Service → Qdrant (:6333) [vector search for RAG]
                       → LLM Provider (OpenAI/Azure/etc.) [text-to-SQL generation]
```

### Guduu DI Web UI Internal Architecture

The Next.js app embeds an Apollo GraphQL server in its API routes (`src/apollo/`):

- **`src/apollo/server/resolvers/`** — GraphQL resolvers (asking, model, project, dashboard, etc.)
- **`src/apollo/server/services/`** — Business logic layer (askingService, deployService, mdlService, queryService, etc.)
- **`src/apollo/server/repositories/`** — Data access layer using Knex (SQLite or PostgreSQL)
- **`src/apollo/server/adaptors/`** — External service adapters (AI service, engine)
- **`src/apollo/client/`** — Frontend GraphQL operations
- **`src/components/`** — React components organized by page (home, setup, modeling, knowledge)
- **`src/pages/`** — Next.js page routes

Path aliases: `@/*` → `./src/*`, `@server/*` → `./src/apollo/server/*`

### Guduu DI AI Service Internal Architecture

The Python service uses a pipeline-based architecture:

- **`src/pipelines/`** — RAG pipeline implementations:
  - `indexing/` — MDL schema, table descriptions, historical questions, SQL pairs → Qdrant
  - `retrieval/` — Semantic search for relevant context from Qdrant
  - `generation/` — SQL generation, chart generation, intent classification
  - `ask/` — Orchestrates retrieval + generation for text-to-SQL
  - `ask_details/` — SQL breakdown and explanation
  - `semantics/` — Semantic processing helpers
- **`src/web/v1/services/`** — Service layer (AskService, SemanticsPreparationService, ChartService, SqlPairsService, etc.)
- **`src/web/v1/routers/`** — FastAPI route handlers
- **`src/core/`** — Base abstractions (pipeline, provider, engine interfaces)
- **`src/globals.py`** — ServiceContainer wiring all services and pipelines together
- **`src/config.py`** — Pydantic Settings with all configuration knobs

Pipelines are configured declaratively in `config.yaml`, wiring LLM providers, embedders, document stores, and engines to named pipeline components.

### Data Flow for "Ask" (Text-to-SQL)

1. User submits natural language question in UI
2. UI sends GraphQL mutation to Apollo Server
3. Apollo Server calls AI Service REST API
4. AI Service runs intent classification → retrieves relevant schema/context from Qdrant → generates SQL via LLM
5. Generated SQL is validated against 语义查询引擎
6. SQL corrections are attempted if validation fails (up to `max_sql_correction_retries`)
7. Results returned through the chain back to UI

### MDL (Metadata Definition Language)

The semantic layer that maps business concepts to database schema. Defines models, columns, relationships, metrics, and calculated fields. MDL is indexed into Qdrant as vector embeddings to provide context for LLM SQL generation. Schema defined in `mdl/mdl.schema.json`.

## Source Deployment

```bash
export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash scripts/setup.sh
bash scripts/start.sh
```

See [DEPLOY.md](../DEPLOY.md) for full instructions.

## Commit Convention

Follows conventional commits: `type(scope): description`
- Scopes: `web-ui`, `ai-service`, `launcher`
- Types: `feat`, `fix`, `chore`, `refactor`
- Examples: `feat(web-ui): add dashboard widget`, `fix(ai-service): handle empty MDL`

## CI/CD

- PR labels trigger service-specific CI: `ci/ui` for UI tests/lint, `ci/ai-service` for AI service tests
