# 多 CC 并行作战计划(wabot 生态)

更新:2026-09-10 · 维护者:云端主控(session_017NQg…am1r)

## 0. 结论:能不能同时带 3–5 个 CC

能,但有三个物理限制,先说清楚:

1. **终端要你开。** 每个本地 CC 会话 = 你电脑上的一个终端标签 + `/rc`。我从云端只能派单(触发器)、读状态、汇总,不能替你开终端、也不能替你点权限提示。
2. **用量按账号共享。** 5 小时滚动窗口是整个账号的,不是每个会话各一份。同时跑 3 个重活会更快撞限额;撞了我会暂停派单并告诉你。
3. **同一仓库要隔离。** 两个会话同时改同一个文件会互相覆盖,所以 wabot 仓库用 git worktree 分目录,线上部署只归 CC-A。

我的角色 = 主控大脑:派单(create_trigger → fire → delete)、巡检(get_session,每小时,有 pending_action 就提醒你点同意)、汇报、维护本文件和各会话的启动提示词。

建议同时活跃:**2 个重活会话 + 1 个轻量分析会话**,再加我。

## 1. 会话编制

| 代号 | 工作目录(Windows) | 职责 | 权限模式 | 状态 |
|---|---|---|---|---|
| CC-A · wabot-ops | `C:\Users\lim_2\Documents\wabot` | 线上运营:FB 发帖收尾、主线维护、n8n 版本部署、老板待办跟进 | default(非 auto,发帖/部署弹窗你点同意) | 等你 `/rc` 接回 |
| CC-B · social-engine | `C:\Users\lim_2\Documents\social-engine`(新建) | 多平台发帖 + 监控系统,按 SPEC-social-engine.md 施工 | default | 等方案定稿后创建 |
| CC-C · tg-intel | `C:\Users\lim_2\Documents\wabot-intel`(wabot 的 git worktree) | Telegram 语料解析、痛点库、话术库、脱敏 | auto 可(纯本地分析) | 等 CC-A 建好 worktree |
| 云端(我) | GitHub Johnny9944/Test-1 · docs/ | 研究、方案、派单、巡检、汇报 | auto | 运行中 |

三个启动提示词在 `docs/kickoff/`,直接整段贴进对应会话。

## 2. 开第二、第三个会话的步骤(Windows 11 + Windows Terminal)

以下步骤已对照 Claude Code 官方文档核实(2026-09-10):

1. 开 Windows Terminal,按 `Ctrl+Shift+T` 开新标签;右键标签 → Rename Tab 改成会话代号(CC-A / CC-B / CC-C)。
2. `cd C:\Users\lim_2\Documents\<该会话的目录>`(worktree 从它自己的目录进,不要在主仓库里进 worktree 子目录)。
3. 第一次:`claude -n CC-B`(给会话命名);以后接回:`claude --resume CC-B`。同一目录多个会话时不要用 `claude --continue`,它只接最近的那一个。
4. 进去后输入 `/rc CC-B`(带名字,手机端列表就叫这个名)。页脚出现 `/rc active` 即接上。
5. 第一条消息贴 `docs/kickoff/` 里对应的整段提示词。我在云端用会话标题认它。
6. `Shift+Tab` 循环切权限模式(auto → default → acceptEdits → plan);Windows 上没反应就按 `Alt+M`。CC-A / CC-B 用 default(发帖、部署会弹窗到手机),CC-C 可 auto。手机端只能选 Manual / Accept edits / Plan,选不了 Auto。

重启电脑或关掉终端后:同一目录 `claude --resume <名字>` 接回完整对话,并自动重连**同一个**远程会话 ID(2026-09-09 实测:CC-A 重启后 ID 不变)。只有当你在手机上删过该会话、或在电脑上手动关过 /rc 再退出时,才会得到新 ID;我会重新扫描并派单,你不用告诉我 ID。

同一仓库开第二个会话的官方做法是 git worktree(`git worktree add ..\wabot-intel -b intel/telegram-corpus`,CC-A 已建),Claude Code 会阻止 worktree 里的会话改主目录的文件。worktree 是全新 checkout,`.env` 等被 gitignore 的文件不会自动出现。
## 3. 派单与汇报协议

