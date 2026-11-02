#Requires -Version 5.1
<#
.SYNOPSIS
    给 DeepSeek Harness 装一个额外的 agent 预设 `whale`（官方 standard 的逐字副本）。

.DESCRIPTION
    做三件事：
      1. 把 bundle 复制到 <DSH_HOME>/profiles/<profile>/local-bundles/whale-preset
      2. 在 profile 的 package.json 里登记依赖 link:./local-bundles/whale-preset
      3. 把 dsh-whale-preset 追加进 dsh.profile.bundles
    修改 package.json 之前会自动备份。

.PARAMETER DshHome
    DSH 的家目录，默认取 $env:DSH_HOME，再退到 ~/.dsh

.PARAMETER Profile
    profile 目录名，默认 desktop

.PARAMETER DryRun
    只打印将要做什么，不写任何文件

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -DshHome D:\dsh-home -DryRun
#>
[CmdletBinding()]
param(
    [string]$DshHome = "",
    [string]$Profile = "desktop",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
$PackageName = "dsh-whale-preset"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say($msg) { Write-Host $msg }

function Resolve-DshHome {
    if ($DshHome) { return $DshHome }
    if ($env:DSH_HOME) { return $env:DSH_HOME }
    $candidate = Join-Path $HOME ".dsh"
    if (Test-Path $candidate) { return $candidate }
    return $candidate
}

$homeDir = Resolve-DshHome
$profileDir = Join-Path (Join-Path $homeDir "profiles") $Profile
$profilePkg = Join-Path $profileDir "package.json"
$destDir = Join-Path (Join-Path $profileDir "local-bundles") "whale-preset"

Say "DSH home : $homeDir"
Say "profile  : $profileDir"

if (-not (Test-Path $profileDir)) {
    throw "profile 目录不存在：$profileDir（确认 DSH 装过、且 profile 名对；可用 -Profile 指定）"
}
if (-not (Test-Path $profilePkg)) {
    throw "找不到 profile 的 package.json：$profilePkg"
}

# ---- 1) 复制 bundle ----
Say "`n[1/3] 复制 bundle -> $destDir"
foreach ($f in @("cordis.patch.yml", "package.json", "LICENSE")) {
    $src = Join-Path $Here $f
    if (-not (Test-Path $src)) { throw "缺少文件：$src" }
}
if ($DryRun) {
    Say "      (dry-run) 会复制 cordis.patch.yml / package.json / LICENSE"
} else {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Copy-Item (Join-Path $Here "cordis.patch.yml") $destDir -Force
    Copy-Item (Join-Path $Here "package.json") $destDir -Force
    Copy-Item (Join-Path $Here "LICENSE") $destDir -Force
    Say "      已复制 3 个文件"
}

# ---- 2) + 3) 登记进 profile ----
Say "`n[2/3] 在 profile package.json 里登记依赖"
Say "[3/3] 追加到 dsh.profile.bundles"

$raw = Get-Content $profilePkg -Raw -Encoding UTF8
$pkg = $raw | ConvertFrom-Json

if (-not $pkg.dependencies) {
    $pkg | Add-Member -NotePropertyName dependencies -NotePropertyValue ([pscustomobject]@{}) -Force
}
$dep = $pkg.dependencies
$hasDep = $dep.PSObject.Properties.Name -contains $PackageName
$depValue = "link:./local-bundles/whale-preset"

if ($hasDep) {
    $old = $dep.$PackageName
    if ($old -ne $depValue) {
        Say "      依赖已存在但值不同：$old -> $depValue"
        $dep.$PackageName = $depValue
    } else {
        Say "      依赖已存在，保持不动"
    }
} else {
    $dep | Add-Member -NotePropertyName $PackageName -NotePropertyValue $depValue -Force
    Say "      已加依赖 $PackageName = $depValue"
}

if (-not $pkg.dsh) {
    $pkg | Add-Member -NotePropertyName dsh -NotePropertyValue ([pscustomobject]@{}) -Force
}
if (-not $pkg.dsh.profile) {
    $pkg.dsh | Add-Member -NotePropertyName profile -NotePropertyValue ([pscustomobject]@{}) -Force
}
if (-not $pkg.dsh.profile.bundles) {
    $pkg.dsh.profile | Add-Member -NotePropertyName bundles -NotePropertyValue @() -Force
}
$bundles = @($pkg.dsh.profile.bundles)
if ($bundles -contains $PackageName) {
    Say "      bundles 里已有，保持不动"
} else {
    $pkg.dsh.profile.bundles = @($bundles + $PackageName)
    Say "      已追加：$($pkg.dsh.profile.bundles -join ', ')"
}

if ($DryRun) {
    Say "`n(dry-run) 没有写任何文件。"
    return
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backup = "$profilePkg.bak-$stamp"
Copy-Item $profilePkg $backup -Force
Say "`n备份：$backup"

$json = $pkg | ConvertTo-Json -Depth 30
[System.IO.File]::WriteAllText($profilePkg, $json + "`n", (New-Object System.Text.UTF8Encoding($false)))
Say "已写入：$profilePkg"

Say @"

装好了。下一步：

  1. 完全退出 DSH，再重新打开（bundle 只在启动时读）
  2. 新建会话时预设选 'whale'，或者让插件用它：
       <DSH_HOME>/profiles/$Profile/cordis.patch.yml 里给那个插件加
       agentPreset: whale
  3. 验证：用 standard 开一个窗口，确认它没有被塞进那个插件的人设

撤销：把 $backup 覆盖回 package.json，删掉 $destDir，重启。
"@
