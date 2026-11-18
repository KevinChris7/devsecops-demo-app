<#
  Machine check for the GitHub worm incident. READ-ONLY: it changes nothing on the machine.

  Run it in a normal PowerShell window (no admin needed; as admin it can also read Defender history):
    powershell -ExecutionPolicy Bypass -File .\machine-check.ps1                 # Triage: before cleaning
    powershell -ExecutionPolicy Bypass -File .\machine-check.ps1 -Mode Verify    # Verify: after reset/clean and setup

  Result:  RED    = signs of the worm. Triage: the machine must be reset. Verify: stop, it is not clean.
           AMBER  = needs a look. Send the report to Kevin.
           GREEN  = nothing found.
  The report is saved to the Desktop (machine-check-<computer>-<mode>-<date>.txt and .csv).
#>
param(
  [ValidateSet('Triage', 'Verify')] [string]$Mode = 'Triage',
  [string]$ScanRoot = '',
  [string]$ReportDir = '',
  [string[]]$ExtraPaths = @(),                  # other folders with code, e.g. -ExtraPaths D:\projects,E:\work
  [datetime]$CleanDate = [datetime]::MinValue   # Verify: when the machine was reset/cleaned (default: Windows install date)
)

$ErrorActionPreference = 'Continue'
$Version = '1.0'
$HomeDir = $env:USERPROFILE
if (-not $HomeDir) { $HomeDir = $HOME }
if (-not $ScanRoot) { $ScanRoot = $HomeDir }
if (-not $ReportDir) {
  $ReportDir = Join-Path $HomeDir 'Desktop'
  if (-not (Test-Path -LiteralPath $ReportDir)) { $ReportDir = $HomeDir }
}

$findings = New-Object System.Collections.Generic.List[object]
function Add-Finding([string]$Level, [string]$Check, [string]$Detail) {
  $findings.Add([pscustomobject]@{ Level = $Level; Check = $Check; Detail = $Detail })
}
function Get-EnvPath([string]$Name, [string]$Child) {
  $base = [Environment]::GetEnvironmentVariable($Name)
  if (-not $base) { return $null }
  if ($Child) { return (Join-Path $base $Child) }
  return $base
}
function Test-Cmd([string]$Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
function Short([string]$s, [int]$n = 300) { if ($null -eq $s) { return '' }; if ($s.Length -gt $n) { return $s.Substring(0, $n) + '...' }; return $s }

Write-Host "Machine check v$Version ($Mode) - scanning, this can take a few minutes..." -ForegroundColor Cyan

# ---------------------------------------------------------------- Clean date
if ($Mode -eq 'Verify' -and $CleanDate -eq [datetime]::MinValue) {
  try { $CleanDate = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).InstallDate } catch { $CleanDate = [datetime]::MinValue }
}

# ---------------------------------------------------------------- 1. Files under the user profile
# One pass over the profile. Skips node_modules, .git internals and links (Windows profiles contain looping junctions).
$wormFiles   = @('temp_auto_push.bat', 'temp_interactive_push.bat')
$maybeFiles  = @('branch_structure.json', 'config.bat')
$configRegex = '^(vite|next|postcss|tailwind|eslint|babel|webpack|nuxt|svelte|astro|vue|jest|vitest|rollup|tsup|remix|metro)\.config\.(js|cjs|mjs|ts|cts|mts)$|^gatsby-config\.(js|mjs|ts)$|^\.eslintrc\.(js|cjs)$'
$skipDirs    = @('node_modules', '.git', '$Recycle.Bin', 'System Volume Information')
$repoDirs    = New-Object System.Collections.Generic.List[object]
$scanned = 0; $unreadable = 0

# OneDrive folders are also marked as links when files are online-only; those are walked (they don't loop)
$cloudRoots = @(@($env:OneDrive, $env:OneDriveCommercial, $env:OneDriveConsumer) | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar })
function Test-InCloud([string]$Path) {
  foreach ($c in $cloudRoots) { if (($Path + [System.IO.Path]::DirectorySeparatorChar).StartsWith($c, [System.StringComparison]::OrdinalIgnoreCase)) { return $true } }
  return $false
}

