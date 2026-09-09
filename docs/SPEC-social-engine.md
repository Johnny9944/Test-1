# SPEC-social-engine.md — wabot 多平台发帖 + 监控系统(终稿 v1.1)

> 版本 v1.1 · 2026-09-09(周三)· 在 v1.0(方案 A 骨架 + 方案 B 归因/凭证卫生 + 方案 C 合规清单)基础上按第二轮评审修订:部署核对改核「已发布快照」;Meta/Threads 凭证一律 Header Auth,Threads token 在 n8n 内自动交换写回;新增 SE-00 Router;SE-06 加错误码分级/防抖/恢复;Supabase 专用角色直连;指标去 reach;合规数字更正;Phase 0 改 7–10 个工作日。平台数字来自二手来源交叉核实(developers.facebook.com / developers.tiktok.com 被代理拦截),标「待核实」者施工前用老板账号在官方后台再验一次;§11 列出全部来源。本文不构成法律意见。

## 1. 目标与非目标

**目标**
- 4–8 个品牌账号(4 条产品线 × FB Page / IG,Phase 2 加 Threads)共用一套内容管线;每帖带唯一来源码 + wa.me,客户进 WhatsApp 后由主线 R22.8 接手成交。
- 系统能回答五个问题:每帖发成没有、被看了多少、点了多少、每条线每周进了几个 lead(及成交)、token 何时到期。
- 老板亲眼看过每条文案再发(前两周强制审批),不靠模型判断合规。

**非目标**
- 不是靠播放量赚钱的矩阵号:不刷量、不买号、不用指纹浏览器、不用任何非官方私有 API;唯一的「预热」是新 IG 号接 API 前由老板本人正常使用两周(§7)。
- 禁用一切第三方 WhatsApp Channels/Status 接口(封号风险直达承载销售机器人的号);FB Groups API 已于 2024-04-22 移除,不做自动发群。
- 不把 token 交给第三方发帖 SaaS;不在 Supabase、执行数据、versions/、TASK.md 里出现任何凭证。
- Phase 3 前不投付费广告;TikTok/小红书/YouTube 在拿到官方公开发布能力前只做半自动(系统出稿,老板手发)。

## 2. 平台矩阵(2026-09)

| 平台 | 状态 | 官方路径 / 上限 | 前置 | 阶段 |
|---|---|---|---|---|
| Facebook Page | 现在可自动(已上线) | Graph API v26.0(2026-07-29 发布)`/{page}/photos`、`/feed`;Reels 走 `/video_reels` start/finish 两阶段(仅 Page,Phase 2);系统用户 token 无时间过期,但安全审查、资产变更、移除系统用户、App 受限会失效;帖文链接可点 | 4 个 Page 在同一 Business Portfolio;App Mode = Live;自家资产 Standard Access 即可,不用 App Review | Phase 0 复用 |
| Instagram | 现在可自动 | Facebook Login 路径,与 FB 共用系统用户 token;`POST /{ig}/media` → 轮询 → `/media_publish`;100 帖/24h(官方页 carousel 段落写 50,一律以 `content_publishing_limit` 实值为准);图**仅 JPEG** ≤8MB、比例 4:5–1.91:1;caption 链接不可点 | IG 转 Business 并绑对应 Page;Page 若被要求 Page Publishing Authorization 则完成前不能 API 发帖(主要针对美国受众大的 Page,马来西亚小 Page 通常不触发,Meta 建议预先完成);新号先由老板手动运营 2 周再接 API | Phase 1 主攻 |
| Threads | 现在可自动(长期 token 60 天,可在 n8n 内自动交换/刷新) | `POST /{uid}/threads` → `threads_publish`;`link_attachment` 可点,但预览只在纯文本贴显示、带图不显示;250 帖/24h(`threads_publishing_limit`);OAuth 换到的是 1 小时短期 token,须再用 app secret 调 `th_exchange_token` 换 60 天长期 token,24 小时后可用 `th_refresh_token` 刷新,过期后不可再刷新 | App 可长期停在开发模式 + Threads Tester(上限 25);凭证用 Header Auth 而非 OAuth2(§3.3) | Phase 2 |
| TikTok | 需申请 | Content Posting API;未过审只能 SELF_ONLY 私密、≤5 用户/24h、账号须私密;过审后 Direct Post 每创作者约 15 帖/日;审核二手来源称 2–4 周或 2–6 周、多轮反馈 | Business 账号、开发者 app、域名验证、演示视频 | Phase 2 提交,期间半自动 |
| 小红书 | 只能半自动 | 无面向海外品牌号的公开发布 API;第三方均为逆向脚本 | 老板手机手发,回贴链接 | Phase 2 内容包 |
| YouTube Shorts | 不建议(暂缓) | 未审计项目上传锁私密,需合规审计;配额已不是瓶颈(2025-12-04 起 videos.insert ≈100 单位,2026-06-01 起上传单独计桶 100 次/天) | 合规审计;OAuth 同意屏发布到 Production | Phase 3 视需求 |
| Telegram 频道 | 不建议(可选) | Bot API 免费可自动,但该客群几乎无自然流量 | 建频道 | 有余力再做 |
| X / LinkedIn / FB Groups / WhatsApp Channels | 不建议 | X 2026-04 起含链接帖 $0.20、普通帖 $0.015;LinkedIn 需 Community Management API 审批;Groups API 已移除;WhatsApp Channels 无官方接口 | — | — |

## 3. 架构

原则:不新增服务器、不新增付费 SaaS;n8n 多几条工作流,Supabase 多几张表,OpenAI 多一次「派生」调用;凭证只活在 n8n Credentials 与 CC-B 本地 .env。

### 3.0 前置:n8n 实例版本与设置(新增)

