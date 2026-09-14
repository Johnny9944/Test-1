# 三个新平台(YouTube / TikTok / 小红书)怎么开、谁做什么(2026-09-14)

> 老板:「YouTube 频道、TT、XHS 是否都能帮我开通?我负责 verify OTP。」结论:**开号只能你本人做**(手机 + OTP,每个 2–5 分钟);开好之后频道设置、内容、排程、申请 API 全归系统。三个平台现在都做不到「全自动发布」,原因和时间线如下(规则经 2026-09-14 联网核实,来源见文末)。

## 0. 一句话
- 账号:你今天开(三个平台同一个名字),10 分钟。
- 发布:先半自动(内容我们备好、排程你点一下),YouTube 走 Studio 定时发布;TikTok 先申请审核(几天到数周)、审核前只能私密;小红书没有 API,只能手机手发,而且 2026-02-10 起保健食品在小红书**禁止达人推广**,只能做「生活场景」内容不提产品功效。
- 真正的瓶颈是竖版短视频:现在引擎只出图。先建「官方图 + 字幕」轻视频管线(15–30 秒,9:16),一条视频同时喂 Reels / Shorts / TikTok / 小红书。

## 1. 平台对照
| 平台 | 你开号要做的 | 系统能做的 | 自动发布现状(已核实) | 什么时候能自动 |
|---|---|---|---|---|
| YouTube | 用你的 Google 账号在 youtube.com 建频道(品牌账号,取统一名字) | 频道简介/头图/链接、视频与字幕、Shorts 剪辑、每周排程表 | Data API 上传的视频若项目未过 Google 审核会被**锁成私密**;审核没有官方时限,经验几周到几个月。频道不能用 API 创建 | 半自动:YouTube Studio「定时发布」不受此限,内容备好你上传时选「已排定」即可;审核表同时提交,过了再接 API |
| TikTok | 手机装 App 用手机号注册(18+),转 Business 账号 | 内容、字幕、标签、发布日历;以公司名义(SSM 名称 + 网站 + 企业邮箱)注册开发者并提交审核材料(UX 图、演示视频、用量估计) | 审核前 API 发布一律 **SELF_ONLY 私密**,且 ≤5 个账号/24h;审核通过不追溯之前的私密帖;通过后约 15–25 帖/天(非官方数) | 提交后几天到数周;之前手发 |
| 小红书 | 用马来西亚手机号注册即可 | 内容(生活场景、不提产品功效)、发布日历、评论话术 | **没有**面向海外个人/小商家的发布 API;2026-03 起专项封「AI 托管/群控」账号(已处理 120 万个);2026-02-10 起「蓝帽子」保健食品、OTC、医疗器械在小红书禁止达人推广 | 一直半自动;账号只能真人手发。马来西亚月活约 300 万、华人渗透约四成、女性 16–34 为主(行业估计),值得做但只做「睡眠/生活方式」内容,不带产品功效 |

## 2. 命名与素材
- 三平台同一个名字(建议与现有 FB Page / IG 一致),头像同一张,简介同一段(不写「官方/总代/授权」)。
- 素材只用「SOTS Group Daelife」共享库里的官方图与公司设计部文件夹;认证图、价格图不用于公开内容;文案全部过 Gate-Ad(疗效/病名/折扣/身份词一律拒)。
- 视频:轻视频管线(待建,CC-B 或新开 CC-D):ffmpeg 把 3–5 张官方图做成 15–30 秒 9:16 幻灯(缓慢推拉 + 字幕 + 结尾 CTA「私信回『DNG』」),无配音先上;字幕文本走 Gate-Ad;输出 MP4 ≤60 秒,Reels/Shorts/TikTok/小红书共用。

## 3. 三周时间线(不影响主线)
| 周 | 你 | 系统 |
|---|---|---|
| 本周 | 开三个号;Meta 一枚口令(六项权限);Ezbiz 证书 + Meta 法定名称 → 提交验证 | IG 接引擎(D'Nitez 线)、桥 v2.1、R22.12 上线、广告 PAUSED 建好 |
| 下周 | YouTube Studio 上传第一批 Shorts(选定时) | 轻视频管线;TikTok 开发者申请材料(UX 图、演示视频)提交;YouTube API 审核表提交 |
| 第三周 | 每天 5 分钟点发 TikTok / 小红书 | 三平台发布日历;TikTok/YouTube 审核跟进;过审即接 API |

## 4. Meta 企业验证要点(已核实)
- Business Portfolio 的法定名称必须与 SSM 证书**一字不差**(含标点大小写);名称不符是被拒的头号原因。你的 Portfolio 现在叫「BS LIM BM1」,先到 Business Settings → Business info 改成注册名再提交。
- 文件用 SSM Business Registration Certificate(个体户 Form D);过期文件 100% 被拒。ROBA 注册有效期 1–5 年(你注册时自选),到期前续证无罚款,过期 12 个月内可续但有罚金(约 RM20 + 每月 RM10),超过 12 个月自动注销只能重注册。
- Ezbiz 批准后证书**免费下载只有 90 天**(你的批准日 2025-10-13,已过),之后要在 Ezbiz 付费重新下载(Business Info 约 RM10),或找当时下载过的 PDF。
- 审核一般 3 个工作日到 2 周;卡在 In Review 不要重复提交。
- 只投自己账户的手动 CTWA 广告不强制验证;但 WhatsApp Cloud API 未验证会被锁在最低发送层级(Tier 0,约 250 个联系人/24h),主线要放量必须验证。

## 5. 来源
YouTube:developers.google.com/youtube/v3/docs/videos/insert、…/guides/quota_and_compliance_audits、support.google.com/youtube/answer/1270709(定时发布)、answer/15424877(Shorts 3 分钟)。TikTok:developers.tiktok.com/docs/en/content-sharing-guidelines、…/getting-started-faq、…/verify-your-business。小红书:open.xiaohongshu.com 开发者文档、technode.com 2026-03-11(AI 托管账号治理)、news.qq.com 2026-02-06(禁推令)。Meta:facebook.com/business/help/2058515294227817(可接受文件)、business/help/810450577622394(广告主验证要求)。SSM:ssm.com.my 续证指南 PDF、ezbiz 下载步骤(techbloat.com)。