$stack = New-Object System.Collections.Generic.Stack[string]
foreach ($root in @($ScanRoot) + $ExtraPaths) {
  if ($root -and (Test-Path -LiteralPath $root)) { $stack.Push((Resolve-Path -LiteralPath $root).Path) }
  elseif ($root) { Add-Finding 'AMBER' 'Folder to scan not found' $root }
}
while ($stack.Count -gt 0) {
  $dir = $stack.Pop()
  try { $entries = [System.IO.Directory]::GetFileSystemEntries($dir) } catch { $unreadable++; continue }
  foreach ($p in $entries) {
    try { $attr = [System.IO.File]::GetAttributes($p) } catch { continue }
    $name = [System.IO.Path]::GetFileName($p)
    if (($attr -band [System.IO.FileAttributes]::Directory) -eq [System.IO.FileAttributes]::Directory) {
      if ((($attr -band [System.IO.FileAttributes]::ReparsePoint) -eq [System.IO.FileAttributes]::ReparsePoint) -and -not (Test-InCloud $p)) { continue }
      if ($name -eq '.git') { $repoDirs.Add([pscustomobject]@{ Repo = $dir; Created = [System.IO.Directory]::GetCreationTime($p) }); continue }
      if ($skipDirs -contains $name) { continue }
      $stack.Push($p); continue
    }
    $scanned++
    $lname = $name.ToLowerInvariant()
    try {
      if ($wormFiles -contains $lname) { Add-Finding 'RED' 'Worm spreader file' $p; continue }
      if ($maybeFiles -contains $lname) { Add-Finding 'AMBER' 'Possible worm file (check)' $p; continue }

      if ($lname -eq 'tasks.json' -and ([System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($p))) -eq '.vscode') {
        $t = [System.IO.File]::ReadAllText($p)
        if ($t -match '"runOn"\s*:\s*"folderOpen"') { Add-Finding 'RED' 'VS Code task that runs on folder open' $p }
        continue
      }
      if ($lname -match $configRegex) {
        $fi = New-Object System.IO.FileInfo($p)
        if ($fi.Length -gt 5MB) { Add-Finding 'AMBER' 'Unusually large config file' $p; continue }
        $t = [System.IO.File]::ReadAllText($p)
        $maxLen = 0
        foreach ($line in ($t -split "`n")) { if ($line.Length -gt $maxLen) { $maxLen = $line.Length } }
        if ($t -match '[ \t]{150,}\S') { Add-Finding 'RED' 'Config file with code hidden after long whitespace' $p }
        elseif ($maxLen -gt 1000) { Add-Finding 'RED' "Config file with a $maxLen-character line" $p }
        elseif ($maxLen -gt 300 -and $t -match 'eval\(|Function\(|atob\(|fromCharCode|\\x[0-9a-fA-F]{2}') { Add-Finding 'RED' 'Config file with long obfuscated code' $p }
        elseif ($maxLen -gt 300) { Add-Finding 'AMBER' "Config file with a $maxLen-character line (check)" $p }
        continue
      }
      if ($lname.EndsWith('.woff2')) {
        $fs = [System.IO.File]::OpenRead($p)
        try { $buf = New-Object byte[] 4; $n = $fs.Read($buf, 0, 4) } finally { $fs.Close() }
        $magic = [System.Text.Encoding]::ASCII.GetString($buf, 0, $n)
        if ($magic -ne 'wOF2') { Add-Finding 'RED' 'Fake font file (not a real WOFF2 font)' $p }
        continue
      }
      if ($lname -eq '.git-credentials') {
        $lvl = 'AMBER'; if ($Mode -eq 'Verify') { $lvl = 'RED' }
        Add-Finding $lvl 'Plain-text Git password file' $p; continue
      }
      if ($lname -eq '.npmrc') {
        $t = [System.IO.File]::ReadAllText($p)
        if ($t -match '_authToken|_auth\s*=|_password') { Add-Finding 'AMBER' 'npm token stored in .npmrc (rotate it and remove)' $p }
        continue
      }
    } catch { $unreadable++ }
  }
}
Add-Finding 'INFO' 'Files scanned' "$scanned files under $((@($ScanRoot) + $ExtraPaths) -join ', ') ($unreadable folders/files could not be read)"

