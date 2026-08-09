# Claude Code 电脑版:远程遥控 + 持续自动化 配置指南

> 目标:让家里电脑上的 Claude Code **一直挂着自动干活**,并且你能从 **iPad 随时遥控**。
> 用法总结:**家里电脑 = 干活的机器,iPad = 遥控器,云端 Routines = 电脑关机也能跑的定时任务。**

---

## 0. 前提条件(先确认)

- ✅ 订阅是 **Pro / Max / Team / Enterprise**(不能用 API key,必须用 claude.ai 账号)
- ✅ 家里电脑已安装 Claude Code CLI
- ✅ 家里电脑设置里**关闭自动休眠**(Remote Control 是本地进程,电脑睡了就断线)
- ⚠️ **TeamViewer 用不上**——它是给你看屏幕的,不能让 Claude 接进去。遥控靠下面的 Remote Control。

---

## 1. 一次性准备

在家里电脑的终端里跑:

```bash
cd ~/你的项目目录          # 换成你真实的项目路径
claude /login              # 用 claude.ai 账号登录(不是 API key)
claude                     # 首次运行,接受"工作区信任"提示,然后可退出
```

> 如果设过这些环境变量,先取消,否则 Remote Control 连不上:
> `ANTHROPIC_BASE_URL`、`DISABLE_TELEMETRY`、`DO_NOT_TRACK`、`CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`、`DISABLE_GROWTHBOOK`

---

## 2. 开启常驻 Remote Control(核心)

用 `tmux` 挂着,这样关掉终端窗口也不会断:

```bash
tmux new-session -d -s claude "cd ~/你的项目目录 && claude remote-control --name '家里工作台'"
```

- 想看运行状态/二维码:`tmux attach -t claude`,进去后按**空格**显示二维码,按 `Ctrl+b` 再按 `d` 退出但不停止。
- 常用参数:
  - `--name '家里工作台'` 给会话起名,方便在 iPad 上认出来
  - `--continue` 接着上次的会话
  - `--spawn=worktree` 每个会话用独立 git worktree(并行干活不打架)

---

## 3. iPad 上接管

1. 装 **Claude App**(iOS,iPad 通用),用**同一个账号**登录
2. 点底部 **Code** 标签
3. 连接方式二选一:
   - **扫码**:扫电脑终端里显示的二维码
   - **选会话**:在列表里找到"家里工作台"(绿点=在线)
4. (可选)在电脑会话里跑 `/config`,打开推送通知,iPad 就能收到"需要你确认"的提醒

接上之后,你在 iPad 发的指令,**干活的是家里电脑,碰的是你的本地文件**。

---

## 4. 让它"持续 follow up"的三种方式

| 你的需求 | 用什么 | 例子 |
|---|---|---|
| 一次发任务、跑到完成 | `/goal` | `/goal 所有测试通过并且 lint 没有报错` |
| 会话内定时轮询 | `/loop` | `/loop 10m 检查构建是否完成,失败就诊断` |
| 定时/事件触发(电脑关机也跑) | **Cloud Routines** | `/schedule 每天早上9点做一次代码 review` |

### 4.1 `/loop`(会话内轮询)
```
/loop 10m 检查 main 分支 CI,红了就拉日志并给出修复建议
/loop                # 跑默认维护任务(可自定义,见下)
```
自定义默认轮询内容:创建 `~/.claude/loop.md`,把你想让它每次做的事写进去。

### 4.2 `/goal`(自动干到达成目标)
```
/goal test/auth 下所有测试通过且 lint 干净
/goal 把所有接口迁移到 v2 API,或最多做 20 轮后停下
/goal            # 查看当前目标进度
/goal clear      # 清除目标
```

### 4.3 Cloud Routines(最推荐,云端常驻)
在任意 Claude Code 会话里用自然语言创建:
```
/schedule 每天早上9点做一次代码 review
/schedule 每6小时检查一次部署状态
/schedule 每周一跑一次完整测试套件
/schedule list       # 查看所有定时任务
/schedule run        # 立即试跑一次
```
也可以去网页管理:**https://claude.ai/code/routines**
- 支持三种触发:**定时(cron)** / **API 调用** / **GitHub 事件**(如"有人开 PR 就自动 review")
- 跑在云端,**家里电脑关机也能跑**

---

## 5. 常见问题

- **iPad 看不到会话**:确认同一账号 + 会话确实在运行 + 网络正常
- **会话断了**:网络中断超过约 10 分钟会超时,重新跑第 2 步的命令即可
- **定时任务不触发**:Cloud Routines 需要 Pro+ 且开通了 Claude Code on the web
- **电脑一段时间后断线**:多半是自动休眠,去系统设置关掉

---

## 6. 参考文档
- Remote Control: https://code.claude.com/docs/en/remote-control
- 定时任务: https://code.claude.com/docs/en/scheduled-tasks
- Routines: https://code.claude.com/docs/en/routines
- Goal 自动化: https://code.claude.com/docs/en/goal
- 手机 App: https://code.claude.com/docs/en/mobile
