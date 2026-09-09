# 5 个 Claude Code Skill 评估(wabot 视角)

评估日期 2026-09-10 · 方法:每个 skill 一个调研代理读一手来源(仓库、npm、官方文档),再由独立审核代理逐条反驳并实测安装命令。所有仓库都真实存在,来源可靠;结论差别在「现在对 wabot 有没有用」。

## 一句话结论

| Skill | 是什么 | 对 wabot 现在的用处 | 结论 |
|---|---|---|---|
| **Find Skills**(vercel-labs/skills) | 教 Claude 上 skills.sh 搜第三方 skill 并劝你装的纯文本 skill | 五个目标场景没有一个直接受益;它引导安装未审阅的第三方 SKILL.md,而 wabot 环境里有永不过期的 Page Token、Supabase service key | **暂不装**。以后需要找现成 skill 时用两条 PowerShell 手动装并改成手动触发 |
| **Stop Slop**(hardikpandya) | 16 KB 纯 Markdown,英文「去 AI 腔」写作规则 | 规则全针对英文(-ly 副词、破折号、被动语态);线上文案由 n8n + OpenAI 生成,Claude Code 里的 skill 管不到;作者 2026-03 后停更 | **暂不装英文版**。要用就装中文版 stop-slop-zh 并设手动触发;更有效的是把中文禁词写进 OpenAI prompt 与 Gate |
| **Claude Mem**(thedotmack) | 常驻 worker + 6 段 hook,抓取每次工具调用压缩成跨会话记忆 | 唯一对口「多会话共享记忆」,但 Claude Code 2.1 已自带 auto memory,加上我们的 TASK.md / HANDOFF 已够用;它会把 Claude 读过的所有文件(含 .env、工作流 JSON 里的 token)明文存进本地库;Windows 上 5 个以上未修 bug;项目刚改名 Grok Mem 并推广加密代币 | **不装** |
| **UI/UX Pro Max**(nextlevelbuilder) | 本地 CSV 设计知识库 + Python 检索脚本,126k star | 只在「做网页监控面板」时有用;现在 Monitor v2 走 Telegram 文字告警,还没到那步;会一并装 7 个子 skill,讨论 FB 帖子时容易误触发 | **以后做面板时再装**(插件市场路线,装后删掉 6 个子 skill) |
| **Task Observer**(rebelytics) | 记录「你在哪里纠正了 Claude」,帮你迭代自建 skill;不是多任务监控 | 名字误导:它观察的是你做事的方式,不是任务进度;前提是先有自建 skill 可改进;每会话固定约 1.1 万 token;Windows 必须 Git Bash | **等 wabot 有 ≥3 个自建 skill 再装** |
| skills CLI(`npx skills`) | 装 skill 的包管理器,不是 skill | 工具而已;需 Node ≥ 22.20 与 Git;Windows 要加 `--copy` 并关遥测 | 需要时用,固定版本 1.5.25 |

**更值得现在做的事**:把 wabot 自己的硬规则写成两个项目 skill,让每个 CC 会话自动遵守。草稿已在 `docs/skills/`:

- `fb-copy-gate`:社媒文案规则(首句点名产品、分段、马来西亚保健品广告禁语、HALAL、帖尾来源码 + encode 后的 wa.me、中文去 AI 腔)。
- `n8n-deploy`:n8n 改动与部署流程(versions/ 版本文件、REST 只改内容不改 Active、字节核对、回滚、老板手动 Publish、凭证不进执行数据、Brain 三段哈希 + harness 三个数)。