# Old repo clones
if ($repoDirs.Count -gt 0) {
  if ($Mode -eq 'Triage') {
    Add-Finding 'INFO' 'Repo folders on this machine' ("$($repoDirs.Count) found. All must be deleted during the clean-up. " + (($repoDirs | Select-Object -First 15 | ForEach-Object { $_.Repo }) -join '; '))
  } else {
    $old = @($repoDirs | Where-Object { $_.Created -lt $CleanDate })
    if ($old.Count -gt 0) { Add-Finding 'AMBER' 'Repo folders older than the clean-up (delete and clone fresh)' (($old | Select-Object -First 15 | ForEach-Object { "$($_.Repo) ($($_.Created.ToString('yyyy-MM-dd')))" }) -join '; ') }
    else { Add-Finding 'INFO' 'Repo folders' "$($repoDirs.Count) found, all cloned after $($CleanDate.ToString('yyyy-MM-dd'))" }
  }
}

# Hooks inside repos: a repo's own hooks folder switches the company safety check off for that repo
foreach ($r in $repoDirs) {
  $gitDir = Join-Path $r.Repo '.git'
  try {
    $cfg = Join-Path $gitDir 'config'
    if ((Test-Path -LiteralPath $cfg) -and ([System.IO.File]::ReadAllText($cfg) -match '(?m)^\s*hookspath\s*=\s*(.+)$')) {
      Add-Finding 'AMBER' 'Repo sets its own hooks folder, so the company safety check does not run in it (check)' "$($r.Repo): hooksPath = $($Matches[1].Trim())"
    }
    $hd = Join-Path $gitDir 'hooks'
    if (Test-Path -LiteralPath $hd) {
      $active = @(Get-ChildItem -LiteralPath $hd -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne '.sample' })
      if ($active.Count -gt 0) { Add-Finding 'AMBER' 'Repo has its own active Git hooks (check)' "$($r.Repo): $(($active | ForEach-Object { $_.Name }) -join ', ')" }
    }
  } catch { $unreadable++ }
}

# ---------------------------------------------------------------- 2. Discord, VS Code and Cursor tampering
foreach ($d in @('Discord', 'DiscordPTB', 'DiscordCanary')) {
  $root = Get-EnvPath 'LOCALAPPDATA' $d
  if (-not $root -or -not (Test-Path -LiteralPath $root)) { continue }
  Get-ChildItem -LiteralPath $root -Directory -Filter 'app-*' -ErrorAction SilentlyContinue | ForEach-Object {
    Get-ChildItem -LiteralPath (Join-Path $_.FullName 'modules') -Directory -Filter 'discord_desktop_core-*' -ErrorAction SilentlyContinue | ForEach-Object {
      $idx = Join-Path $_.FullName 'discord_desktop_core\index.js'
      if (Test-Path -LiteralPath $idx) {
        $c = ([System.IO.File]::ReadAllText($idx)).Trim()
        if ($c -ne "module.exports = require('./core.asar');" -and $c -ne 'module.exports = require("./core.asar");') {
          Add-Finding 'RED' "$d has been modified (code injected into its startup file)" $idx
        }
      }
    }
  }
}

