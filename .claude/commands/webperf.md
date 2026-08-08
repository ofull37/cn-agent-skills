---
description: 通过 web-performance-auditor 角色运行 Web 性能审计
---

`/webperf` 专门针对 Web 应用程序。不要将其用于工具库、CLI 或没有浏览器可见输出的纯服务端代码。

## 确定模式

**深度模式** — 当以下任一条件可用时启用：
- 一份 Lighthouse JSON 报告文件（例如 `npx lighthouse <url> --output json --output-path ./report.json`，或来自 Chrome DevTools MCP CLI 的 `npx -p chrome-devtools-mcp chrome-devtools lighthouse_audit --output-format=json`）
- PageSpeed Insights 的 JSON 响应（包含 Lighthouse + CrUX）
- CrUX API 的响应（需要 `CRUX_API_KEY` 或 `GOOGLE_API_KEY`）
- DevTools 性能 trace
- 一个在线 URL，且在 harness 中配置了 `chrome-devtools` MCP 服务器（代理可以直接通过 `lighthouse_audit` 和 `performance_*` 工具捕获指标）
- 在本地调用 Chrome DevTools MCP CLI（通过 `npx -p chrome-devtools-mcp chrome-devtools <tool>` 或先执行 `npm i -g chrome-devtools-mcp`）——用户运行类似 `chrome-devtools lighthouse_audit --output-format=json` 的命令，并将 JSON 输出传给代理

**快速模式** — 当以上条件都不可用时作为默认。代理扫描源代码中的结构性反模式，并将每项发现标记为 `potential impact`。

## 运行审计

创建 `web-performance-auditor` 子代理。显式地传给它：

- 待评审的文件、组件或 diff
- 任何产物路径（Lighthouse JSON、PSI JSON、CrUX 响应、trace）或粘贴的 JSON 内容
- 已知的目标 URL 或页面名称
- 说明你期望的模式（Quick 或 Deep），以便在意图使用 Deep 模式时代理能指出缺失的输入

子代理返回一份记分卡（仅填充有来源依据的值）、按优先级排序的发现列表、正面观察以及主动提出的建议。

## 输出

将完整的审计报告返回给用户。无需综合或合并步骤——这是一个单角色命令。
