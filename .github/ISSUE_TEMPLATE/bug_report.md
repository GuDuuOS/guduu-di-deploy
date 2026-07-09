> ## Guduu DI
>
> **Guduu DI** — 企业级数据智能平台。
>
> 产品名称、Logo 与界面品牌均为 **Guduu DI**。

---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. Scroll down to '....'
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Screenshots**
If applicable, add screenshots to help explain your problem.

**Desktop (please complete the following information):**
- OS: [e.g. iOS]
- Browser [e.g. chrome, safari]

**Guduu DI Information**
- Version: [e.g, 0.1.0]

**Additional context**
Add any other context about the problem here.

**Relevant log output**
- 请分享 `$GUDUU_DEPLOY_ROOT/env/.env`（脱敏后）与 `$GUDUU_DEPLOY_ROOT/app/ai-service/config.yaml`
- 日志位于 `$GUDUU_DEPLOY_ROOT/runtime/logs/`：
    ```bash
    tail -n 200 "$GUDUU_DEPLOY_ROOT/runtime/logs/web-ui.log"
    tail -n 200 "$GUDUU_DEPLOY_ROOT/runtime/logs/ai-service.log"
    tail -n 200 "$GUDUU_DEPLOY_ROOT/runtime/logs/engine.log"
    tail -n 200 "$GUDUU_DEPLOY_ROOT/runtime/logs/ibis.log"
    ```