function Test-EditorInstall([string]$Label, [string]$Root, [string]$ExeName) {
  if (-not $Root -or -not (Test-Path -LiteralPath $Root)) { return }
  $app = Join-Path $Root 'resources\app'
  if (-not (Test-Path -LiteralPath $app)) { return }
  $checked = 0; $bad = @()
  $productJson = Join-Path $app 'product.json'
  if (Test-Path -LiteralPath $productJson) {
    try {
      $product = Get-Content -LiteralPath $productJson -Raw | ConvertFrom-Json
      if ($product.checksums) {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        foreach ($prop in $product.checksums.PSObject.Properties) {
          $f = Join-Path (Join-Path $app 'out') ($prop.Name -replace '/', '\')
          if (-not (Test-Path -LiteralPath $f)) { $f = Join-Path (Join-Path $app 'out') $prop.Name }
          if (-not (Test-Path -LiteralPath $f)) { continue }
          $hash = [Convert]::ToBase64String($sha.ComputeHash([System.IO.File]::ReadAllBytes($f))).TrimEnd('=')
          $checked++
          if ($hash -ne ([string]$prop.Value).TrimEnd('=')) { $bad += $prop.Name }
        }
      }
    } catch { Add-Finding 'INFO' "$Label check" "Could not read $productJson" }
  }
  if ($bad.Count -gt 0) { Add-Finding 'RED' "$Label program files have been modified" ("Files that don't match the installer: " + ($bad -join ', ')) }
  elseif ($checked -gt 0) { Add-Finding 'INFO' "$Label program files" "$checked core files match the installer" }
  # Files changed well after the program itself was installed or updated
  $exe = Get-ChildItem -LiteralPath $Root -Filter $ExeName -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($exe) {
    $limit = $exe.LastWriteTime.AddHours(2)
    $late = @(Get-ChildItem -LiteralPath $app -Recurse -File -Include *.js, *.cjs, *.mjs -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $limit } | Select-Object -First 10)
    if ($late.Count -gt 0) { Add-Finding 'AMBER' "$Label files changed after it was installed (check)" (($late | ForEach-Object { $_.FullName }) -join '; ') }
  }
}
Test-EditorInstall 'VS Code' (Get-EnvPath 'LOCALAPPDATA' 'Programs\Microsoft VS Code') 'Code.exe'
Test-EditorInstall 'VS Code' (Get-EnvPath 'ProgramFiles' 'Microsoft VS Code') 'Code.exe'
Test-EditorInstall 'Cursor' (Get-EnvPath 'LOCALAPPDATA' 'Programs\cursor') 'Cursor.exe'

# Recently added VS Code extensions (for review)
$extDir = Join-Path $HomeDir '.vscode\extensions'
if (Test-Path -LiteralPath $extDir) {
  $recent = @(Get-ChildItem -LiteralPath $extDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime -gt (Get-Date).AddDays(-120) } | Select-Object -First 25)
  if ($recent.Count -gt 0) { Add-Finding 'INFO' 'VS Code extensions added in the last 120 days (check you know each one)' (($recent | ForEach-Object { $_.Name }) -join ', ') }
}

# ---------------------------------------------------------------- 3. Running Node.js processes and their connections
try {
  $procs = @(Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction Stop)
  foreach ($pr in $procs) {
    $conns = ''
    try { $conns = (@(Get-NetTCPConnection -OwningProcess $pr.ProcessId -State Established -ErrorAction Stop | ForEach-Object { "$($_.RemoteAddress):$($_.RemotePort)" }) -join ', ') } catch { }
    $cl = [string]$pr.CommandLine
    $lvl = 'AMBER'
    if ($cl -match '\\AppData\\|\\Temp\\|\s-e\s|--eval|eval\(') { $lvl = 'RED' }
    Add-Finding $lvl 'Node.js process running (should be none during the stop-work period)' (Short "PID $($pr.ProcessId): $cl  connections: $conns" 600)
  }
} catch { Add-Finding 'INFO' 'Running processes' 'Could not list processes on this system' }

# ---------------------------------------------------------------- 4. Things that start automatically
$suspicious = '(?i)node(\.exe)?["\s]|wscript|cscript|mshta|powershell.*(-enc|-e\s|-w\s*hidden|-windowstyle\s*hidden)|\.vbs\b|\.js\b|\.bat\b|\.cmd\b|\\temp\\'
$runKeys = @(
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
  'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
  'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')
$regOk = $false
foreach ($k in $runKeys) {
  try {
    if (-not (Test-Path $k)) { continue }
    $regOk = $true
    $item = Get-ItemProperty -Path $k -ErrorAction Stop
    foreach ($prop in $item.PSObject.Properties) {
      if ($prop.Name -like 'PS*') { continue }
      $val = [string]$prop.Value
      if ($val -match $suspicious) { Add-Finding 'RED' 'Suspicious program set to run at sign-in' (Short "$k\$($prop.Name) = $val") }
      else { Add-Finding 'INFO' 'Program set to run at sign-in' (Short "$($prop.Name) = $val") }
    }
  } catch { }
}
if (-not $regOk) { Add-Finding 'INFO' 'Startup registry' 'Not available on this system' }

