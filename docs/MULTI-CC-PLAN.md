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
| CC-A wabot-ops(Fable) | 等桥重新部署 | R22.9;n8n 2.38.5;R22.10 黑名单同步已上线;18 个 TMP 已清理;**R22.11 Enquiry 计数已备好**(草稿 3375e1ca,harness 79→84 新增 0,当天整值覆盖);**通道结论(2026-09-13)**:主线 WhatsApp 走 Meta 官方 Cloud API 直连(graph.facebook.com/v23.0,系统用户凭证)= (a),ctwa_clid 尚未落库(后续加) | 等 CC-B 桥 v2 重新部署后改 count→value 并发布 | ① 桥重新部署后在 CC-A 窗口敲「上线 R22.11」;之后:B 成交记账 → C 跟进提醒;ctwa_clid 落库排进 R22.12 |
| CC-B social-engine(Opus 5) | 等老板重新部署 | Supabase social 14 表;Sheets bridge v1 已部署;**任务 0 结论**:主线正则 `/#FB_([A-Z]{2,8})\b/`,下划线后缀不兼容,v3.10 来源码定为连字符 `#FB_DNG-0911A`(docs/task0.md);**bridge v2 定稿**(enquiry/closed 整值覆盖+delta、spend>0、新增 sale/find/ping、blocklist 号码处理、表头容错)待部署;SE-09 干跑卡在 Meta token(190/460 已撤销) | 工具链/DEPLOY-SOP 进行中 | ① Apps Script 编辑器粘贴 Code.local.gs 覆盖 → 保存 → 部署 → 管理部署 → 铅笔 → 新版本 → 部署;② 重新生成 Meta 只读口令(wabot、永不过期、ads_read+read_insights,不带尖括号,生成后不再点撤销)贴进 CC-B 窗口;③ BotFather 换 social bot 口令 |
| CC-C tg-intel(Haiku) | idle | Telegram 语料 38 聊天 4312 条(3 个公共群 HTML 已转 JSON,为子集);REPORT-telegram-corpus.md;**data/insights/{DNG,GSD,FLX,RUM}.json**(每线 5 条痛点,脱敏);**gate-ad-words.json** 55 条三语禁词/灰区词草稿(21 条来自语料、11 条 Meta 政策需老板核实) | — | 有空时核一遍禁词表;3 个公共群若要他人消息需逐群导出(可选) |

教训(2026-09-11/12):Telegram 批量导出勾了媒体会跑一整天(10 GB),纯文字十几分钟;Haiku 处理带空格括号的路径与多 MB JSON 容易误判「截断」,先复制到项目内简单路径再解析;auto 模式对项目目录之外的路径每条命令都会问,用 /add-dir 一次解决。

云端巡检:周六 10:00Z、14:00Z 各一次;周日起可放宽到每 6 小时;安静模式不变。

## 7c. 进度快照(2026-09-13 15:20 UTC / 马来西亚 23:20,周日)

**授权信取消。** 老板指出公司资料在 Google Drive 里。主控读过经销合同(2025-09-30)、新手手册、公司通告后确认:分销商本来就可以自费做线上/线下广告、自建社媒账号(不得自称官方/总代),所以不必再向领导要授权信;docs/letters/ 两份草稿标记「已取消,保留备用」。合同原文属公司机密,不进本仓库(仓库是公开的)。

对 wabot / 广告 / 未来服务生意有约束力的几条(概括,不引原文):
- 内容只能用公司官方资料与说法,不得有未批准的疗效或专业身份宣称 → wabot 疗效词只做禁词,不做卖点。
- 零售价按公司公布,不得私自折扣/促销/送礼(有通告罚款先例) → 话术里「优惠/折扣」类词进禁词表。
- 找 KOL/直播要先经公司同意;官方素材不得改动 → 广告图/文案只能用公司批准的素材做排版,不能改内容。
- 客户资料属公司所有,只能用于卖公司产品 → 案例分析产物(脱敏)只服务主线,不复用到别家客户。
- 合同期内不能替其他健康类电商做经销/广告,也不能挖公司渠道的客户/代理 → 「一人公司服务」的客户来源必须是公司体系之外的行业(见 STRATEGY-90DAY-REVIEW.md)。
- 不得在 Shopee/Lazada 等平台上架。

