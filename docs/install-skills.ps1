<#
 wabot · Claude Code skill 安装脚本(Windows PowerShell 5.1 / 7)
 用法(在 PowerShell 里执行,默认什么都不装,只做前置检查):
   .\install-skills.ps1                       # 只检查 Node / Git / 目录
   .\install-skills.ps1 -FindSkills           # 手动方式装 find-skills(零遥测,改为手动触发)
   .\install-skills.ps1 -StopSlopZh           # 装中文版 stop-slop-zh(手动触发)
   .\install-skills.ps1 -UiUxProMax           # 通过插件市场装 ui-ux-pro-max(做监控面板时再用)
   .\install-skills.ps1 -TaskObserver         # 下载 v3.1.0 .skill 包并校验 SHA256(需先有 Git for Windows)
   .\install-skills.ps1 -WabotSkills -WabotDir "C:\Users\lim_2\Documents\wabot"   # 把 docs/skills 的两个自建 skill 放进 wabot\.claude\skills
 每条命令都来自 2026-09-09 的一手核实;claude-mem 故意不提供(结论:不装)。
 若报 "running scripts is disabled":先执行  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
#>
param(
  [switch]$FindSkills,
  [switch]$StopSlopZh,
  [switch]$UiUxProMax,
  [switch]$TaskObserver,
  [switch]$WabotSkills,
  [string]$WabotDir = "C:\Users\lim_2\Documents\wabot"
)
$ErrorActionPreference = "Stop"
$skillsDir = Join-Path $env:USERPROFILE ".claude\skills"
$env:DISABLE_TELEMETRY = "1"

function Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function AddManualOnly($skillMd) {
  # 在 frontmatter 的 name: 行后插入 disable-model-invocation: true,只有手动 /名字 才触发
  $lines = Get-Content -Encoding utf8 $skillMd
  if ($lines -match '^disable-model-invocation:') { return }
  $out = @(); $done = $false
  foreach ($l in $lines) { $out += $l; if (-not $done -and $l -match '^name:') { $out += 'disable-model-invocation: true'; $done = $true } }
  Set-Content -Encoding utf8 $skillMd $out
}

Step "前置检查"
New-Item -ItemType Directory -Force $skillsDir | Out-Null
try { $node = (node -v) } catch { $node = "(没有 Node)" }
try { $git = (git --version) } catch { $git = "(没有 Git)" }
Write-Host "Node: $node   (npx skills 需要 >= 22.20.0;纯下载方式不需要)"
Write-Host "Git : $git    (task-observer / stop-slop clone 需要 Git for Windows)"
Write-Host "Skills 目录: $skillsDir"

if ($FindSkills) {
  Step "find-skills(手动下载,零遥测)"
  $d = Join-Path $skillsDir "find-skills"; New-Item -ItemType Directory -Force $d | Out-Null
  Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/vercel-labs/skills/main/skills/find-skills/SKILL.md" -OutFile (Join-Path $d "SKILL.md")
  AddManualOnly (Join-Path $d "SKILL.md")
  Write-Host "已装到 $d,只有输入 /find-skills 才会触发。它搜索/安装时会调用 npx skills(需要 Node >= 22.20)。"
}

if ($StopSlopZh) {
  Step "stop-slop-zh(中文去 AI 腔,手动触发)"
  $d = Join-Path $skillsDir "stop-slop-zh"
  if (Test-Path $d) { Remove-Item -Recurse -Force $d }
  git clone --depth 1 https://github.com/VincentOld/stop-slop-zh.git $d
  Remove-Item -Recurse -Force (Join-Path $d ".git")
  AddManualOnly (Join-Path $d "SKILL.md")
  Write-Host "已装到 $d。注意它的 frontmatter name 可能是 stop-ai-slop-zh,在 Claude Code 输入 /stop 按 Tab 看实际名字。"
}

if ($UiUxProMax) {
  Step "ui-ux-pro-max(插件市场路线)"
  try { $py = (py -3 --version) } catch { $py = "(没有 Python)" }
  Write-Host "Python: $py  (需要 3.8+;没有就 winget install Python.Python.3.12,并关闭「应用执行别名」里的 python.exe / python3.exe)"
  claude plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
  claude plugin install ui-ux-pro-max@ui-ux-pro-max-skill
  Write-Host "装完后在 Claude Code 里 /reload-plugins。建议只留核心 skill:插件缓存目录下删除 design、banner-design、brand、design-system、slides、ui-styling 六个子目录。"
}

if ($TaskObserver) {
  Step "task-observer v3.1.0(下载 .skill 包 + SHA256 校验)"
  $zip = Join-Path $env:TEMP "task-observer.zip"
  Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/rebelytics/one-skill-to-rule-them-all/releases/download/v3.1.0/task-observer.skill" -OutFile $zip
  $h = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
  if ($h -ne "82ab3e7061cea60c37c36da57e88eb2860bb24169315083715d69a9268a88433") { throw "SHA256 不匹配: $h" }
  Expand-Archive -Path $zip -DestinationPath $skillsDir -Force
  Write-Host "已装到 $skillsDir\task-observer。还需要把激活块写进 ~\.claude\CLAUDE.md(见 docs/SKILLS-EVAL.md),工作区用 C:/Users/$env:USERNAME/.claude/task-observer-workspace;必须已安装 Git for Windows。"
}

if ($WabotSkills) {
  Step "wabot 自建 skill:fb-copy-gate + n8n-deploy"
  $src = Join-Path $PSScriptRoot "skills"
  $dst = Join-Path $WabotDir ".claude\skills"
  New-Item -ItemType Directory -Force $dst | Out-Null
  Copy-Item -Recurse -Force (Join-Path $src "fb-copy-gate") $dst
  Copy-Item -Recurse -Force (Join-Path $src "n8n-deploy") $dst
  Write-Host "已复制到 $dst。在 wabot 的 Claude Code 会话里输入 /skills 应能看到 fb-copy-gate 与 n8n-deploy。"
}

Step "完成。进 Claude Code 输入 /skills 核对;若看不到新 skill,重启 Claude Code 一次。"
