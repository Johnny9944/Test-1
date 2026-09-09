---
name: n8n-deploy
description: wabot 生态里任何 n8n 工作流改动与部署的流程。要改 versions/ 里的工作流 JSON、部署到 n8n.daelifeai.com、加节点、改 Brain 提示词、碰凭证或线上激活状态时使用。规则来自 CLAUDE.md 第 1/2/3 节与老板的铁律。
---

# n8n-deploy

## 铁律(不可协商)

- **不用 REST 改 Active 或归档状态。** 这版 n8n 的激活 = 编辑器右上角「Publish」按钮,列表页 ⊖ 是 Archive。激活由老板亲手点;你只做内容更新与自测,然后告诉老板「可以 Publish」。
- **不 git push。** 本地 commit 即可。
- **不打印、不转述任何 token / key。** 凭证只放 n8n Credentials 或 `.env`,不进版本文件、不进执行数据、不进聊天。
- **凭证类与破坏性操作先停下问老板**(CLAUDE.md 铁律 B / C / C2):换 token、删工作流、删表、清执行记录、改 DNS、改 webhook 地址。
- **改 Core Logic(Brain)必须按 CLAUDE.md 第 1/2/3 节:** 三段哈希证明(改前 / 改后 / 部署后拉回)+ harness 回归报三个数(基线 / 本次 / 新增),新增失败必须为 0。

## 标准流程

1. **起版本文件。** 复制上一版 `versions/<名字>_<版本>.json` 成新版本号(例:R22.8 → R22.9;v3.9.19 → v3.9.20),只改需要改的节点;`settings.errorWorkflow` 指向 Monitor v2(XnFVzxSuSw33IjBI);成功执行不保存数据、失败保留(`saveDataSuccessExecution: none`)。
2. **本地自测。** 主线走 harness;FB 引擎走 dry-run(发帖节点禁用);校验 JSON 能被 n8n 导入。
3. **部署内容。** 用 REST `PUT /workflows/{id}` 只更新 `nodes / connections / settings`,不带 `active` 字段;不用 CLI import(会把工作流停掉)。
4. **字节核对。** 部署后 GET 拉回,对 nodes/connections 做规范化后比对哈希,写进 TASK.md 与 HANDOFF(哈希前 8 位)。
5. **回滚准备。** 上一版文件路径写进 HANDOFF;回滚 = 同样的 PUT 推回上一版。
6. **交给老板。** 回复格式:改了什么 → 三个数 → 哈希 → 「请到 n8n 打开 <工作流名> 核对后点 Publish」→ 回滚方式。
7. **记录。** 更新 TASK.md / HANDOFF-next-session.md,git commit(不 push)。

## 常见坑

- 老板点 ⊖ 以为是开关,其实是 Archive:发现工作流不见了先看「Show archived」。
- Error Workflow 下拉不显示已归档的工作流;设置后要 Save 再 Publish 才持久化。
- 新版 n8n 里 Publish 后才生效;只 Save 不生效。
- Monitor v2 是 30 分钟心跳到 Telegram;超过 45 分钟没心跳先查主线是否被归档。
- 编辑器直链偶尔触发 Chrome 安全页,从 Workflows 列表点进去即可。