- **版本要求**:Publish 语义需 2.0+;公共 API `PATCH /credentials/{id}`(scope credential:update,支持 isPartialData)需 2026-01 之后的 2.x(commit 750e9a8 / #23431);凭证泄漏 advisory GHSA-q3j5-8vrg-4p9q 修复于 2.27.4 / 2.28.1。CC-B 开工先在 UI(Settings 页底部)或 `GET /rest/settings` 看版本,**低于 2.28.1 先请老板升级**(DO 上升级会短暂停主线,选非发帖时段)。老板实例的确切版本:待核实。
- **社区版没有执行数据脱敏**(仅 Enterprise),所以发布类、探针类、Threads Auth 工作流一律「成功与失败执行都不保存」;曾有「Do not save 设置被忽略」bug(#12118),验收时实际打开一次执行列表确认没有 token。
- 全局 `EXECUTIONS_DATA_PRUNE=true`、`EXECUTIONS_DATA_MAX_AGE=72`(默认 336h):要改 DO 上的 env 并重启 n8n,会短暂停主线,列入「先问老板」,由老板选时间。
- 2.0 起 `N8N_BLOCK_ENV_ACCESS_IN_NODE` 默认 true,Code 节点读不到环境变量,盐、密钥都不能往那放。

### 3.1 Supabase(schema `social`)

- **访问方式**:n8n 的 SE-* 一律用 **Postgres 节点直连**,不用 Supabase 节点(PostgREST 访问自定义 schema 要先在 Dashboard → Settings → API 加 Exposed schemas 并 GRANT,否则报 PGRST106;直连不需要)。`001_social_schema.sql` 建专用登录角色 `social_engine`:`social` schema 全权;主线相关表**仅 SELECT**(只授 SE-07 需要的几张);不能直读 Vault,只能经 `SECURITY DEFINER` 的 `social.wa_hash()`。n8n 凭证 `pg-social-engine` 只用这个角色,密码由老板在 SQL Editor 设好直接贴进 n8n。service key 只留给 CC-B 本地一次性建表,绝不进任何 n8n 工作流——「只读主线表」由此从纪律变成权限。
- `brand_accounts`:`line_code`(DNG/GSD/FLX/RUM)、`platform`(fb/ig/th/tt/xhs)、`platform_account_id`、`credential_ref`(n8n 凭证**名**,不是 token)、`bio_link_url`、`wa_number`、`posting_days`、`posting_time_myt`、`posting_mode`(auto/semi)、`require_approval`、`is_active`、`paused_reason`、`paused_at`、`mal_no`、`kkliu_no`、`halal_cert_ref`(三者可空)、`testimonial_form_on_file`。**种子数据**(Phase 0a):4 条 FB 行,对应现有 4 个 Page 与 v3.9.19 用的凭证名(CC-B 只读 GET 从 v3.9.19 JSON 抄 name,不抄值)。
- `platform_credentials`(只存元数据,**绝不存密文**):`credential_ref`、`platform`、`token_type`(page_never_expire/system_user/threads_60d)、`issued_at`、`expires_at`(发放时手工登记,null=无时间过期)、`last_probe_at`、`last_probe_ok`、`consecutive_failures`、`last_error_code`、`last_error`(仅 code/message)。种子:现有 4 个 Page token 各一行 `expires_at=null`——这就是 Phase 0 SE-06 探的对象;另加一行 `probe-test` 指向故意错误的 Header Auth 凭证,用于验收 190 分支。
- `post_schedule`:`master_id`、`brand_account_id`、`platform`、`scheduled_at`、`variant_lang`、`caption`、`media_urls[]`、`media_kind`(image/reel)、`source_code`(唯一)、`wa_link`、`gate_status`、`gate_report` jsonb、`approval`(auto/pending/approved/rejected)、`status`(draft/ready/publishing/published/failed/skipped/manual_pending)、`attempts`、`next_retry_at`、`updated_at`。
- `post_log`:`schedule_id`、`platform_post_id`(唯一约束)、`permalink`、`published_at`、`ok`、`error_code`、`error_message`(仅 Meta 返回的 error.code/message,不存请求 URL)、`n8n_execution_id`、`is_manual`。
- `metrics_daily`:`(post_log_id, snapshot_date)` 主键,核心字段 `views/viewers/reactions/comments/shares/saves/redirect_clicks`,`raw` jsonb 全存。`impressions/page_fans` 已于 2025-11-15、`reach`/`video_views`(非 Reels)/`profile_views`/`website_clicks` 已于 2026-06-15 被 Meta 弃用,替代为 views / post_media_view / Page Viewer 系列;`reach` 标 deprecated 只留 `raw`;平台自报点击(`post_clicks` 是否已移除:待核实)只作参考。
- `metric_map`:`platform, metric_key, api_metric, api_version, valid_from, valid_to, enabled` — Meta 下线指标只改表不改流。**初始版本不由本文硬编码**:Phase 1 第一项任务是老板账号在 Graph API Explorer 对 4 个 Page + 4 个 IG 逐个跑一次可用指标,把实际返回写进表作为 v1,SE-05 只读表。
- `link_clicks`(Phase 1 起):`source_code, platform, clicked_at, ua_hash, ip_hash`。
- `lead_attribution`:`wa_hash`(库内计算)、`source_code`、`line_code`、`platform`、`schedule_id`、`match_method`(exact_key/line_only/none)、`first_msg_at`、`matched_code`、`lang_tag`(zh/ms/mix)、`stage`(new/qualified/won/lost)、`order_value`。**不长期保留客户首句明文**(常含「我糖尿病…」等健康状况,属 PDPA 敏感个人资料):只留匹配到的来源码与语言标记;排查需要临时存的 `first_msg_excerpt` 由 SE-08 每日清空 30 天前的值;`v_funnel_weekly` 不依赖摘录。
- `gate_rules`:`rule_type`(forbid/require/length)、`lang`、`pattern`、`severity`(block/warn)、`applies_to`(all/平台/线)、`enabled` — 老板在表里加词即时生效,不改工作流。
- `alerts_log`:`severity, kind, dedupe_key, message, sent_at`。
- `ad_spend`(Phase 3,老板手填)。
- 视图 `v_funnel_weekly`:按 `line_code × platform × ISO 周` 出 posts/views/clicks/leads/qualified/won/revenue/spend、`cpl_all_in`、`cpl_paid`;`qualified` = 客户回复 ≥2 条且非黑名单。
- **手机号哈希盐**放 Supabase Vault,pg 函数 `social.wa_hash(phone)` 在库内 `digest(phone || salt, 'sha256')`。Vault 根密钥由 Supabase 托管:同项目恢复/PITR 可解密,但自行 pg_dump 导出或换项目手工恢复解不开;盐丢了 `wa_hash` 不可复现、lead 去重全失效——**盐生成后老板另存一份到密码管理器(离线),文档写明「不是备份的一部分」**。另请老板在 Dashboard → Database → Backups 确认每日备份为整库(含 `social`):待确认。

### 3.2 n8n 工作流(前缀 SE,全部 Settings → Error Workflow = Monitor v2,时区固定 Asia/Kuala_Lumpur)

| 工作流 | 触发(MYT) | 做什么 | 失败处理 |
|---|---|---|---|
| **SE-00 Social Bot Router**(新增) | Telegram Trigger(social bot,**全系统唯一**) | 一个 bot 只能注册一个 webhook,n8n 里同一 bot 只有最后发布的 Trigger 工作流收得到消息,所以 social bot 全部入站集中在这里:按 `callback_data` 前缀分发 `ap:`→SE-01b(发/不发)、`won:`→SE-07(成交)、`man:`→SE-09(已发/跳过)、`rs:`→SE-06(恢复账号);图片/视频 + 线码 → 素材入库;其余文本回「未识别」。用 Execute Workflow 调子流,子流不带 Trigger | Router 挂了按钮全失效,是 SE-08 心跳的第一项 |
| SE-01 Planner | 发帖日前一晚 21:00(日/二/四) | 读次日要发的账号 → 复用 v3.9.19 中文主文案 → 一次 OpenAI 派生各平台版本 → Gate v2 → 写 `post_schedule`;发前查 IG `content_publishing_limit`,余量 <5 改期不硬发 | Gate fail 只记录 + 摘要,不阻塞其他账号;OpenAI 失败重试 2 次 |
| SE-01b Approval | SE-01 末尾 | `require_approval=true` 的账号:文案 + 缩略图由 **social bot** 发出,老板点「发 / 不发」按钮(回调经 SE-00);次日 17:45 未回复即 `skipped`(≥20 小时窗口) | 老板不在不会误发;两周后可逐账号关掉 |
| SE-02 Publish-FB | 一三五 18:00 | 原子抢占 `UPDATE … SET status='publishing' WHERE status='ready' AND scheduled_at<=now() RETURNING *`(两次执行不会取到同一行)→ HTTP Request(Header Auth,§3.3)→ 写 `post_log` → `published` | 临时错误(Meta code 1/2、网络)与限流(4/17/613)退避 5/15/45 分钟重试 3 次;权限类 190/200/10 与滥用判定 368 不重试直接告警 |
| SE-03 Publish-IG | 一三五 18:05 | 同上;`/media` → 每 15 秒轮询 `status_code=FINISHED`(≤5 分钟)→ `/media_publish`;Phase 1 只发图片;Reels(IG `media_type=REELS`、FB `/video_reels`)放 Phase 2,视频规格待核实 | 容器 ERROR 判失败并入库 |
| SE-04 Publish-Threads(Phase 2) | 18:10 | `/threads`(text + link_attachment 或 image_url)→ 30 秒后 `threads_publish`;发前查 `threads_publishing_limit`;要链接预览就发纯文本贴 | 同上 |
| **SE-00T Threads Auth**(Phase 2,新增) | Webhook(OAuth 回调)+ 被 SE-06 调用 | 收 OAuth `code` → 换 1 小时短期 token → 用 app secret 调 `th_exchange_token` 换 60 天长期 token → 经 n8n 公共 API `PATCH /credentials/{id}`(isPartialData)写回 Header Auth 凭证 `threads-<line>`,并更新 `platform_credentials.expires_at`;第 50 天由 SE-06 调 `refresh_access_token?grant_type=th_refresh_token` 再 PATCH。全程在 n8n 内完成,人不看 token;本流「成功失败都不保存执行」 | 前提:老板批准 n8n 持有自己的 API key(§3.3);不批准则由老板点授权链接触发本流,PATCH 一步改为提示老板手动贴 |
| SE-05 Metrics | 每日 08:00 | D+1/3/7 拉 Insights(指标名读 `metric_map`)→ upsert `metrics_daily` | 单帖失败不阻断;`invalid metric` 单独告警并把该 `metric_map` 行 `enabled=false` |
| SE-06 Token Sentinel | 每日 07:00(失败 30 分钟后重探) | 用**预置凭证**发 `GET /me?fields=id`(FB/IG)、Threads `/me` 做活性探针;按 `expires_at` 阶梯告警 14 天 info / 7 天 warn / 3 天 critical。**错误码分级与防抖**:190/200/10(凭证/权限)计一次失败,重探仍失败(**连续 2 次**)才 `is_active=false` + P1;1/2/4/17/613(临时/限流)只 P2 告警、重探、不停号。停号消息附「恢复」按钮(经 SE-00 置回 `is_active=true`);下一次探针成功也自动恢复并告警「已恢复」。Threads 第 50 天触发 SE-00T 刷新 | 不用 `debug_token`(会把 token 写进 query 进执行数据) |
| SE-07 Lead Sync + Clicks | 每 10 分钟 | 轮询主线已落库的客户表(或 AFTER INSERT 触发器)解析来源码 → `lead_attribution`;接收 go 跳转的点击回调(校验共享密钥 header)→ `link_clicks`;处理「成交」回调 | 抓不到码写 `match_method=none`,永不影响主线回复 |
| SE-08 Report + Reconcile | 每日 08:30;发帖日 18:30 | 08:30 日报由 **social bot** 发(带「成交」按钮);18:30 对账「应发 vs 已发」,卡在 `publishing` >30 分钟改 `failed` 并告警(人工确认平台是否已发再决定重发);日报固定一行「**SE-* 已发布 N/M**」(只读 GET 看 `active` 与 `activeVersion`),作为「漏 Publish」兜底;顺手清 30 天前的 `first_msg_excerpt` | 报表失败本身也告警 |
| SE-09 SemiAuto Pack(Phase 2) | SE-01 末尾 | TikTok/小红书内容包(脚本 + 标题 + 3 条 caption + 来源码)由 social bot 发,带「已发 / 跳过」按钮,老板回贴帖子链接 → `post_log(is_manual=true)` | 48h 未回复提醒一次后 `skipped` |

**Telegram bot 分流(修订)**:现有 Monitor v2 bot 的唯一 webhook 已被主线占用,只能**发纯文本**、收不到按钮回调;因此带按钮的消息(审批、日报、内容包、停号/恢复)一律由 social bot 发送并经 SE-00 Router 回收,Monitor v2 bot 只发 Error Workflow 告警与心跳,现有工作流一个节点都不动。social bot 的 `chat_id` 由老板首次发「hi」后,CC-B 用 `getUpdates` 读取并写进本地 .env,不写进 SPEC。

### 3.3 凭证与执行数据

- **Meta 凭证一律「Header Auth」**:n8n 自带「Facebook Graph API」凭证把 token 注入 query string(源码 `authenticate.properties.qs.access_token`),URL 会出现在错误输出与代理/反代日志——**禁用**。改为 HTTP Request + Header Auth 凭证:Name `Authorization`、Value `Bearer <token>`;Graph API 与 Threads 都接受。凭证名 `meta-sysuser-wabot`(系统用户)、`threads-<line>`(4 个)。
- Meta:Business Settings 建**系统用户**(Admin),分配 4 Page + 4 IG,用现有 App 生成 token,勾 `pages_manage_posts, pages_read_engagement, pages_show_list, read_insights, instagram_basic, instagram_content_publish, instagram_manage_insights, business_management`,不勾 60 天过期。一份凭证管 8 个资产;失效条件:老板改密码、被移出 Page、撤销授权、安全审查、App 受限。App 须处于 **Live 模式**(开发模式下发的内容只对有 App 角色的人可见;现有引擎已发真实帖,大概率已是,仍要在 developers.facebook.com 顶部确认);只发自家资产,**Standard Access 够用,不用提交 App Review**。现有 4 个 Page token「永不过期」同样有条件(底层用户改密码、被移出 Page、撤销授权即失效),所以 Phase 0 就要探。
- 错误分支只提取 `error.code / error.message / fbtrace_id` 再落库或告警,禁止把整个响应或请求 URL 写进 `post_log`。
- HTTP Request 一律用 predefined credential;禁止在 Set/Code 节点拼 token、禁止 `access_token` 走 query;`post_log` 只存去敏后的错误信息。
- **Threads(Phase 2)不用 n8n OAuth2 凭证**:OAuth2 凭证换到的是 1 小时短期 token,响应无 refresh_token,n8n 不会做 `th_exchange_token` 二次交换,照 v1.0 做会每小时失效而不是 60 天。改为 Header Auth 凭证存长期 token + SE-00T 自动交换/刷新/写回(§3.2)。App Dashboard 的 User Token Generator 也只出短期 token,不能当捷径。
- **n8n API key 归属(老板拍板)**:非企业版 API key 全权限、无作用域、无法限制只读,「REST 只准 GET」是纪律不是控制。两把钥匙分开:(1)CC-B 的 key 只放本地 `.env`(已 gitignore),不写进任何 n8n 工作流、Supabase、文档;所有 REST 调用集中在 `tools/n8n-get.mjs` 一个只实现 GET 的封装,禁止在别处直接 curl;DEPLOY-LOG 记每次 REST 调用类型;老板随时可在 n8n Settings → n8n API 一键撤销。(2)SE-00T 要自动写回凭证就需要 n8n 持有**第二把** key(Header Auth 凭证 `n8n-self-api`,仅 SE-00T 用)——与铁律冲突,**由老板决定是否允许**;不允许则每约 50 天老板点一次授权链接,SE-00T 只做交换并提示老板手动贴。
- 发布类、探针类、SE-00T「成功与失败执行都不保存」;验收时实际打开一次执行记录确认没有 token(§3.0)。

### 3.4 版本、部署、回滚

- 版本文件 `versions/SE-0x_vN.json`;凭证只保留 `{name,id}` 引用。写入 versions/ 前脚本扫描 `EAA`、`ya29.`、`bot\d+:`、`sk-`、`eyJ`、`THAA`(Threads token 前缀)、`n8n_api_` 等 token 形态,命中即拒绝写入。
- **核对已发布快照而非草稿**:n8n 2.x `GET /workflows/{id}` 顶层 `nodes/connections` 是最新草稿,已发布快照在只读字段 `activeVersion`(含 versionId/nodes/connections,可为 null),`active` 只读;v1.0 对草稿做哈希,漏点 Publish 也会通过——已改。`tools/verify-deploy.mjs` 按序检查:(1)`active==true` 且 `activeVersion` 非 null;(2)对 `activeVersion.nodes/connections` 去掉 `id/updatedAt/versionId/position` 等服务端字段、按键排序后 sha256,与 versions/ 文件同样归一化后逐字节一致;(3)顶层草稿归一化后 == activeVersion(证明发布的就是最新导入,没有导入后又被改);(4)`docs/DEPLOY-LOG.md` 以 **workflow id 为主键**记日期、版本、哈希、`activeVersion.versionId`、谁点的 Publish、本次用了哪些 REST 调用。任一步不过 = 未部署成功。
- **UI 导入行为待实测**:官方文档称 UI 导入总是新建工作流(新 ID),只有 CLI 会覆盖同 ID;另有「导入后已更新的工作流会变为未发布」的说法。新 ID 意味着 Error Workflow 设置、凭证引用、DEPLOY-LOG 的 ID、SE-08 心跳依据的 id 全部漂移,旧流仍在跑会**双发**;导入即取消发布则老板不及时 Publish 就有空档。**Phase 0a 先用 dummy 工作流实测两条路径**(工作流列表「Import from File」 vs 画布内 ⋯ → Import from File)对 ID/发布状态的影响,结论写进 `docs/DEPLOY-SOP.md`;若会新建 ID,SOP 改为「画布内导入覆盖」,做不到则「新建后立即归档旧流并在 DEPLOY-LOG 记 ID 变更」;同名两条流同时 active 由 verify-deploy 直接判失败。
- 部署 = CC-B 按 SOP 在 UI 导入 → 手动 Test 自测 → 老板确认 Error Workflow = Monitor v2 → 老板点 Publish → CC-B 跑 verify-deploy → 写 DEPLOY-LOG。
- **回滚**优先用 n8n 自带 Workflow history → Restore version → Publish(社区版保留 24 小时);超过 24 小时用 versions/ 文件按 SOP 导入再 Publish。任何时候不用 REST 写工作流、不改 Active/Publish;不用 `PUT /workflows`。
- Error Trigger 只对自动触发的执行生效,手动 Test 不进 Monitor v2,验收必须让 cron 真跑一次并人为制造失败(统一放 Phase 0b,与 kickoff 一致)。

## 4. 内容管线

1. **主文案**:沿用 v3.9.19(中文,Gate 四条:长度/关键词/HALAL/首句点名产品)。
2. **派生**:一次 OpenAI 调用,`response_format` 强制 JSON `{fb, ig, threads, tiktok_script, xhs, hashtags, image_prompt}`;缺字段整批重跑一次,仍失败只保留 FB 版本。FB 400–800 字,帖尾 wa.me(整段 `encodeURIComponent`,`#` 必须变 `%23`)+ 来源码;IG ≤2200 字、首句点名产品、不放 URL、写「WhatsApp 我们发 #IG_DNG,链接在主页」、hashtag ≤5;Threads ≤500 字 + `link_attachment`(要预览就不带图);TikTok/小红书出 60–90 秒口播脚本与 3 条 caption。语言 Phase 1 只中文,Phase 2 隔周加 BM/Manglish 变体(同一 master,`variant_lang` 不同)。
3. **Gate v2**(纯规则、确定性,不用模型二审;规则读 `gate_rules`):长度;首 12 字含产品名;来源码与 wa 链接一致;三语禁词(治疗/治愈/根治/预防/降血糖/降血压/cure/treat/heal/ubat/sembuh/merawat 等)与 Act 290 附表 20 种疾病名(肾病、心脏病、糖尿病、癫痫、瘫痪、肺结核、哮喘、麻风、癌症、耳聋、药物成瘾、疝气、**眼疾**、高血压、精神病、不孕、性冷淡、**性功能障碍/阳痿**、性病、神经衰弱)**对所有 SKU 一律 block,与有没有 MAL 无关**——Act 290 第 3 条对任何「物品」生效,食品类 SKU 同受 Food Regulations 1985 reg.18 约束,一样禁止预防/治疗/治愈宣称(v1.0「食品类无 MAL 不拦」已删);MAL/KKLIU 只决定「能否提功效」不决定「能否提疾病」:`mal_no` 与 `kkliu_no` 都非空才放行功效句并带 KKLIU 字样,否则功效词一律 block;`mal_no` 非空的 SKU 必须带 MAL 号;名人/专业人士背书一律拦;客户见证仅当 `testimonial_form_on_file=true` 放行;不出现「前后对比」「100%」「无副作用」「医生推荐」;HALAL 仅在 `halal_cert_ref` 非空时可提且只写「已获认证」;AI 图 caption 加「图片由 AI 生成」;近 30 帖 simhash 去重;IG 图校验 JPEG/比例/大小。任一 block → 该版本 `skipped`,其他平台照发;`gate_report` 逐条记录便于老板改稿。
4. **素材**:公司官方审批素材(先确认分销商可用)> 老板手机竖版实拍 > AI 场景图(gpt-image-1-mini,非写实插画风,不生成产品包装、不生成真人、不做「服用后效果」;**生成时指定 `output_format: jpeg`**,默认 PNG 会被 IG 整批拦下)。入库前用 n8n Edit Image 节点统一转 JPEG、按 4:5 裁切、压到 ≤8MB。统一进 Supabase Storage 公共桶 `assets/{line}/{yyyymm}/`(IG 需公网 HTTPS URL);老板发图到 social bot 并写线码即经 SE-00 入库。

## 5. 获客归因

- **来源码** `#<PLAT>_<LINE>_<MMDDx>`,如 `#IG_DNG_0911A`;bio 链接用账号级 `#IG_DNG_BIO`;向后兼容 `#FB_DNG`(归到线)。正则 `#(FB|IG|TH|TT|XHS)_(DNG|GSD|FLX|RUM)(?:[_ ]([0-9]{4}[A-Z]|BIO))?`,大小写不敏感,取首句前 200 字第一个匹配,同时接受 `_` 与空格分隔。
- **主线兼容性是前置(任务 0)**:本地没有 wabot 文件,无法核对 R22.8 的来源码正则;若主线按 `#FB_DNG` 精确/词边界匹配,`#FB_DNG_0911A` 会让现有归因失效,Phase 0 验收(依赖主线落库的首句)也过不了。CC-B 先用只读 GET 拉 R22.8 JSON,找出解析节点,写明它对 `#FB_DNG_0911A` 的行为:兼容 → 用下划线格式;不兼容 → 由 CC-A 改主线正则(需老板批准)或新码改用主线能容忍的两段式 `#FB_DNG 0911A`。验收前在主线用一条测试消息验证,结论待核实。
- **链接**:FB 帖与 Threads 直接 `wa.me/60…?text=` + 预填「Hi Johnny 我想了解 Dnitez #FB_DNG_0911A」,不经跳转(最短路径,n8n 重启不影响)。IG/TikTok bio 用 `go.daelifeai.com/<code>`:若 daelifeai.com 的 DNS 在 Cloudflare,用免费 Worker 做 302(静态映射线 → 号码与产品名,`waitUntil` 异步回调 SE-07 记点击,**回调带共享密钥 header `X-Go-Secret`**,值存 Worker Secret 与 n8n 凭证各一份,不匹配即丢弃;n8n 挂了客户照样跳转,简介里也不暴露 n8n 域名);DNS 不在 Cloudflare 时优先只把 `go` 子域 CNAME 到 Cloudflare(不迁主域),做不到才退回 n8n webhook「Redirect」响应(未知 code 也 302 到默认 wa.me,接受 n8n 重启期间短暂丢点击)。
- **写回**:不改 R22.8。SE-07 轮询(或触发器)主线客户表首条消息 → `lead_attribution`,`wa_hash` 由库内函数算;`match_method` 三档;日报单列「无码进线 %」,长期 >30% 说明预填文字被客户删了,回头改文案不改系统;无码进线与同平台 24 小时内点击做时间邻近参考匹配,不计入精确归因。CC-A 需先确认主线来源码所在表/列,以及主线会不会把老板测试号当黑名单/内部号。
- **成交**:日报里每个新 lead 带「成交」按钮(social bot → SE-00 → SE-07)→ 输入金额 → `stage=won, order_value`;若主线已有成交状态则直接同步,不让老板重复操作。
- **口径**:`leads` = 去重 `wa_hash`;`CTR = clicks/views`;`lead_rate = leads/clicks`;`CPL_paid = ad_spend/leads`(仅 AD_ 来源);无广告时报 `CPL_all_in =(OpenAI + 图片)/ leads`。

## 6. 监控与告警

- **P1 即时**:同一帖失败 3 次;凭证探针**连续 2 次**权限类失败(自动停号,附「恢复」按钮);18:30 对账缺帖;当日 go 点击 >30 但 1 小时 0 进线(社媒活着但主线可能挂了);SE-00 Router 或 SE-02 在应执行时段无执行记录。
- **P2 汇总**:Gate 拦截;`invalid metric`;token 剩 ≤14 天;某线连续 7 天 0 lead;IG 配额 >80%;素材库剩 <3 张;临时/限流类探针失败;SE-* 有未发布项。
- **去重**:`alerts_log.dedupe_key = kind + account + 日期`,1 小时内只发一次,连续失败不刷屏。
- **心跳**:Monitor v2 30 分钟不变(纯文本 bot);SE-02 发帖日 2 小时无执行记录 → 告警「疑似未 Publish 或 cron 未跑」;日报「SE-* 已发布 N/M」为第二道兜底。
- **日报(08:30,social bot 一条消息,底部带按钮)**:
  ```
  📅 09-10 wabot 社媒日报
  发帖 昨日 8/8 成功(FB4 IG4) 失败 0 | 待审批 4 | 待手发 2
  D+1 views DNG 1.2k · GSD 860 · FLX 640 · RUM 410
  点击 go 37 | 新 lead 昨日 5(FB_DNG 3·IG_GSD 1·线级 1) 无码 12% 本周 14 成交 2
  Token 全部正常 | IG 配额 4/100 | SE-* 已发布 9/9 | 半自动回填率 80%
  待办:RUM 素材剩 2 张,请补图
  [成交 #1] [成交 #2] …
  ```

## 7. 分阶段落地

今天 2026-09-09(周三)。v1.0 的「Phase 0 本周」不现实(老板要 Publish ≥4 个工作流、日报连发 3 天、新帖还得先发出去),改为 **7–10 个工作日**分两段;本 SPEC 与 kickoff 的验收清单统一为下表。

| 阶段 | 交付 | 验收 |
|---|---|---|
| **Phase 0a**(09-10 → 09-16,5 个工作日) | 老板交 .env 与 social bot;n8n 版本核对(≥2.28.1);**任务 0** R22.8 来源码解析兼容性结论;`tools/n8n-get.mjs` + `tools/verify-deploy.mjs` + token 扫描 + `docs/DEPLOY-LOG.md`;dummy 工作流导入实测 → `docs/DEPLOY-SOP.md`(先于任何真实导入);`001_social_schema.sql`(schema + 角色 `social_engine` + 视图 + Vault 盐/哈希函数 + 种子数据);SE-00 Router 最小版(先只接「恢复」与收图);SE-07 lead 写回;v3.9.19 → v3.10 版本文件(帖尾唯一码,节点 diff 先给老板过目再导入) | ① 任一条经 wa.me 预填首句进线(允许老板测试号,CC-A 先确认主线不把该号当黑名单)→ `lead_attribution` 出现 `match_method=exact_key`;② 主线对新码的解析已用测试消息验证;③ v3.10 与 SE-07 在 versions/ 有文件、verify-deploy 对 `activeVersion` 通过、DEPLOY-LOG 有哈希与 versionId;④ DEPLOY-SOP 写明导入路径对 ID/发布状态的实测结论 |
| **Phase 0b**(→ 09-23,5 个工作日) | SE-06(探针 + 阶梯 + 错误码分级/防抖/恢复);SE-08 日报最小版(social bot 发,含「SE-* 已发布 N/M」);cron 真跑制造失败;执行记录无 token 检查 | ⑤ 日报连发 3 天;⑥ 把一条 `expires_at` 改到 5 天内,次日 07:00 前收到 warn;⑦ `probe-test` 假凭证连续 2 次失败 → `is_active=false` + P1 + 「恢复」按钮,按下即恢复;⑧ Monitor v2 收到一次由 cron 真跑触发的人造失败(手动 Test 不算);⑨ 打开一次 SE-06 执行记录确认没有 token(或确认未保存) |
| Phase 1(2 周) | 前置硬阻塞:**公司书面许可**到手(Act 500);4 个新 IG 已由老板手动运营各 2 周;IG 转 Business/绑 Page/系统用户 token(Header Auth)/App Mode=Live;第一项任务 = Graph API Explorer 跑出 `metric_map` v1;SE-01/01b/02/03/05 上线,v3.9.19 逻辑迁入(旧引擎保留可回滚);**灰度:先 DNG 一条线 FB+IG 跑一周,再扩 4 条**;素材桶 + bot 收图;go 跳转(IG bio);`gate_rules` 三语初始化 | 连续 3 个排程日 FB+IG 8 帖自动发成、指标入库、日报无人工干预;Gate 拦下 ≥1 条含禁词测试稿;人为改坏 token 后次日 07:30 前 P1 且该账号自动停、恢复按钮可用;旧引擎一键 Publish 可回滚;执行记录里无 token |
| Phase 2(1 个月) | 老板拍板 n8n 是否持有自己的 API key → SE-00T Threads Auth;Threads 4 号 + SE-04;BM/Manglish 变体;SE-09 半自动内容包(TikTok/小红书);TikTok Business 账号 + 开发者 app + 提交审核(过渡期 MEDIA_UPLOAD 推到收件箱或手发);Reels(FB `/video_reels`、IG REELS)规格核实后接入;`v_funnel_weekly` 周报 | Threads 帖 wa.me 可点且归因;长期 token 第 50 天自动刷新一次成功(或老板点一次链接即完成);半自动回填率 ≥80%;周报每线 leads/CPL 可直出;TikTok 审核已提交 |
| Phase 3 | TikTok 过审后 DIRECT_POST;Click-to-WhatsApp 广告小额测试(流量/互动目标,备齐 KKLIU);`ctwa_clid` 落库;语料库痛点自动喂 prompt;YouTube 视需求 | 单线 CPL_paid 可算;广告素材全部过 Gate |

## 8. 风险与合规(非法律意见)

- **Act 290**(Medicines (Advertisement and Sale) Act 1956):附表 20 种疾病禁止宣称预防/治疗/诊断(全表见 §4),眼护线避「眼疾/白内障/青光眼」,鹿肽素线避「壮阳/性功能」;第 3 条对任何「物品」生效,食品类 SKU 不例外。MAL 注册产品的功效广告须 MAB 批准并展示 KKLIU 号(含社媒):官方申请费 RM100/份(代办报价 RM50–500 视媒体类型),审批 5 个工作日仅限非网站广告、网站/社媒类 30 天,批文有效 3 年;未获批前只讲生活场景、成分、认证(MAL/HALAL)。先在 KKM「Semakan Produk Berdaftar」核每个 SKU 状态。
- **Act 500 直销**:分销商任何广告材料须公司事先批准是行业合同常规,多数公司禁止自制功效文案——公司书面许可是 **Phase 1 的硬阻塞**,不是「资料」;同时拿分销商广告守则、官方素材授权,确认公司 KPDN AJL 执照。
- **Meta 健康政策**:禁前后对比、禁负面自我认知暗示;2025-01 起健康类数据源禁下漏斗事件优化(我们靠来源码归因不靠 Pixel);TikTok 补充剂广告 18+ 确认,预审为 Ads Manager 通用要求,马来西亚资格需与 TikTok 销售代表确认。
- **PDPA 2024 修正(2025 年 1/4/6 月分三阶段生效)/ CPETTR 2024(2024-12-25 生效)**:只存手机号哈希、不留首句明文;主线首条回复加数据用途说明;CPETTR 除经营者信息披露外还要求线上销售信息有**马来文版本**,CC-B 提供的简介/PDPA 文本同时给 BM 版(非法律意见,建议与公司合规确认)。
- **AI 标识**:Meta 写实 AI 视频/音频须自我披露,图片会被自动打「AI info」;马来西亚 OSA 2025 已于 2026-01-01 生效。策略:AI 只做非写实场景图并声明,视频用实拍。
- **封号与连坐**:全部账号挂在老板真实身份的一个 Business Portfolio、同一系统用户 token 下,一个账号被限制可能连带商业账户受限——所以新 IG 先手动运营 2 周、Phase 1 先灰度 1 条线、Business Verification 尽早完成;IG 同设备 ≤5 号(TikTok 登录上限已放宽至 6,推荐 3);每账号每日 ≤2 帖、simhash 去重;不用 VPN 切区。
- **指标漂移**:Meta 2025-11-15 与 2026-06-15 两批弃用(详见 §3.1),`post_clicks` 是否已移除待核实——点击真值用自建 go 跳转,平台自报只作参考;`metric_map` + `raw` 全存。
- **单点凭证**:一个系统用户 token 管全部,老板改密码/被踢出 Page 即全停;SE-06 每日探针(防抖后)+ 日报兜底 + 旧引擎可回滚。
- **审批窗口**:老板漏看审批则整批 `skipped` 不发,宁可空档不误发;日报会列「待审批 N 条」提醒。
- **漏 Publish**:verify-deploy 核 `activeVersion`、日报「已发布 N/M」、SE-02 无执行心跳三道兜底。
- **一手文档未直连**:标「待核实」项(见 §11)施工前用老板账号在官方后台再验一次。

## 9. 老板要亲自做的事(照着点;逐步细节见 boss_actions)

1. **交钥匙**:n8n Settings → n8n API → Create API key(全权限,随时可在同一页撤销);Supabase Settings → API 复制 service_role key;两者与 social bot chat id 写进 `social-engine/.env`(CC-B 给模板),不发聊天。
2. **合并资产 + 企业验证 + App Mode**:business.facebook.com 确认 4 个 Page 在同一 Portfolio,上传 SSM 做验证;developers.facebook.com 该 App 顶部确认 App Mode = Live。
3. **IG 预热**:4 个新 IG 从今天起由你本人手动运营 2 周(完善简介、绑手机、手发 3–5 帖、正常互动),再转 Business 绑 Page;Page 若提示 Page Publishing Authorization 先完成身份确认。
4. **生成系统用户 token**:Business 设置 → 系统用户 → 添加 `n8n-social`(Admin)→ 分配 4 Page + 4 IG → 生成 token(勾 §3.3 权限,不勾 60 天过期)→ n8n Credentials 新建「**Header Auth**」`meta-sysuser-wabot`:Name `Authorization`,Value `Bearer ` + token;不用「Facebook Graph API」类型。
5. **建 social bot**:@BotFather `/newbot` → token 贴进 n8n Credentials「Telegram」`tg-social-bot` → 给 bot 发「hi」。
6. **产品与公司资料**:MAL 号、HALAL 证书号、KKLIU 批文(若有)、**公司书面许可**(Phase 1 硬阻塞)、分销商广告守则、KPDN AJL 执照号。
7. **Vault 盐离线备份**:CC-B 生成盐后抄进你的密码管理器;它不在 Supabase 备份里。
8. **Bio 链接 + DNS**:IG 简介网站栏填 `go.daelifeai.com/IG_xxx_BIO`;告诉 CC-B 域名 DNS 在哪里管理。
9. **拍素材**:每条线每月 10 张 4:5 竖版实拍 + 5 段 15–30 秒竖版视频,发给 social bot 并写线码。
10. **点 Publish**:CC-B 说「已按 SOP 导入、已自测」后 → 该工作流 → Settings 确认 Error Workflow = Monitor v2 → Publish;回滚优先 Workflow history → Restore → Publish(24 小时内),更早的由 CC-B 按 SOP 导入旧版再 Publish;Phase 0a 会请你在 dummy 工作流上多点几次以实测导入行为。
11. **n8n 升级 / 改 env**:版本低于 2.28.1 或要改执行数据保留期时,选非发帖时段让 CC-A 在 DO 上操作(主线停几分钟)。
12. **每天**:发帖日前一晚在 social bot 点「发 / 不发」(次日 17:45 截止);08:30 看日报,成交点「成交」填金额;收到「已停号」按「恢复」或回复 CC-A。
13. **Phase 1 第一件事**:用你的账号开 Graph API Explorer,按 CC-B 清单对 4 Page + 4 IG 各跑一次 insights,截图给 CC-B 填 `metric_map`。
14. **Phase 2 拍板**:是否允许 n8n 持有一把自己的 API key 自动写回 Threads token(不允许 = 每 50 天点一次授权链接);Threads 加 4 个 Tester(上限 25,App 可停在开发模式)并授权;TikTok 切 Business 账号并提交审核。
15. **合规文本**:主线首条回复加 PDPA 数据用途说明、各平台简介补经营者信息,均中文 + BM 两版。

## 10. 成本

| 项目 | 月费 |
|---|---|
| Meta Graph / IG / Threads API、Telegram Bot、Cloudflare Worker 免费层(100k 请求/天、10ms CPU) | RM 0 |
| OpenAI 派生调用(每周 3 天 × 4 线 × 1 次 JSON 派生)+ 日报汇总 | ≈ RM 5–10 |
| AI 场景图 gpt-image-1-mini(每月约 30 张,$0.005–0.036/张 ≈ $0.15–1.1) | ≈ RM 1–5 |
| Supabase(现有项目新增 11 张表 + 素材桶,免费层 1GB;素材超 1GB 且不在 Pro 才需 US$25) | RM 0(或 RM 110) |
| n8n / Digital Ocean(现有;升级到 ≥2.28.1 不加钱) | RM 0 新增 |
| **合计新增** | **≈ RM 8–20/月**;一次性可选:KKLIU 官方申请费约 RM 100/份(+ 代办费 RM 50–500 视媒体类型) |

## 11. 核实记录(施工前用老板账号在官方后台再验一次)

- **已核实(来源)**:IG 100 帖/24h、`content_publishing_limit`、JPEG/8MB/4:5–1.91:1 — bundle.social/blog/instagram-api-rate-limits(二手引官方,carousel 段落写 50);PPA — community.make.com/t/…/74991;Threads 60 天、`th_refresh_token`、过期不可刷新 — picklog.cc/blog/threads-api-token-refresh;Threads OAuth 只给 1 小时 token、需 `th_exchange_token` — blog.nevinpjohn.in/posts/threads-api-public-authentication、note.com/youpapalife/n/ne22b0e34ad1a;n8n `PATCH /credentials/{id}` — github.com/n8n-io/n8n commit 750e9a8(#23431);Threads 250 帖/24h、预览仅纯文本贴 — postproxy.dev/blog/how-to-post-to-threads-via-api、threads.com/@anujs3/post/C_1DGIFzqwb;TikTok SELF_ONLY/≤5 用户/≈15 帖/日 — vorplabs.com/agent-tools/tiktok-content-posting-api;TikTok 审核 2–6 周 — bundle.social/blog/tiktok-api-approval;系统用户 token — singhamandeep.com/meta-system-user-access-tokens;Page token 条件性永不过期 — bundle.social/blog/facebook-page-access-token;Graph API v26.0 — unalsoft.com/blog/2026-07-31-meta-graph-api-v26;Groups API 移除 — ayrshare.com;指标弃用两批 — docs.supermetrics.com/docs/facebook-insights-field-changes-november-13-2025-1、windsor.ai …june-15-2026;健康类数据源限制 — jonloomer.com/qvt/health-and-wellness-restrictions;AI 标识 — about.fb.com 2024-02;YouTube 配额变更 — blotato.com/blog/youtube-api-pricing;X 定价 — docs.x.com/x-api/getting-started/pricing;Error Trigger 手动不生效、`N8N_BLOCK_ENV_ACCESS_IN_NODE`、执行数据默认 336h、脱敏仅企业版、API key 无作用域 — docs.n8n.io(errortrigger / task-runners / manage-execution-data / redact-execution-data / n8n-api/authentication)、community.n8n.io/t/17795;#12118 — github.com/n8n-io/n8n/issues/12118;FacebookGraphApi 凭证 `qs.access_token` — n8n 源码 FacebookGraphApi.credentials.ts;`activeVersion` — n8n 源码 public-api …/schemas/activeVersion.yml、workflow.yml;Telegram 一 bot 一 webhook — docs.n8n.io telegramtrigger/common-issues、community.n8n.io/t/94736;Publish 取代 Active — support.n8n.io …workflow-publishing-in-n-8-n-2-0;凭证泄漏 advisory — GHSA-q3j5-8vrg-4p9q;Act 290 附表 — pharmacy.moh.gov.my …act-290_1.pdf;KKLIU RM100/5 工作日或 30 天/3 年 — bioprestige.my、prioocare.com;Food Regulations reg.18 — foodipedia.my;Act 500 — enagic-my.com/compliance;PDPA/CPETTR/OSA — dfdl.com、lexology.com(g=a8ed5c4d…)、roedl.com;IG ≤5 号/TikTok 6 号 — socialscalehub.com、360uniquizer.com;TikTok 18+ — ads.tiktok.com age-targeting-restrictions;gpt-image-1-mini 单价 — eesel.ai;Supabase 定价 — uibakery.io;Worker 免费层 — srvrlss.io;Meta 错误码 — github.com/phwd/fbec;Standard Access 免审 — singhamandeep.com/what-is-meta-advanced-access;FB Reels — ayrshare.com;Supabase 自定义 schema — supabase.com/docs/guides/api/using-custom-schemas;Vault — supabase.com/docs/guides/database/vault、github.com/supabase/vault;wa.me `#`→`%23` — help.businesschat.io。
- **v1.0 已推翻并改正**:OAuth2 凭证直接拿 60 天 Threads token(不成立);n8n 无更新凭证端点(过时);API key 可限只读(不成立);YouTube 隐藏配额 7/天(过时);KKLIU RM300/5 工作日(部分错误);食品类无 MAL 不拦疾病词(不成立);核对草稿哈希算部署成功(漏点 Publish 测不出)。
- **待核实**:`post_clicks` 是否已移除;UI 导入是否新建 ID / 取消发布(dummy 实测);老板实例 n8n 版本;R22.8 对 `#FB_DNG_0911A` 的解析;开发模式内容可见性(2020 年二手来源,确认 App Mode=Live 即可);Reels/视频规格;Supabase 每日备份覆盖范围;「Do not save」在老板版本上是否生效。