foreach ($sf in @((Get-EnvPath 'APPDATA' 'Microsoft\Windows\Start Menu\Programs\Startup'), (Get-EnvPath 'ProgramData' 'Microsoft\Windows\Start Menu\Programs\StartUp'))) {
  if (-not $sf -or -not (Test-Path -LiteralPath $sf)) { continue }
  Get-ChildItem -LiteralPath $sf -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' } | ForEach-Object {
    if ($_.Extension -match '(?i)^\.(bat|cmd|vbs|js|ps1|exe)$') { Add-Finding 'RED' 'Script or program in the Startup folder' $_.FullName }
    else { Add-Finding 'INFO' 'Shortcut in the Startup folder' $_.FullName }
  }
}

try {
  $tasks = @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskPath -notlike '\Microsoft\*' })
  foreach ($t in $tasks) {
    foreach ($a in @($t.Actions)) {
      $cmd = "$($a.Execute) $($a.Arguments)".Trim()
      if (-not $cmd) { continue }
      if ($cmd -match $suspicious) { Add-Finding 'RED' 'Suspicious scheduled task' (Short "$($t.TaskPath)$($t.TaskName): $cmd") }
      elseif ($cmd -match '(?i)\\AppData\\|%localappdata%|%appdata%') { Add-Finding 'AMBER' 'Scheduled task running a program from the user profile (check; updaters often do this)' (Short "$($t.TaskPath)$($t.TaskName): $cmd") }
      else { Add-Finding 'INFO' 'Scheduled task (not Microsoft)' (Short "$($t.TaskPath)$($t.TaskName): $cmd") }
    }
  }
} catch { Add-Finding 'INFO' 'Scheduled tasks' 'Not available on this system' }

# ---------------------------------------------------------------- 5. Git settings and saved credentials
$safetyHooks = Join-Path $HomeDir '.git-safety\hooks'
if (Test-Cmd 'git') {
  foreach ($scope in @('--global', '--system')) {
    $lines = @(& git config $scope --list 2>$null)
    foreach ($l in $lines) {
      $kv = $l -split '=', 2; $key = $kv[0].ToLowerInvariant(); $val = ''; if ($kv.Count -gt 1) { $val = $kv[1] }
      if ($key -eq 'core.hookspath') {
        $norm = { param($x) ($x -replace '\\', '/').TrimEnd('/').ToLowerInvariant() }
        if ((& $norm $val) -eq (& $norm $safetyHooks)) { Add-Finding 'INFO' 'Git hooks folder' "Company safety hooks ($val)" }
        else { Add-Finding 'RED' 'Git is set to run hooks from an unexpected folder' "git config $scope core.hooksPath = $val" }
      }
      elseif ($key -eq 'init.templatedir') { Add-Finding 'RED' 'Git template folder set (can plant hooks in every new clone)' "git config $scope init.templateDir = $val" }
      elseif ($key -match '^url\..*\.insteadof$') { Add-Finding 'RED' 'Git is redirecting repository addresses' "git config $scope $l" }
      elseif ($key -like 'alias.*' -and $val.StartsWith('!')) { Add-Finding 'AMBER' 'Git alias that runs a shell command (check)' "git config $scope $l" }
      elseif ($key -eq 'credential.helper') { Add-Finding 'INFO' 'Git credential helper' "$scope $val" }
    }
  }
} else { Add-Finding 'INFO' 'Git' 'Git is not installed' }

if (Test-Cmd 'cmdkey') {
  $gh = @(& cmdkey /list 2>$null | Select-String -Pattern 'Target:.*github' | ForEach-Object { $_.Line.Trim() })
  if ($gh.Count -gt 0) {
    if ($Mode -eq 'Triage') { Add-Finding 'INFO' 'Saved GitHub credentials (remove during clean-up)' ($gh -join '; ') }
    else { Add-Finding 'INFO' 'Saved GitHub credentials (should only be the new sign-in made after the clean-up)' ($gh -join '; ') }
  }
}

