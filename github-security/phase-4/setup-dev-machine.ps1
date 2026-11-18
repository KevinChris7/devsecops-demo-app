<#
  Safe settings for a cleaned developer machine. Run it once the machine has been reset or deep-cleaned,
  in a normal PowerShell window, from the folder that holds the Phase 4 files (including 'pre-push'):

    powershell -ExecutionPolicy Bypass -File .\setup-dev-machine.ps1

  It lists every change it makes, and it is safe to run again (for example after installing Node.js).
  What it sets:
    - Git: runs the company safety check before every push; removes risky Git settings; merge instead of rebase on pull
    - npm: packages can't run install scripts automatically
    - VS Code and Cursor: tasks never run automatically when a folder is opened; Workspace Trust stays on
  It also checks that Git, Node.js, VS Code, gitleaks and Snyk are installed, and says how to install any that are missing.
#>
param(
  [string]$HookSource = '',
  [string]$HomeOverride = ''
)

$ErrorActionPreference = 'Continue'
$HomeDir = $HomeOverride
if (-not $HomeDir) { $HomeDir = $env:USERPROFILE }
if (-not $HomeDir) { $HomeDir = $HOME }
if (-not $HookSource) { $HookSource = Join-Path $PSScriptRoot 'pre-push' }

$changes = New-Object System.Collections.Generic.List[string]
$todo    = New-Object System.Collections.Generic.List[string]
function Test-Cmd([string]$Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

Write-Host 'Setting up safe defaults for this machine...' -ForegroundColor Cyan

# ---------------------------------------------------------------- 1. Git
if (Test-Cmd 'git') {
  # 1a. Company safety check before every push
  $hookDir = Join-Path $HomeDir '.git-safety\hooks'
  $want = ($hookDir -replace '\\', '/')
  # Any other hooks folder (for example one the worm planted) is removed first, whatever happens next
  $have = (& git config --global --get core.hooksPath 2>$null)
  if ($have -and (($have -replace '\\', '/').TrimEnd('/') -ne $want)) {
    & git config --global --unset-all core.hooksPath
    $changes.Add("Git: removed an unexpected hooks folder ($have)")
  }
  if (-not (Test-Path -LiteralPath $HookSource)) {
    $todo.Add("The file 'pre-push' was not found next to this script ($HookSource). Download it with the other Phase 4 files and run this again.")
  } else {
    $hookText = [System.IO.File]::ReadAllText($HookSource)
    if ($hookText -notmatch 'company-safety-pre-push') {
      $todo.Add("'$HookSource' is not the company safety check. Download it again from the incident Teams group.")
    } else {
      New-Item -ItemType Directory -Force -Path $hookDir | Out-Null
      $hookText = $hookText -replace "`r`n", "`n"                        # Git runs hooks with sh: Unix line endings
      $hookFile = Join-Path $hookDir 'pre-push'
      [System.IO.File]::WriteAllText($hookFile, $hookText, $utf8NoBom)
      if ($PSVersionTable.PSEdition -eq 'Core' -and -not $IsWindows) { & chmod +x $hookFile }   # macOS/Linux need the executable bit
      & git config --global core.hooksPath $want
      $changes.Add("Git: company safety check runs before every push ($want/pre-push)")

      # Self-test: a clean push must go through and a push containing a worm sign must be blocked
      $st = Join-Path ([System.IO.Path]::GetTempPath()) ('git-safety-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
      $result = 'FAIL'; $why = ''
      try {
        & git init -q --bare (Join-Path $st 'remote.git') 2>$null
        & git clone -q (Join-Path $st 'remote.git') (Join-Path $st 'work') 2>$null
        $w = Join-Path $st 'work'
        & git -C $w config user.email 'selftest@local'; & git -C $w config user.name 'Safety self-test'
        [System.IO.File]::WriteAllText((Join-Path $w 'README.md'), "self-test`n", $utf8NoBom)
        & git -C $w add -A; & git -C $w commit -q -m 'clean' 2>$null
        & git -C $w push -q origin HEAD 2>$null
        if ($LASTEXITCODE -ne 0) { $why = 'a clean push was refused' }
        else {
          New-Item -ItemType Directory -Force -Path (Join-Path $w '.vscode') | Out-Null
          [System.IO.File]::WriteAllText((Join-Path $w '.vscode\tasks.json'), '{"tasks":[{"runOptions":{"runOn":"folderOpen"}}]}', $utf8NoBom)
          & git -C $w add -A; & git -C $w commit -q -m 'worm sign' 2>$null
          $pushOut = (& git -C $w push origin HEAD 2>&1 | Out-String)
          if ($LASTEXITCODE -ne 0 -and $pushOut -match 'BLOCKED') { $result = 'PASS' }
          else { $why = 'a push containing a worm sign was NOT blocked' }
        }
      } catch { $why = $_.Exception.Message }
      finally { Remove-Item -LiteralPath $st -Recurse -Force -ErrorAction SilentlyContinue }
      [System.IO.File]::WriteAllText((Join-Path (Split-Path $hookDir -Parent) 'selftest.txt'), "$result $((Get-Date).ToString('yyyy-MM-dd HH:mm')) $why`n", $utf8NoBom)
      if ($result -eq 'PASS') { $changes.Add('Git: safety check self-test PASSED (clean push allowed, worm sign blocked)') }
      else { $todo.Add("Safety check self-test FAILED: $why. Send this screen to Kevin.") }
    }
  }
  # 1b. Remove risky Git settings (these were flagged by the machine check)
  $tpl = (& git config --global --get init.templateDir 2>$null)
  if ($tpl) { & git config --global --unset-all init.templateDir; $changes.Add("Git: removed template folder setting ($tpl)") }
  $redirects = @(& git config --global --get-regexp '^url\..*\.insteadof$' 2>$null)
  foreach ($r in $redirects) {
    $key = ($r -split '\s+', 2)[0]
    & git config --global --unset-all $key
    $changes.Add("Git: removed address redirect '$r'")
  }
  # 1c. Pull with merge (force pushes are blocked on the server, so rebased branches can't be pushed)
  & git config --global pull.rebase false
  $changes.Add('Git: pull uses merge, not rebase')
  # 1d. Credentials through Git Credential Manager (browser sign-in, nothing stored in plain text)
  $gcm = $false
  try { & git credential-manager --version *> $null; $gcm = ($LASTEXITCODE -eq 0) } catch { $gcm = $false }
  if ($gcm) { & git config --global credential.helper manager; $changes.Add('Git: sign-in through Git Credential Manager') }
  else { $todo.Add('Git Credential Manager not found: reinstall Git for Windows (winget install --id Git.Git -e)') }
  $plain = Join-Path $HomeDir '.git-credentials'
  if (Test-Path -LiteralPath $plain) { $todo.Add("Delete the plain-text password file $plain (its credentials must already be rotated)") }
} else {
  $todo.Add('Install Git for Windows: winget install --id Git.Git -e   (then run this script again)')
}

# ---------------------------------------------------------------- 2. npm
if (Test-Cmd 'npm') {
  & npm config set ignore-scripts true 2>$null
  $now = (& npm config get ignore-scripts 2>$null | Out-String).Trim()
  if ($now -eq 'true') { $changes.Add('npm: packages cannot run install scripts automatically (npm run <script> still works)') }
  else { $todo.Add('npm: could not turn off install scripts. Run: npm config set ignore-scripts true') }
} else {
  $todo.Add('Install Node.js LTS: winget install --id OpenJS.NodeJS.LTS -e   (then run this script again)')
}

# ---------------------------------------------------------------- 3. VS Code and Cursor
function Set-EditorSetting([string]$Text, [string]$Key, [string]$JsonValue) {
  $pattern = '"' + [regex]::Escape($Key) + '"\s*:\s*("[^"]*"|true|false|\d+)'
  if ($Text -match $pattern) { return [regex]::Replace($Text, $pattern, ('"' + $Key + '": ' + $JsonValue)) }
  $i = $Text.IndexOf('{')
  if ($i -lt 0) { return "{`n  `"$Key`": $JsonValue`n}`n" }
  return $Text.Substring(0, $i + 1) + "`n  `"$Key`": $JsonValue," + $Text.Substring($i + 1)
}
$editors = @(@{ Name = 'VS Code'; Dir = 'Code'; Cmd = 'code' }, @{ Name = 'Cursor'; Dir = 'Cursor'; Cmd = 'cursor' })
$appData = $env:APPDATA
if (-not $appData) { $appData = Join-Path $HomeDir 'AppData\Roaming' }
$anyEditor = $false
foreach ($ed in $editors) {
  $userDir = Join-Path (Join-Path $appData $ed.Dir) 'User'
  if (-not (Test-Path -LiteralPath (Join-Path $appData $ed.Dir)) -and -not (Test-Cmd $ed.Cmd)) { continue }
  $anyEditor = $true
  New-Item -ItemType Directory -Force -Path $userDir | Out-Null
  $file = Join-Path $userDir 'settings.json'
  $text = '{}'
  if (Test-Path -LiteralPath $file) {
    $text = [System.IO.File]::ReadAllText($file)
    Copy-Item -LiteralPath $file -Destination "$file.before-safety-setup" -Force
  }
  if (-not $text.Trim()) { $text = '{}' }
  $text = Set-EditorSetting $text 'task.allowAutomaticTasks' '"off"'
  $text = Set-EditorSetting $text 'security.workspace.trust.enabled' 'true'
  $text = Set-EditorSetting $text 'security.workspace.trust.untrustedFiles' '"prompt"'
  [System.IO.File]::WriteAllText($file, $text, $utf8NoBom)
  $changes.Add("$($ed.Name): tasks never run automatically; Workspace Trust on (settings: $file)")
}
if (-not $anyEditor) { $todo.Add('VS Code not found. Install it with: winget install --id Microsoft.VisualStudioCode -e   then run this script again') }

# ---------------------------------------------------------------- 4. Security tools
if (-not (Test-Cmd 'gitleaks')) { $todo.Add('Install gitleaks (secret scanner): winget install --id Gitleaks.Gitleaks -e   or download it from github.com/gitleaks/gitleaks/releases') }
if (-not (Test-Cmd 'snyk')) { $todo.Add('Install the Snyk CLI from the verified standalone download (Phase 4 runbook, step 4), then run: snyk auth') }
$todo.Add('In each CLIENT repo after cloning, point Snyk at the client''s organization: git config safety.snykOrg <client-org-name>')

# ---------------------------------------------------------------- Summary
Write-Host ''
Write-Host 'Changes made:' -ForegroundColor Green
foreach ($c in $changes) { Write-Host "  - $c" }
Write-Host ''
Write-Host 'Still to do:' -ForegroundColor Yellow
foreach ($t in $todo) { Write-Host "  - $t" }
Write-Host ''
Write-Host 'Next: run  powershell -ExecutionPolicy Bypass -File .\machine-check.ps1 -Mode Verify' -ForegroundColor Cyan