CC-A 会把它们放进 `wabot\.claude\skills\`,CC-B 放 `n8n-deploy` 进 social-engine。

## 各 skill 细节

### Find Skills
- 仓库 https://github.com/vercel-labs/skills,文件 `skills/find-skills/SKILL.md`,Vercel 官方,MIT,30.8k star。
- 无常驻进程、无 API key。`npx skills find` 会把搜索词发到 skills.sh 与 Vercel 遥测端点;`DISABLE_TELEMETRY=1` 可关。
- 真正的风险是供应链:它的目的就是引导安装任意 GitHub 仓库的 SKILL.md,而 SKILL.md 会指挥 Claude 执行命令。
- 若装:加一行 `disable-model-invocation: true` 改成只有手动 `/find-skills` 才触发;每个候选 skill 装前先读完 SKILL.md。

### Stop Slop
- 仓库 https://github.com/hardikpandya/stop-slop,7 个文件 16 KB,MIT,约 17k star;作者 2026-03-18 后零回应,23 个 PR 无一处理。
- 已知问题:会让模型按约 80 列硬换行(issue #56),WhatsApp 会原样显示断行;示例自身违反自己的规则。
- 中文替代:https://github.com/VincentOld/stop-slop-zh(77 star,单次提交,成熟度低)。真正对每条帖子生效的做法是把中文禁词表挑一部分写进 n8n 里 OpenAI 的 system prompt 与 Gate 黑名单,不增加月费。

### Claude Mem
- 仓库 https://github.com/thedotmack/claude-mem,Apache-2.0,93.6k star,npm 13.24.5(2026-09-09)。
- 机制:Bun 托管的 HTTP worker(127.0.0.1:37777)+ SQLite + Chroma 向量库;默认用 haiku 压缩,消耗你自己的订阅额度;npx 安装器默认引导登录 cmem.ai 云端(USD 30/月),必须 `--provider claude` 才纯本地。
- 抓取面:PostToolUse 匹配 `*`,Claude 读过的每个文件都会进本地明文库,与「凭证不能进执行数据」直接冲突。
- Windows 未修 issue:#3901 worker 随进程死、#3899 幽灵端口、#3873 每 7 秒弹黑窗、#3865 用户名含非 ASCII 时 ENOENT、#3835 安装中断、#3940 市场路线版本不一致导致 worker 反复被杀。
- 重新评估条件:上述 issue 关闭,且原生 auto memory 明显不够用。

### UI/UX Pro Max
- 仓库 https://github.com/nextlevelbuilder/ui-ux-pro-max-skill,MIT,126k star,2026-09-06 仍在更新,有中文 README。
- 核心脚本离线、无遥测、无 API key;但子 skill `ui-styling` 会 `npx shadcn add` 联网改项目文件,`design` 子 skill 需要 Gemini 等图片 API key。
- Windows:先 `py -3 --version` 确认 Python;关闭「应用执行别名」里的 python.exe / python3.exe。
- 推荐安装(到时候):会话内 `/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill` → `/plugin install ui-ux-pro-max@ui-ux-pro-max-skill`,装后删掉 design、banner-design、brand、design-system、slides、ui-styling 六个子目录。

### Task Observer
- 仓库 https://github.com/rebelytics/one-skill-to-rule-them-all,CC BY 4.0,2.5k star,v3.1.0(2026-09-04)。
- 纯本地文本,不联网;但观察记录会引用你的工作内容(文案原文、产品名、客户信息),需在 CLAUDE.md 加「不得写入 token / 手机号 / 客户姓名」。
- Windows:所有强制片段是 bash(find/awk/grep),必须 Git for Windows;作者自己开的 issue #77 承认 PowerShell 不受支持。
- 推荐安装(到时候):下载 v3.1.0 的 .skill 包(SHA256 `82ab3e70…8433`)解压到 `%USERPROFILE%\.claude\skills`,再把激活块写进 CLAUDE.md,工作区放 `~/.claude/task-observer-workspace`。

### skills CLI(npx skills)
- npm 包 `skills` 1.5.25,Vercel Labs,MIT,运行时依赖只有 tar + yaml,无 postinstall。
- Windows 三个坑:PowerShell 5.1 默认执行策略挡住 `npx.ps1`(用 `npx.cmd` 或 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`);默认用 junction 链接,加 `--copy`;`update` 会把 copy 改回链接(issue #1199),Windows 上不要用 update,直接重跑 add。
- 在 Claude Code 里运行时自动非交互:不带 `--skill` 会静默装整个仓库的全部 skill,同名会静默覆盖你自写的 skill(issue #1906)。永远带 `--skill` 和 `-a claude-code`,自写 skill 起独特名字。

## 安装前置(Windows 11)

```powershell
node -v          # 需要 >= 22.20.0,否则 winget install OpenJS.NodeJS.LTS
git --version    # 需要 Git for Windows,否则 winget install Git.Git
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned   # 只做一次;不想改就把 npx 写成 npx.cmd
[Environment]::SetEnvironmentVariable("DISABLE_TELEMETRY","1","User"); $env:DISABLE_TELEMETRY="1"
```

装完在 Claude Code 里输入 `/skills` 核对;若 `%USERPROFILE%\.claude\skills` 目录在会话开始前不存在,要重启 Claude Code 一次(anthropics/claude-code #92129 仍 open,Windows 偶发不识别)。

## 已核实的安装命令(需要时用)

见 `docs/install-skills.ps1`,每个 skill 一个开关参数,默认什么都不装。
