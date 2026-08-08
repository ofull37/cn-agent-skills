---
description: 运行 TDD 工作流——编写失败测试、实现、验证。对于 bug，使用 Prove-It 模式。
---

调用 cn-agent-skills:test-driven-development 技能。

对于新功能：
1. 编写描述预期行为的测试（它们应该失败 FAIL）
2. 实现代码让它们通过
3. 在保持测试通过的同时进行重构

对于 bug 修复（Prove-It 模式）：
1. 编写一个能复现该 bug 的测试（必须失败 FAIL）
2. 确认测试失败
3. 实现修复
4. 确认测试通过
5. 运行完整测试套件以检查回归

对于浏览器相关问题，还需调用 cn-agent-skills:browser-testing-with-devtools，使用 Chrome DevTools MCP 进行验证。