# ---------------------------------------------------------------- 6. Hosts file
$hosts = Get-EnvPath 'SystemRoot' 'System32\drivers\etc\hosts'
if ($hosts -and (Test-Path -LiteralPath $hosts)) {
  $entries = @(Get-Content -LiteralPath $hosts -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch '^\s*(#|$)' -and $_ -notmatch '^\s*(127\.0\.0\.1|::1)\s+localhost\s*$' })
  if ($entries.Count -gt 0) { Add-Finding 'AMBER' 'Extra entries in the hosts file (check)' (($entries | Select-Object -First 10) -join '; ') }
}

# ---------------------------------------------------------------- 7. Microsoft Defender
try {
  $mp = Get-MpComputerStatus -ErrorAction Stop
  if (-not $mp.RealTimeProtectionEnabled) { Add-Finding 'AMBER' 'Defender real-time protection is OFF' 'Turn it on in Windows Security' }
  if ($mp.AntivirusSignatureAge -gt 3) { Add-Finding 'AMBER' 'Defender virus definitions are out of date' "$($mp.AntivirusSignatureAge) days old: run Windows Update" }
  $fullScan = $mp.FullScanEndTime
  if ($Mode -eq 'Verify') {
    if (-not $fullScan -or $fullScan -lt $CleanDate) { Add-Finding 'AMBER' 'No full Defender scan since the clean-up' 'Run a full scan (Windows Security > Virus & threat protection > Scan options > Full scan)' }
    else { Add-Finding 'INFO' 'Last full Defender scan' $fullScan.ToString('yyyy-MM-dd HH:mm') }
  }
  try {
    $det = @(Get-MpThreatDetection -ErrorAction Stop | Where-Object { $_.InitialDetectionTime -gt (Get-Date).AddDays(-120) })
    foreach ($d in ($det | Select-Object -First 15)) {
      $th = Get-MpThreat -ThreatID $d.ThreatID -ErrorAction SilentlyContinue
      $lvl = 'RED'
      if ($Mode -eq 'Verify' -and $d.InitialDetectionTime -lt $CleanDate) { $lvl = 'INFO' }
      Add-Finding $lvl 'Defender found malware' (Short "$($d.InitialDetectionTime.ToString('yyyy-MM-dd')): $($th.ThreatName) in $($d.Resources -join ', ')")
    }
  } catch { Add-Finding 'INFO' 'Defender history' 'Run this script as administrator to include Defender detection history' }
} catch { Add-Finding 'INFO' 'Microsoft Defender' 'Defender status not available on this system' }

# ---------------------------------------------------------------- 8. Setup checks (Verify only)
if ($Mode -eq 'Verify') {
  if (Test-Cmd 'npm') {
    $ign = (& npm config get ignore-scripts 2>$null | Out-String).Trim()
    if ($ign -ne 'true') { Add-Finding 'AMBER' 'npm install scripts are still allowed' 'Run setup-dev-machine.ps1 (or: npm config set ignore-scripts true)' }
  }
  foreach ($ed in @(@('VS Code', 'Code'), @('Cursor', 'Cursor'))) {
    $edDir = Get-EnvPath 'APPDATA' $ed[1]
    if (-not $edDir -or -not (Test-Path -LiteralPath $edDir)) { continue }
    $settings = Join-Path $edDir 'User\settings.json'
    $ok = $false
    if ($settings -and (Test-Path -LiteralPath $settings)) { $ok = ([System.IO.File]::ReadAllText($settings) -match '"task\.allowAutomaticTasks"\s*:\s*"off"') }
    if (-not $ok) { Add-Finding 'AMBER' "$($ed[0]) can still run tasks automatically" 'Run setup-dev-machine.ps1' }
  }
  $hook = Join-Path $safetyHooks 'pre-push'
  if (-not (Test-Path -LiteralPath $hook) -or -not ((Get-Content -LiteralPath $hook -Raw) -match 'company-safety-pre-push')) { Add-Finding 'AMBER' 'Safety pre-push check is not installed' 'Run setup-dev-machine.ps1' }
  else {
    $selftest = Join-Path (Split-Path $safetyHooks -Parent) 'selftest.txt'
    $stText = ''; if (Test-Path -LiteralPath $selftest) { $stText = (Get-Content -LiteralPath $selftest -Raw).Trim() }
    if ($stText -notmatch '^PASS') { Add-Finding 'AMBER' 'Safety pre-push check has not passed its self-test' "Run setup-dev-machine.ps1 again. Last result: $stText" }
    else { Add-Finding 'INFO' 'Safety pre-push check' "Self-test: $stText" }
    $hp = (& git config --global --get core.hooksPath 2>$null)
    if (-not $hp) { Add-Finding 'AMBER' 'Safety pre-push check is installed but not switched on' 'Run setup-dev-machine.ps1 again' }
  }
  foreach ($tool in @('git', 'gitleaks', 'snyk')) { if (-not (Test-Cmd $tool)) { Add-Finding 'AMBER' "$tool is not installed" 'See the Phase 4 runbook, step 4' } }
}

