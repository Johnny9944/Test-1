# CC-A 待派任务池(来自老板 Google Drive 三张表,2026-09-11)

老板授权:「另外几个你也可以参考一下看看有什么用得上的还是什么时候要做的都可以写进 CC-A 去做」。以下按价值排序,等 R22.9 稳定 ≥ 3 天、n8n 升级完成后逐条派。

## A. 黑名单同步(block list → 主线)
- 来源:Google Sheet「block list」(1b9Wl4KBpgG96c_DPIFRNKLQG2BholIlO5HoJ9spbbRg,工作表「工作表1」,列 Name / H/P NUMBER / 备注;由 yeoshunwen88 维护并共享给老板)。
- 做法:CC-B 的 Sheets 桥提供 `GET ?action=blocklist`(共享密钥);主线新增每日 07:00 MYT 同步工作流「BL-sync」:拉取 → 规范化号码(去空格/连字符,60 开头,`+60167…` 与 `0167…` 都映射到 `60167…`)→ upsert 到主线黑名单表(与 R22.x 现有黑名单机制合并,不新建第二套)→ 命中黑名单的入站消息:不回复、只在 Telegram 提醒老板一条。
- 验收:把表里一个号码发一条测试消息 → 机器人不回 → Telegram 收到提醒。
- 铁律:黑名单表的删除动作不做,只新增;同步脚本只读表。

## B. 成交自动记账(Supabase → Sales sheet)
- 来源:「Copy of Sales 2025」(1ftZrswrUmS-UoOFohWfHr1CJkIn_RbbUgFQxzHlfCTo),列:Order Date, Name, Phone, Product, whatapps/message, OTS/FUP/REPEAT, PV, Address, Problems, Payment Detail, ADS, Delivery Date, First Follow up, Second Follow up。
- 做法:主线标记成交(现有状态机里的「closed」事件)时,经 Sheets 桥 `POST action=sale` 追加一行:日期、姓名、电话(脱敏规则由老板定:整号还是后 4 位)、产品、来源码(填 ADS 列)、PV(老板在 WhatsApp 里确认的金额)、Problems(机器人记录的主诉,只写生活场景描述,不写病名)。
- 同时把当日 Closed / Enquiry 计数写回 Ratio report(`POST action=closed|enquiry`),Ratio 公式自动算。

## C. 跟进提醒(Sales sheet → Telegram)
- 表里有 First / Second Follow up 日期。每天 09:00 MYT 读取当天到期的跟进,推一条 Telegram 给老板:姓名、产品、上次主诉、建议话术(按 fb-copy-gate 规则,不写疗效)。
- 不自动给客户发消息;要不要让 wabot 自动发,老板单独拍板(涉及主动触达,风险高)。

## D. Ratio report 自动填(与 SE-09 配合)
- SE-09(CC-B)每天写 Advertisment 列;A/B 落地后 Enquiry / Closed / Sales 三列也自动填,老板只看 Ratio。

## 派单顺序建议
1. A(最快见效,防骗子号占用机器人)→ 2. D 的 Enquiry 计数(主线已有线索事件)→ 3. B → 4. C。
每条派单前先让 CC-A 只读核对主线现有黑名单表结构与「closed」事件字段,再写版本文件 R22.10/R22.11,走 harness 回归三个数。