**老板问「每一笔销售案例的打法和背后逻辑是否都已分析、保存、入库、让 wabot 分人分市场给最优策略」——诚实答案:未完成。** 截至 09-13 CC-C 只做了语料报告、4 条线各 5 条痛点、55 条禁词,没有按案例分析,也没进数据库,wabot 也没接。管线今天才派:

| 步 | 谁 | 内容 | 状态 |
|---|---|---|---|
| 1 | CC-A | 近 90 天 WhatsApp 会话脱敏导出到 wabot-intel/data/cases/wa-cases-*.jsonl(手机号打码,不进 git) | 15:07Z 已派,进行中 |
| 2 | CC-C | company-playbook.json(销售流程、P.E.P.C、黄金 7 天、每日例行、公司规矩 5 节)+ tools/case-analyze.mjs(每案:画像、入口、旅程阶段、异议与回应、成交触发点、流失点、合规标记、可复用打法)+ tools/strategy-cards.mjs(按线 × 画像聚合成策略卡,可回溯案例)+ README-strategy.md | 15:1xZ 已派,先用合成案例自测,导出到了再跑真实数据 |
| 3 | CC-B | 策略卡与案例分析入 Supabase social schema(新表 strategy_cards / case_analyses),含数据归属字段 | 待 2 出结果 |
| 4 | CC-A | R22.13:Brain 按来源码/首句/语言判画像 → 读策略卡 → 只在公司规矩范围内选话术;Core Logic 变更走 CLAUDE.md 三段哈希 + harness 三个数(新增失败 0) | 待 3;先做 R22.12 ctwa_clid 落库 |

IG 检查(CC-B):本机没有可用的 IG/FB 凭证,做不了自动核对,写了 docs/ig-readiness-check.md(social-engine 仓库,commit 34ed020)给老板自查:已连 FB 的 IG 是否为 Business 账号、有无 ≥9 帖、是否在同一 Business Portfolio。

## 8. 凭证规则更新:「只写不记」(老板 2026-09-11 授权)

- 子会话可以**写入**凭证到它该在的地方:n8n Credentials(经公共 API 或 UI 路径)、本机 `.env`、n8n 环境变量;来源只能是老板贴进该窗口的值、或该会话 `.env` 里已合法持有的值。
- 子会话**不记**:不打印、不回显、不写进仓库 / TASK / HANDOFF / 聊天,不转发给其他会话;需要引用时只写「已写入 <名称>」。
- 仍需老板亲手做的:在第三方后台**生成新秘密**(BotFather、Meta 系统用户 token、Supabase Dashboard、Google Cloud / Apps Script 部署),因为那些界面要他的登录。
- 破坏性操作(删工作流 / 删表 / 清执行记录 / 改 DNS / 改 webhook)与线上 Active 开关,规则不变:老板亲手。

## 9. 上线授权更新:「主控核对通过即可直接上线」(老板 2026-09-12 授权)

老板原话(2026-09-12 10:1xZ,针对 R22.10 黑名单同步的 4 步):「1. 确认 2. 你直接让他上线即可,我知道了 3. 批准 R22.10 上线,并且之后你检查后没问题也能直接上线,通知我即可 4. 没事,我相信你能做好」。

生效规则:
- 主控(云端)核对通过后,CC-A 可直接激活/发布工作流并通知老板,不再等老板在 n8n 手拨 Publish/Active。
- 「核对通过」的最低门槛不变:harness 回归三个数且新增失败 = 0;三段哈希证明;PUT 前预检(2.38 草稿机制对应处理);记录发布前后 versionId / activeVersionId;写好回滚点;上线后观察 30 分钟(入站正常回复、error 0、提醒只在命中时),异常立即回滚并报告。
- 仍然只有老板能做:破坏性操作(删工作流/删数据/清 TMP)、在第三方后台生成新凭证、Meta/Google/Telegram 后台的授权动作。
- 通知形式:上线后一条简短结果(做了什么、数字、回滚点);安静模式不变。