# ---------------------------------------------------------------- Report
$order = @{ 'RED' = 0; 'AMBER' = 1; 'INFO' = 2 }
$sorted = @($findings | Sort-Object { $order[$_.Level] }, Check)
$red = @($sorted | Where-Object { $_.Level -eq 'RED' }).Count
$amber = @($sorted | Where-Object { $_.Level -eq 'AMBER' }).Count
$result = 'GREEN'; if ($amber -gt 0) { $result = 'AMBER' }; if ($red -gt 0) { $result = 'RED' }

$meaning = @{
  'Triage' = @{ 'RED' = 'Signs of the worm. This machine MUST be reset (Reset this PC > Remove everything).';
                'AMBER' = 'Items need a look. Send this report to Kevin before choosing reset or deep clean.';
                'GREEN' = 'Nothing found. Reset is still preferred; a supervised deep clean is acceptable.' };
  'Verify' = @{ 'RED' = 'NOT CLEAN. Stop: do not sign in to GitHub or client systems. Send this report to Kevin.';
                'AMBER' = 'Almost there: fix the items listed, then run the check again.';
                'GREEN' = 'Clear. Send this report to the tech lead to be marked as cleared.' }
}

$computer = $env:COMPUTERNAME; if (-not $computer) { $computer = [System.Environment]::MachineName }
$user = $env:USERNAME; if (-not $user) { $user = $env:USER }
$stamp = (Get-Date).ToString('yyyyMMdd-HHmmss')
$base = Join-Path $ReportDir "machine-check-$computer-$Mode-$stamp"
$header = @(
  "Machine check v$Version", "Mode:      $Mode", "Computer:  $computer", "User:      $user",
  "Date:      $((Get-Date).ToString('yyyy-MM-dd HH:mm'))")
if ($Mode -eq 'Verify') { $header += "Clean-up date used: $($CleanDate.ToString('yyyy-MM-dd'))" }
$header += @('', "RESULT: $result  ($red red, $amber amber)", $meaning[$Mode][$result], '', 'FINDINGS', '--------')
$body = $sorted | ForEach-Object { "[$($_.Level)] $($_.Check)`r`n        $($_.Detail)" }
$utf8 = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText("$base.txt", (($header + $body) -join "`r`n") + "`r`n", $utf8)
$sorted | Export-Csv -LiteralPath "$base.csv" -NoTypeInformation -Encoding UTF8
$hash = (Get-FileHash -LiteralPath "$base.txt" -Algorithm SHA256).Hash

Write-Host ''
$color = @{ 'RED' = 'Red'; 'AMBER' = 'Yellow'; 'GREEN' = 'Green' }[$result]
Write-Host "RESULT: $result  ($red red, $amber amber)" -ForegroundColor $color
Write-Host $meaning[$Mode][$result]
foreach ($f in ($sorted | Where-Object { $_.Level -ne 'INFO' } | Select-Object -First 20)) {
  Write-Host ("  [{0}] {1}: {2}" -f $f.Level, $f.Check, (Short $f.Detail 160))
}
Write-Host ''
Write-Host "Report: $base.txt"
Write-Host "SHA-256: $hash"