- 每个会话根目录一个 `TASK.md`(当前任务 / 状态 / 下一步)+ `HANDOFF-next-session.md`;每轮结束 `git commit`,**不 push**。
- 共享资源归属:只有 CC-A 能改 wabot 的 `versions/` 与线上;CC-C 只在 worktree 分支 `intel/*` 改 `tools/`、`products-input/`,合并由 CC-A 审后做;CC-B 独立仓库,但要用 wabot 的 n8n / Supabase 凭证时,凭证放在 CC-B 目录的 `.env`(不进 git),不复制 wabot 的文件。
- 我每小时巡检一次;会话停在权限提示(pending_action)超过 20 分钟,我会在这里提醒你。
- 派单消息大小:fire_trigger 附带 40 KB 以上的文本会送不到本地会话(返回一个不存在的会话 ID)。长文档分段发,每段 ≤ 15 KB,放在触发器的 prompt 里,让会话按段号拼接。2026-09-10 送 SPEC 时踩过。
- 铁律对所有会话一致:不 push、不打印 token、不用 REST 改 Active、凭证类与破坏性操作先问你、改 Brain 走三段哈希 + harness 回归。

## 4. 每个会话的第一阶段任务

- **CC-A**:① 首帖改新版式 + 发眼护/关节/鹿肽素三条并核对来源码;② 核对主线 errorWorkflow 是否指向 Monitor v2;③ 列 TMP 临时工作流清单给你 UI 删;④ FB 引擎 dry-run 后告诉你能不能 Publish 排程;⑤ 建 CC-C 的 worktree。
- **CC-B**:按 SPEC-social-engine.md 的 Phase 0 施工(见 docs/SPEC-social-engine.md 与 docs/kickoff/CC-B-social-engine.md)。
- **CC-C**:用现有(不完整的)导出先把解析管线跑通,加脱敏与增量导入;你重新导出后重跑出报告,再映射到 4 条产品线的洞察草稿。

## 5. 限额与节奏

- 用量限制是账号级的:5 小时滚动窗口 + 周限额,claude.ai 聊天、Claude Code、手机 App 全部算在一起;并行 N 个会话大约按 N 倍消耗。2026-09-09 晚三个会话并行 3 小时就撞到了 5 小时窗口(03:30 MYT 重置)。
- 优先级:CC-A(线上收入相关)> CC-B(新增长)> CC-C(分析,可随时暂停)。接近上限先停 CC-C。
- 撞限后:终端里的会话会显示「Usage limit reached · continuing automatically at …」自动等待;从手机端操作的会话不会自动等,需要回电脑输入 `/rate-limit-options`。
- 每条请求都会重发整段对话;会话太长时先让它把状态写进 TASK.md,再 `/compact`。
- 在任一会话输入 `/usage` 看窗口余量。
## 6. 云端已经开始做的(不需要你)

- 5 个 skill 的调研与安装命令核实 → `docs/SKILLS-EVAL.md` + `docs/install-skills.ps1`
- 多平台发帖 + 监控系统方案(三角度设计 → 两评委 → 合成 → 批评 → 修订)→ `docs/SPEC-social-engine.md` + `docs/kickoff/CC-B-social-engine.md`
- Remote Control 多会话机制核实 → 本文件第 2、5 节

## 7. 进度快照(2026-09-09 21:17 UTC / 马来西亚 05:17)

| 会话 | 状态 | 已完成 | 等你 |
|---|---|---|---|
| CC-A wabot-ops | idle | 4 帖已发并验证;harness 68/68 + 7 新;R22.9 备好(75/0,主 Brain 未动);备份已验证 | ① 部署时间窗 ② errorWorkflow 设置 ③ Brain 改动 S-7/S-3/B-2/S-8 批准 ④ Supabase 备份 |
| CC-B social-engine | idle | SPEC 三段拼齐存档;Phase 0 离线部分 34 项交付已 commit;`需要老板.md` 已写到项目根目录(commit 759d46d,5 项决策 + 21 条阻塞) | 打开 `需要老板.md` 逐条回;.env keys;n8n ≥ 2.28.1;Business Portfolio + App Live;IG 新号两周养号;系统用户 token 走 Header Auth;新社交 bot;合规文件;Vault salt 离线备份 |
| CC-C tg-intel | idle | 四线词典(313–388 词)、200 条合成 fixture、导入监听脚本;自测 336/0;commit 517f518 | Telegram 重新导出(完整版) |

