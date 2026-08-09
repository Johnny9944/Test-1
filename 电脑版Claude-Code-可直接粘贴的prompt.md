# 电脑版 Claude Code — 可直接粘贴的 Prompt 合集

> 用法:到家里电脑,打开 Claude Code(在你的项目目录里跑 `claude`),
> 然后把下面对应的整段话**复制粘贴进去**让它执行。
> 每个 Prompt 都是自然语言,Claude 会帮你完成对应配置。

---

## Prompt ①:一键检查环境 + 开启远程遥控(先跑这个)

```
帮我把这台电脑配置成可以从 iPad 远程遥控的 Claude Code。请依次:
1. 检查我是否已用 claude.ai 账号登录(不是 API key),没有就提示我运行 claude /login;
2. 检查是否设置了会干扰 Remote Control 的环境变量(ANTHROPIC_BASE_URL、DISABLE_TELEMETRY、
   DO_NOT_TRACK、CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC、DISABLE_GROWTHBOOK),
   如果有就告诉我怎么取消;
3. 告诉我这台电脑的操作系统怎么关闭"自动休眠",避免会话断线;
4. 最后给我一条可以直接运行的命令,用 tmux 常驻启动 Remote Control,会话命名为"家里工作台"。
全部用中文说明,每一步给出可复制的命令。
```

---

## Prompt ②:设置默认轮询任务(让它每次自动帮我盯这些)

```
帮我在 ~/.claude/loop.md 里创建一个默认轮询清单,内容是:
每次触发时,检查当前项目 main 分支的 CI 状态,如果失败就拉取失败日志、诊断原因、
给出最小修复建议;如果有新的代码变更没提交就提醒我;如果一切正常就用一句话说"一切正常"。
写完后告诉我怎么用 /loop 启动它。
```

---

## Prompt ③:建立云端定时任务(电脑关机也能跑)

```
帮我创建几个 Cloud Routine 定时任务(用 /schedule):
1. 每天早上 9 点,对我这个项目做一次代码 review,总结潜在问题;
2. 每周一上午,跑一次完整测试套件并汇报结果;
3. 如果 GitHub 上有人给这个仓库开了新 PR,就自动做一次简要 review。
建好后用 /schedule list 列出来给我确认,并告诉我怎么在网页 claude.ai/code/routines 里管理它们。
```

---

## Prompt ④:发一个自动干到底的任务(示例,按需改)

```
/goal 把 <这里写你的目标,例如:所有单元测试通过并且 lint 没有报错>。
过程中自动推进,不要每一步都问我;遇到真正需要我决策的地方再停下来问。
```

---

## Prompt ⑤:确认遥控状态(想检查连没连上时用)

```
/rc
```
> 会显示当前 Remote Control 的状态、会话链接和二维码。iPad 上扫这个码即可接管。

---

## 使用顺序建议

1. 先粘 **Prompt ①**,把环境和遥控配好
2. 再粘 **Prompt ②**,设好默认轮询
3. 想要电脑关机也持续跑的,粘 **Prompt ③**
4. 有具体任务时,用 **Prompt ④** 的格式发给它
5. 在 iPad 上想确认连接,随时用 **Prompt ⑤**

> 提示:①③⑤ 在哪台设备发都行(会同步);但要碰家里电脑本地文件的活,
> 必须是家里电脑上那个 Remote Control 会话在跑。