云端巡检节奏:安静模式,有待办 30 分钟、无待办 90 分钟;00:00 UTC(08:00 MYT)写唯一一份晨报。

## 7b. 进度快照(2026-09-12 06:05 UTC / 马来西亚 14:05,周六)

| 会话 | 状态 | 已完成 | 进行中 | 等你 |
|---|---|---|---|---|
| CC-A wabot-ops(Fable) | 派单中 | R22.9 上线并核对;**n8n 2.1.4 → 2.38.5 升级完成**(02:00Z 自动执行,02:30Z 心跳成功,Monitor #450 / R22.9 #451 绿,4 个工作流 active 且 versionId 前后一致,API 200,零错误,旧容器保留可回滚);TASK.md 已记「2.38.5 起 PUT 须带 ?publishIfActive=false」 | 任务 A 黑名单同步 R22.10:只读核对 → dry-run 数字 → harness 三个数 → 待发布(BL-sync 新工作流未激活;主线改动 PUT 带 publishIfActive=false) | ① R22.10 待发布后:n8n 里 Publish BL-sync,主线改动回一句「批准 R22.10 上线」 ② 18 个 TMP 的「删」 |
| CC-B social-engine(Opus 5) | 派单中 | Supabase social schema 14 表 + v_funnel_weekly;Apps Script「Sheets bridge」已由老板部署并测通(密钥按只写不记自生成并写入 .env / n8n 凭证);SE-09 广告花销→Ratio report 草稿就绪 | 确认桥有 GET ?action=blocklist(缺则加,需老板「管理部署→新版本」重新部署);写 from-cc-b\\bridge-for-cc-a.md | Meta 只读 token:系统用户分配广告账户(查看效果)+ 生成新 token 只勾 ads_read / read_insights → 贴进 CC-B 窗口(只写不记) |
| CC-C tg-intel(Haiku) | idle | Telegram 完整导出(60 聊天,10 GB 含媒体)已处理:38 聊天 / 4.3K 消息;REPORT-telegram-corpus.md + 按产品线痛点/异议初稿(Documents\\wabot-intel) | — | 3 个公共群逐群「导出聊天记录」(JB Flexguard NEW Market🔥 / GesunD素材库 2.0 / Ruume 先锋者🦌,去掉媒体、JSON);建议 CC-C 切 Sonnet;BotFather /revoke 泄露过的 bot token |

教训(2026-09-11/12):Telegram 批量导出勾了媒体会跑一整天(10 GB),纯文字十几分钟;Haiku 处理带空格括号的路径与多 MB JSON 容易误判「截断」,先复制到项目内简单路径再解析;auto 模式对项目目录之外的路径每条命令都会问,用 /add-dir 一次解决。

云端巡检:周六 10:00Z、14:00Z 各一次;周日起可放宽到每 6 小时;安静模式不变。

## 8. 凭证规则更新:「只写不记」(老板 2026-09-11 授权)

- 子会话可以**写入**凭证到它该在的地方:n8n Credentials(经公共 API 或 UI 路径)、本机 `.env`、n8n 环境变量;来源只能是老板贴进该窗口的值、或该会话 `.env` 里已合法持有的值。
- 子会话**不记**:不打印、不回显、不写进仓库 / TASK / HANDOFF / 聊天,不转发给其他会话;需要引用时只写「已写入 <名称>」。
- 仍需老板亲手做的:在第三方后台**生成新秘密**(BotFather、Meta 系统用户 token、Supabase Dashboard、Google Cloud / Apps Script 部署),因为那些界面要他的登录。
- 破坏性操作(删工作流 / 删表 / 清执行记录 / 改 DNS / 改 webhook)与线上 Active 开关,规则不变:老板亲手。
