# Phase 4B — Developer Machines: Deep Clean (only when allowed)

**Goal:** Every developer machine is clean, every account used on it has been secured from a clean machine, and every developer works with safe settings from now on. A developer gets repo access back only after this is done and checked.
**Who:** Each developer, on their own machine. The tech lead tracks progress in the cleared-developer tracker below. Kevin reviews the reports and verifies each machine before access is restored.
**Tools** (download all three from the incident Teams group into one folder, for example `Downloads\phase4`):

| File | What it does |
| --- | --- |
| `machine-check.ps1` | Checks the machine for signs of the worm. **Read-only**: it changes nothing. Saves a report to the Desktop. |
| `setup-dev-machine.ps1` | Applies the safe settings to Git, npm, VS Code and Cursor, installs the safety check that runs before every push, and tests that the check works. Safe to run again. |
| `pre-push` | The safety check itself. `setup-dev-machine.ps1` installs it; developers don't run it directly. |

All three work in the Windows PowerShell that comes with Windows; nothing extra is needed to run them.

---

## Which runbook do I follow?

There are two Phase 4 runbooks. Both end the same way (setup, Verify, account reset, fresh clones); they differ only in how the machine is cleaned.

| Situation | Runbook |
| --- | --- |
| Your account made **unauthorized** commits or force pushes (including ones you can't explain) | **4A Reset** (mandatory) |
| Your machine was the first one infected (patient zero) | **4A Reset** (mandatory) |
| `machine-check.ps1` shows **RED** | **4A Reset** (mandatory) |
| `machine-check.ps1` shows **AMBER** | Kevin reviews the report and decides |
| `machine-check.ps1` shows **GREEN** | **4A Reset preferred.** **4B Deep clean** only if the tech lead and Kevin agree a reset really isn't possible (for example, licensed software that can't be reinstalled) |

**A deep clean is more than a full Defender scan.** A scan only finds malware Defender already knows. The deep clean also deletes every repo copy, reinstalls the developer tools and removes saved credentials, and every route then ends with the account reset, which is what actually cuts the attacker off.

**Force pushes you did yourself:** the mandatory rule is for unauthorized ones. If you genuinely did a force push and the tech lead has checked what it changed, your triage result decides. When in doubt, reset: the worm makes its force pushes look like the developer's own.

## Time and window for this runbook

| Step | Time | Hands-on? |
| --- | --- | --- |
| 1. Triage check | 15 min | Yes |
| 3B.1–2. Save patches, delete every code folder | 30–45 min | Yes |
| 3B.3–5. Uninstall the tools, delete leftovers, remove saved sign-ins | 30–45 min | Yes |
| 3B.6. Startup items, reviewed with Kevin | 15–30 min | Yes, with Kevin |
| 3B.7. Browsers | 15 min | Yes |
| 3B.8. Defender Offline scan, then full scan | 1.5–2.5 h | No, runs by itself |
| 3B.9. Triage check again | 15 min | Yes |
| 4. Install the tools, including Snyk | 30–45 min | Yes |
| 5. Setup script | 10 min | Yes |
| 6. Verify (the full scan from 3B.8 counts if it finished today) | 15 min | Yes |
| 7. Secure the accounts | 1–1.5 h | Yes |
| 8. Fresh clones, `snyk test`, `npm ci` | 30–60 min | Yes |
| **Total** | **About 6–8 h**, of which about 4 h hands-on | |

**Recommended window:** one working day, started in the morning so Kevin is available for the startup-items review (3B.6) and the scans run over lunch. A deep clean can't be left running overnight like a reset, because most of it is hands-on.

## Rollout and windows (tech lead)

| When | Who | Window |
| --- | --- | --- |
| Today | **All developers:** "Before your turn" (triage + setup) | About 20 minutes each, no downtime |
| Today, right away | **One developer from each team** starts the full clean-up, so each team has a cleared developer and any team-specific problems show up early. Anyone RED, patient zero, and accounts that force-pushed also start today | One working day (for a reset, finished the next morning) |
| Before the weekend | Fix anything the first developers found; share the fixes with everyone | — |
| Weekend | **Everyone else**, on the agreed day, with no production work that day | One day |

Until the weekend, the rest of the developers keep working on production through reviewed pull requests, following "Before your turn".

---

## Why the order matters

The worm runs on developer machines. It steals what it finds there: GitHub sign-ins and tokens, `.env` files, passwords saved in the browser, and Discord and VS Code sessions. It then uses them to push in the developer's name.

So:
1. **Clean the machine first.** A password changed on an infected machine goes straight to the attacker.
2. **Then secure the accounts**, from the cleaned machine.
3. **Then restore access** and clone the cleaned repos fresh. Old copies of repos are never reused.

## Before your turn (everyone, today, about 20 minutes, no downtime)

One developer from each team is cleaned first and everyone else at the weekend, so production work can continue. Until your turn:
1. Run the **triage check** (step 1) and send the report to the tech lead. **RED: stop working on this machine now**; you go first in the queue.
2. Run **`setup-dev-machine.ps1`** (step 5). It switches off automatic VS Code tasks and npm install scripts and installs the push safety check, which blocks the worm's main ways of spreading while you keep working. You run it again after your clean-up.
3. On production repos, work only through pull requests. Reviewers reject changes to `.vscode/tasks.json`, config files with very long lines or code hidden after a run of spaces, new `.woff2` or `.bat` files, and anything nobody can explain.

## Stop-work rules (from the start of your turn until you are cleared)

- Don't open company or client repos in VS Code or Cursor, and don't run `npm install`, `npm run` or any build.
- Don't push, and don't sign in to GitHub, client systems or the VPN from this machine.
- Don't copy code folders to a USB drive, OneDrive or another machine.
- Company GitHub repos are protected on the server (Phase 2). **Client repos are not protected by us**, so these rules are what protects them.

---

## The flow

| Step | What | Who |
| --- | --- | --- |
| 1 | Triage check | Developer |
| 2 | Confirm this is the right runbook | Tech lead, with Kevin for AMBER |
| 3B | Supervised deep clean | Developer; tech lead follows along; Kevin reviews startup items |
| 4 | Install the tools from official sources | Developer |
| 5 | Run the setup script | Developer |
| 6 | Full Defender scan, then Verify check: must be GREEN | Developer; Kevin checks the report |
| 7 | Secure the accounts and change credentials, from this machine | Developer |
| 8 | Access restored; fresh clones of cleaned repos only | Kavitha (company repos), client DevOps (client repos), developer |

---

## Step 1 — Triage check

Every machine that has been used for company or client code needs this, home PCs and laptops included.

1. Open **Start**, type `PowerShell`, right-click **Windows PowerShell** and choose **Run as administrator**. (Without administrator rights the check still works, but it can't read Defender's detection history.)
2. Go to the folder with the files and run the check:
   ```powershell
   cd $env:USERPROFILE\Downloads\phase4
   powershell -ExecutionPolicy Bypass -File .\machine-check.ps1
   ```
   If you keep code outside your user folder (for example on drive D:), add those folders:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\machine-check.ps1 -ExtraPaths D:\projects,E:\work
   ```
3. Expected output (it takes a few minutes):
   ```
   Machine check v1.2 (Triage) - scanning, this can take a few minutes...

   RESULT: GREEN  (0 red, 0 amber)
   Nothing found. Reset is still preferred; a supervised deep clean is acceptable.

   Report: C:\Users\<you>\Desktop\machine-check-<PC>-Triage-<date-time>.txt
   SHA-256: <64 characters>
   ```
   A RED or AMBER result lists what it found under the result line.
4. **List your secret files** (file names only, not their contents). These secrets are treated as stolen and must be changed in step 7:
   ```powershell
   Get-ChildItem $env:USERPROFILE -Recurse -Force -File -Include '.env*','*.pem','*.key','*.pfx','credentials','*.ppk' -ErrorAction SilentlyContinue |
     Where-Object { $_.FullName -notmatch '\\node_modules\\' } | Select-Object -ExpandProperty FullName |
     Out-File "$env:USERPROFILE\Desktop\secret-files-$env:COMPUTERNAME.txt"
   ```
   Add `,D:\projects` after `$env:USERPROFILE` if you used `-ExtraPaths` above.
5. Send both files from the Desktop (the `machine-check-...txt` report and `secret-files-...txt`) to the tech lead in the Teams group. Send the files, not screenshots.
6. Tell the tech lead every **other** device where you signed in to GitHub or client systems in the last six months, such as a home PC or a second laptop. Each one goes through this phase too.

## Step 2 — Confirm a deep clean is allowed

Use this runbook **only** if all of these are true, and the tech lead has recorded Kevin's agreement in the Teams group:
- Triage is **GREEN** (or AMBER that Kevin has reviewed and allowed).
- Your account made **no** unauthorized commits or force pushes, and your machine isn't patient zero.
- A reset really isn't possible.

Otherwise, stop and use **Phase 4A Reset**.

**Saving uncommitted work as a patch** (used in 3B.1). For each repo with work that isn't on GitHub:
```powershell
cd C:\path\to\repo
git add -A
git diff --cached --binary --output="$env:USERPROFILE\Desktop\backup\<repo-name>-uncommitted.patch"
```
Create the `backup` folder on the Desktop first. Use `--output` as shown, not `>`, which saves the patch in a format `git apply` can't read. The tech lead reviews each patch before it's applied to a fresh clone in step 8. **Never copy the repo folders themselves.**

## Step 3B — Supervised deep clean

The tech lead follows along; Kevin checks the result in step 6. Do the steps in this order.

1. **Save uncommitted work as patches**, as in the box below.
2. **Delete every code folder** on the machine: every repo clone, copies in Downloads, and anything in OneDrive or other synced folders (and their online recycle bins). Then empty the Recycle Bin. The triage report lists the repo folders it found.
3. **Uninstall** (Settings → Apps → Installed apps): Visual Studio Code, Cursor, Discord, Node.js (and nvm, if installed) and Git.
4. **Delete the leftover folders.** In PowerShell (not administrator):
   ```powershell
   $leftovers = @(
     "$env:APPDATA\Code", "$env:USERPROFILE\.vscode", "$env:LOCALAPPDATA\Programs\Microsoft VS Code",
     "$env:APPDATA\Cursor", "$env:USERPROFILE\.cursor", "$env:LOCALAPPDATA\Programs\cursor",
     "$env:APPDATA\discord", "$env:LOCALAPPDATA\Discord",
     "$env:APPDATA\npm", "$env:LOCALAPPDATA\npm-cache", "$env:APPDATA\nvm", "$env:LOCALAPPDATA\Yarn", "$env:LOCALAPPDATA\pnpm",
     "$env:USERPROFILE\.npmrc", "$env:USERPROFILE\.git-credentials", "$env:USERPROFILE\.gitconfig", "$env:USERPROFILE\.node_repl_history")
   foreach ($p in $leftovers) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force; "Deleted $p" } }
   ```
   This also deletes your Git name and email setting; you set it again in step 5.

   Then, in **administrator** PowerShell, make sure Node.js's program folder is gone. PolinRider can replace npm's own program file there, and that change survives a reboot:
   ```powershell
   foreach ($p in @("$env:ProgramFiles\nodejs", "${env:ProgramFiles(x86)}\nodejs")) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force; "Deleted $p" } }
   ```
5. **Saved GitHub sign-ins.** Control Panel → Credential Manager → **Windows Credentials**: remove every entry that mentions `github`. (TortoiseGit or GitHub Desktop users: remove those entries too.)
6. **Things that start automatically.** Kevin goes through the triage report's startup items, scheduled tasks and Run entries with you and says which to remove (Task Manager → Startup apps; Task Scheduler). Don't remove items he hasn't confirmed: many are normal.
7. **Browsers.** Remove any extensions you don't recognise or don't need. Saved passwords are dealt with in step 7.
8. **Defender.** Windows Security → Virus & threat protection → Protection updates → **Check for updates**. Then go to **Scan options → Microsoft Defender Offline scan → Scan now**. The PC restarts and scans before Windows starts (about 15 minutes). After it restarts, go to **Scan options → Full scan → Scan now**.
9. Restart, then run the **triage check again** (step 1). It must show no RED. Any AMBER goes to Kevin.

**Write down the date the deep clean finished.** You need it in step 6.

## Step 4 — Install the tools (official sources only)

In a normal (not administrator) PowerShell window:

```powershell
winget install --id Git.Git -e --source winget
winget install --id OpenJS.NodeJS.LTS -e --source winget
winget install --id Microsoft.VisualStudioCode -e --source winget
winget install --id Gitleaks.Gitleaks -e --source winget
```

Cursor and Discord: install them only if you need them for work, and only from cursor.com and discord.com.

**Snyk CLI.** Snyk's npm package isn't used, because npm install scripts are switched off in step 5. Install the standalone program from Snyk's own download site and check it hasn't been altered:

```powershell
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$dir = "$env:LOCALAPPDATA\Programs\snyk"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
cd $dir
Invoke-WebRequest https://downloads.snyk.io/cli/stable/snyk-win.exe -OutFile snyk-win.exe -UseBasicParsing
Invoke-WebRequest https://downloads.snyk.io/cli/stable/sha256sums.txt.asc -OutFile sha256sums.txt.asc -UseBasicParsing
$line = Select-String -Path .\sha256sums.txt.asc -Pattern '^[0-9a-f]{64}\s+snyk-win\.exe\s*$' | Select-Object -First 1
$expected = ''; if ($line) { $expected = ($line.Line.Trim() -split '\s+')[0] }
$actual = (Get-FileHash .\snyk-win.exe -Algorithm SHA256).Hash.ToLower()
if ($expected -and $actual -eq $expected) { 'Checksum OK' } else { 'CHECKSUM MISMATCH: delete snyk-win.exe and tell Kevin' }
```

Only if it printed `Checksum OK`, finish the install:

```powershell
Move-Item .\snyk-win.exe .\snyk.exe -Force
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$dir*") { [Environment]::SetEnvironmentVariable('Path', "$userPath;$dir", 'User') }
```

The checksum file is signed by Snyk. For a stronger check, Kevin can also verify the signature in Git Bash: run `gpg --keyserver hkps://keys.openpgp.org --recv-keys 467717A30B2B4658415975629691DA64D0025194`, then `gpg --verify sha256sums.txt.asc`; it must say `Good signature from "Snyk Limited <code-signing@snyk.io>"` ([Snyk Docs](https://docs.snyk.io/developer-tools/snyk-cli/snyk-cli/install-the-snyk-cli/verifying-cli-standalone-binaries)).

**Close PowerShell and open a new window** so the new programs are found. Check them:

```powershell
git --version; node --version; gitleaks version; snyk --version
```

Each line shows a version number.

## Step 5 — Run the setup script

1. Set your Git name and email again (use the email linked to your GitHub account):
   ```powershell
   git config --global user.name "Your Name"
   git config --global user.email "you@example.com"
   ```
2. Run the setup from the Phase 4 folder:
   ```powershell
   cd $env:USERPROFILE\Downloads\phase4
   powershell -ExecutionPolicy Bypass -File .\setup-dev-machine.ps1
   ```
3. Expected output:
   ```
   Setting up safe defaults for this machine...

   Changes made:
     - Git: company safety check runs before every push (C:/Users/<you>/.git-safety/hooks/pre-push)
     - Git: safety check self-test PASSED (clean push allowed, worm sign blocked)
     - Git: pull uses merge, not rebase
     - Git: sign-in through Git Credential Manager
     - npm: packages cannot run install scripts automatically (npm run <script> still works)
     - VS Code: tasks never run automatically; Workspace Trust on (settings: C:\Users\<you>\AppData\Roaming\Code\User\settings.json)

   Still to do:
     - In each CLIENT repo after cloning, point Snyk at the client's organization: git config safety.snykOrg <client-org-name>

   Next: run  powershell -ExecutionPolicy Bypass -File .\machine-check.ps1 -Mode Verify
   ```
   If **Still to do** lists anything else (a missing tool, or `self-test FAILED`), fix it and run the setup again. Send a self-test failure to Kevin.

**What the setup changes:**

| Setting | Why |
| --- | --- |
| Safety check before every push | Blocks a push that contains the worm's signs (tasks that run when a folder is opened, code hidden in config files, the worm's `.bat` files, fake font files), secrets (gitleaks), or high-severity dependency problems when dependency files changed (Snyk) |
| Any other Git hooks folder removed | The worm can point Git at its own hooks |
| Git template and address-redirect settings removed | Both can be used to plant code in every new clone or send pushes elsewhere |
| Pull with merge, not rebase | Force pushes are blocked on GitHub, so a rebased branch can't be pushed |
| npm install scripts off | Most npm malware runs during `npm install`. `npm run dev`, `npm run build` and other scripts you start yourself still work |
| VS Code and Cursor: no automatic tasks, Workspace Trust on | The worm spreads through a task that runs as soon as a folder is opened |

## Step 6 — Full Defender scan, then the Verify check

1. If the full scan from step 3B.8 finished **today**, skip to item 2. Otherwise: Windows Security → Virus & threat protection → Scan options → **Full scan → Scan now**, and wait for it to finish.
2. In **administrator** PowerShell:
   ```powershell
   cd $env:USERPROFILE\Downloads\phase4
   powershell -ExecutionPolicy Bypass -File .\machine-check.ps1 -Mode Verify -CleanDate 2026-11-18
   ```
   **Always use `-CleanDate` with the date your deep clean finished** (the example shows 18 Nov 2026). Windows wasn't reinstalled, so the check can't work the date out itself.
3. Expected:
   ```
   RESULT: GREEN  (0 red, 0 amber)
   Clear. Send this report to the tech lead to be marked as cleared.
   ```
   - **AMBER:** fix the items listed (each one says what to do) and run the check again.
   - **RED:** stop. Don't sign in to anything. Send the report to Kevin.
4. Send the GREEN report to the tech lead. Kevin checks it (including that the SHA-256 shown on screen matches the file) and marks it in the tracker.

## Step 7 — Secure the accounts (from this cleaned machine only)

Start only after step 6 is GREEN. Treat every password, token and session that was on the old machine as stolen.

**7a. Email first** (the email account GitHub sends password resets to). Whoever controls it can take over GitHub.
- [ ] New unique password. Check two-step verification and the recovery phone and email.
- [ ] Sign out of all other sessions or devices.
- [ ] Check forwarding rules and filters: delete any you didn't create.

**7b. GitHub** (your own account used for company work). Settings, top-right avatar → **Settings**:
- [ ] **Password and authentication:** new unique password. Set up the authenticator app again (remove it, then add it with a fresh QR code) and **regenerate recovery codes**; store them offline. Remove any passkeys or security keys you don't recognise.
- [ ] **Sessions:** revoke every session except this one.
- [ ] **SSH and GPG keys:** delete **all** of them. Add a new key only if you need one, created on this machine. HTTPS through Git Credential Manager needs no key.
- [ ] **Developer settings → Personal access tokens** (both *Fine-grained* and *Tokens (classic)*): delete **all** of them.
- [ ] **Applications → Authorized OAuth Apps, Authorized GitHub Apps, Installed GitHub Apps:** revoke all. VS Code, GitHub CLI and Cursor ask again when you next sign in; approve only those you use.
- [ ] **Emails:** remove any email address you don't recognise.
- [ ] **Security log:** look back to when the incident started for anything you didn't do, especially new keys, tokens, app authorizations, two-factor changes or new repositories. Send screenshots of anything unknown to Kevin.
- [ ] **Your own repositories:** check for repos, commits or force pushes you didn't make. Tell Kevin before deleting anything.

**7c. Everything else that was used on the old machine.** Change the password, sign out other sessions, and revoke and recreate tokens:
- [ ] npm (also delete all access tokens; turn on two-factor), Docker Hub, cloud consoles (AWS, Azure, Google Cloud: delete access keys)
- [ ] Teams, Slack, Discord (changing the Discord password signs out the stolen session)
- [ ] Client systems, SSO and VPN: through client DevOps, via the tech lead and Kavitha
- [ ] Every password saved in the browser: change each one, then **delete the saved passwords from the browser** and keep them in a password manager instead
- [ ] **Project secrets** from your `secret-files` list (database passwords, API keys, cloud keys in `.env` files): give the list to the tech lead, who arranges the rotation with each service owner. Never paste secret values into Teams, email or AI tools.
- [ ] Personal: banking sign-ins saved in the browser, and any crypto wallet used on the old machine. This worm family steals wallets, so move funds to a new wallet created on a clean device.

**7d. Snyk sign-in.** Run `snyk auth` and sign in in the browser window that opens.

Tell the tech lead when 7a–7d are done.

## Step 8 — Access restored, fresh clones

**Who restores what:**
- **Company repos:** a repo reopens when it gets the permanent rules (Phase 2, step 5) after it's cleaned. Before that, Kavitha checks that **every** developer with write access to it is cleared. Anyone not yet cleared is temporarily removed from that repo (repo → Settings → Collaborators → Remove) and added back once cleared.
- **Client repos:** the tech lead sends the cleared list to Kavitha, who passes it to client DevOps. They restore access on the client side.

**Fresh clones, cleaned repos only.** Clone into a new folder such as `C:\code`. Never copy from a backup or another machine.

```powershell
mkdir C:\code -Force; cd C:\code
git clone https://github.com/<owner>/<repo>.git
cd <repo>
```

The first clone opens a browser window to sign in to GitHub (Git Credential Manager).

Before installing anything, check the dependencies:
- **Company repo:** `snyk test`
- **Client repo:** set the client's Snyk organization once per repo (client DevOps provides the name), then test:
  ```powershell
  git config safety.snykOrg <client-org-name>
  snyk test --org=<client-org-name>
  ```

Then install exactly what the lock file says: `npm ci`. With install scripts off, a few packages may not work straight away (for example ones that download a browser or compile code). If one fails, tell the tech lead. Once they approve that package, run its scripts for that one package only: `npm rebuild <package-name> --ignore-scripts=false`.

**Uncommitted work from step 3B:** once the tech lead has reviewed the patch, apply it to the fresh clone:

```powershell
git apply --check "$env:USERPROFILE\Desktop\backup\<repo-name>-uncommitted.patch"
git apply "$env:USERPROFILE\Desktop\backup\<repo-name>-uncommitted.patch"
```

When VS Code asks whether you trust the folder, trust only repos you cloned from company or client GitHub after the clean-up.

---

## Working safely from now on

- Changes go through pull requests. Force pushes are blocked permanently: use merge, not rebase + force push.
- **Never bypass the safety check with `--no-verify`.** If it blocks something you believe is fine, talk to the tech lead.
- Never open code from outside on this machine: "take-home tests" from recruiters, zip files, or repos from someone you don't know. Fake job interviews are a known way this kind of worm is spread.
- Don't switch npm install scripts back on, and don't turn VS Code automatic tasks back on.
- Install only the VS Code extensions you need, from well-known publishers.
- Report straight away in the Teams group: commits in your name you didn't make, VS Code offering to run a task you didn't start, a Defender alert, or GitHub sign-in emails you didn't expect.
- Keep Windows and Defender up to date.

---

## Cleared-developer tracker (tech lead)

| Developer | Machine | Triage result | Reset / deep clean | Verify GREEN (date) | Kevin checked | Accounts (7a–7b) | Other credentials (7c) | Company repo access | Client access requested |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| | | | | | | | | | |

A developer with more than one machine has one row per machine. A developer is **cleared** only when every machine they use is complete.

---

## Mac machines

Mac machines always follow **Phase 4A Reset** (Erase All Content and Settings).

---

## If something goes wrong

| Problem | What to do |
| --- | --- |
| "running scripts is disabled on this system" | Use the full command exactly as shown (`powershell -ExecutionPolicy Bypass -File ...`). If it is still refused, tell Kevin. |
| `winget` is not recognised | Install **App Installer** from the Microsoft Store, or download the installers from git-scm.com, nodejs.org, code.visualstudio.com and github.com/gitleaks/gitleaks/releases. |
| `CHECKSUM MISMATCH` when installing Snyk | Delete the file. Don't run it. Tell Kevin. |
| Setup says `self-test FAILED` | Don't push. Send the screen to Kevin. |
| A push says `BLOCKED` | Read the reason. Nothing was sent. If you believe it's a false alarm, talk to the tech lead. Never use `--no-verify`. |
| A push says `WARNING: gitleaks/Snyk could not run` | The push went through without that check. Run `snyk auth` again, check the organization name (`git config safety.snykOrg`), and reopen PowerShell after installing a tool. |
| Verify: "Repo folders older than the clean-up" | Delete those folders and clone fresh. Make sure you passed `-CleanDate` with the date the deep clean finished. |
| Verify: "No full Defender scan since the clean-up" | Run a full scan (step 6.1), then the check again. |
| Verify: "Repo sets its own hooks folder" | The repo (often through husky) switches off the company safety check. Tell the tech lead; in that repo run `git config --unset core.hooksPath`. |
| Verify: "can still run tasks automatically" or "npm install scripts are still allowed" | Run `setup-dev-machine.ps1` again (for example after installing VS Code or Node.js). |
| `npm ci` fails on a package that needs install scripts | Step 8: tech lead approves, then `npm rebuild <package-name> --ignore-scripts=false`. |

---

## Limits to know about

- **The safety check runs on the developer's machine, so it can be skipped** (`--no-verify`, or pushing with a stolen token). It catches mistakes and the common cases early. The **GitHub rulesets on the server (Phase 2) and pull-request review are the real protection.**
- The checks look for **this worm's known signs**. A new variant may look different. GREEN means "no known signs", which is why a reset is preferred.
- The machines have only Microsoft Defender, with no central monitoring. The deep clean, the account steps and the server rulesets make up for that, but a reset makes up for it better.
- Snyk Free has a monthly limit on tests. The safety check runs Snyk only when dependency files change, to stay within it.
- The scripts passed testing on simulated machines and were checked for compatibility with the PowerShell built into Windows, but the Windows-only checks (startup entries, scheduled tasks, Defender, Credential Manager) are first run for real in the pilot.

---

## Verification (Kevin, per developer)

| Check | How | Expected |
| --- | --- | --- |
| Machine clean | Verify report from step 6; SHA-256 matches what was on screen | `RESULT: GREEN`; report date after the reset or deep clean |
| Safety check working | Report line *Safety pre-push check* | `Self-test: PASS <date>` |
| Settings in place | Screen share: `git config --global --list` and `npm config get ignore-scripts` | `core.hookspath=.../.git-safety/hooks`, `pull.rebase=false`, no `url.` or `init.templatedir`; npm shows `true` |
| GitHub account | Screen share of Settings → Sessions, SSH and GPG keys, Personal access tokens, Applications | One session; only new keys; no old tokens; only apps the developer uses |
| Security log | Screen share | Nothing unexplained since the incident started |
| Credentials | Developer confirms 7a–7d; tech lead confirms project secrets are being rotated | All ticked |

## Sign-off

| | Name | Date |
| --- | --- | --- |
| Pilot machine complete | | |
| All developer machines cleared (tracker complete) | Tech lead | |
| Verified | Kevin | |
| Approved | Kavitha | |

---

## The files

Download the files from the incident Teams group rather than copying them from this document. They are included here for review.

### pre-push

```sh
#!/bin/sh
# company-safety-pre-push v1.2
# Runs before every git push (installed by setup-dev-machine.ps1). It blocks a push that contains:
#   - signs of the worm: VS Code tasks that run on folder open, code hidden in config files,
#     the worm's .bat spreader files, fake font files
#   - secrets such as tokens and passwords (gitleaks)
#   - high-severity dependency problems, when dependency files changed (Snyk)
# It is a safety net for developers. The GitHub rulesets on the server remain the real protection.

zero=0000000000000000000000000000000000000000
cfg_re='^(vite|next|postcss|tailwind|eslint|babel|webpack|nuxt|svelte|astro|vue|jest|vitest|rollup|tsup|remix|metro)\.config\.(js|cjs|mjs|ts|cts|mts)$|^gatsby-config\.(js|mjs|ts)$|^\.eslintrc\.(js|cjs)$'
deps_re='(^|/)(package\.json|package-lock\.json|npm-shrinkwrap\.json|yarn\.lock|pnpm-lock\.yaml|pom\.xml|build\.gradle(\.kts)?|requirements\.txt)$'

say() { printf '%s\n' "$*" >&2; }
input=$(cat)

printf '%s\n' "$input" | {
  rc=0; snyk_done=0
  # shellcheck disable=SC2034  # lref/rref are read but not needed
  while read -r lref lsha rref rsha; do
    [ -z "$lsha" ] && continue
    [ "$lsha" = "$zero" ] && continue                      # deleting a branch: nothing to check
    if [ "$rsha" != "$zero" ] && git cat-file -e "$rsha^{commit}" 2>/dev/null; then
      revs="$rsha..$lsha"                                  # existing branch: only the new commits
    else
      revs="$lsha --not --remotes"                         # new branch: commits not already on the server
    fi

    # Files added or changed in the commits being pushed, as they stand in the pushed version
    # shellcheck disable=SC2086  # $revs is deliberately split into git arguments
    files=$(git log --format= --name-only --diff-filter=ACMR $revs 2>/dev/null </dev/null | sort -u)
    tmp=$(printf '%s\n' "$files")
    printf '%s\n' "$tmp" | while IFS= read -r f; do
      [ -z "$f" ] && continue
      base=${f##*/}
      case "$f" in
        .vscode/tasks.json|*/.vscode/tasks.json)
          if git show "$lsha:$f" 2>/dev/null | grep -Eq '"runOn"[[:space:]]*:[[:space:]]*"folderOpen"'; then
            say "BLOCKED: $f runs a task automatically when the folder is opened (how the worm spreads)."; echo x
          elif git show "$lsha:$f" 2>/dev/null | grep -Eq 'node[^"]*\.woff2'; then
            say "BLOCKED: $f runs a font file as code (how the worm starts its payload)."; echo x
          fi ;;
      esac
      case "$base" in
        spellright.dict)
          if git show "$lsha:$f" 2>/dev/null | grep -Eq '[[:space:]]{150,}[^[:space:]]|require\(|eval\(|Function\(|child_process'; then
            say "BLOCKED: $f is a spell-check dictionary containing code (the worm hides a loader here)."; echo x
          fi ;;
      esac
      case "$base" in
        temp_auto_push.bat|temp_interactive_push.bat) say "BLOCKED: $f is a known worm spreader file."; echo x ;;
      esac
      case "$base" in
        *.js|*.cjs|*.mjs|*.ts|*.cts|*.mts|*.jsx|*.tsx|*.php|*.json|*.dict)
          # shellcheck disable=SC2016  # the markers are literal text, not variables
          if git show "$lsha:$f" 2>/dev/null | grep -Fq -e 'rmcej%otb%' -e 'Cot%3t=shtP' -e '_$_1e42' -e 'function MDy(' -e "global['!']" -e "global['_V']"; then
            say "BLOCKED: $f contains the PolinRider worm's code."; echo x
          fi ;;
      esac
      if printf '%s\n' "$base" | grep -Eq "$cfg_re"; then
        if git show "$lsha:$f" 2>/dev/null | grep -Eq '[[:space:]]{150,}[^[:space:]]'; then
          say "BLOCKED: $f has code hidden after a long run of spaces (how the worm hides its payload)."; echo x
        elif git show "$lsha:$f" 2>/dev/null | awk 'length > 1000 { found = 1 } END { exit !found }'; then
          say "BLOCKED: $f has a line over 1000 characters (likely hidden code)."; echo x
        fi
      fi
      case "$base" in
        *.woff2)
          magic=$(git show "$lsha:$f" 2>/dev/null | head -c 4)
          [ "$magic" = "wOF2" ] || { say "BLOCKED: $f is not a real font file (the worm hides code in fake fonts)."; echo x; } ;;
      esac
    done | grep -q x && rc=1

    # Secrets in the commits being pushed
    if command -v gitleaks >/dev/null 2>&1; then
      if gitleaks git --help >/dev/null 2>&1 </dev/null; then
        gitleaks git --log-opts="$revs" --redact --no-banner --exit-code 3 >&2 </dev/null; grc=$?
      else
        gitleaks detect --source . --log-opts="$revs" --redact --no-banner --exit-code 3 >&2 </dev/null; grc=$?
      fi
      case $grc in
        0) ;;
        3) say "BLOCKED: gitleaks found a secret in these commits. Remove it, and treat it as leaked: rotate it."; rc=1 ;;
        *) say "WARNING: gitleaks could not run (exit $grc). Tell the tech lead." ;;
      esac
    else
      say "WARNING: gitleaks is not installed, so secrets were not checked."
    fi

    # Dependencies changed: Snyk check (once per push)
    if [ $snyk_done -eq 0 ] && printf '%s\n' "$files" | grep -Eq "$deps_re"; then
      snyk_done=1
      if command -v snyk >/dev/null 2>&1; then
        org=$(git config --get safety.snykOrg)
        say "Dependency files changed: running Snyk${org:+ (organization $org)}..."
        if [ -n "$org" ]; then snyk test --all-projects --severity-threshold=high --org="$org" >&2 </dev/null; src=$?
        else snyk test --all-projects --severity-threshold=high >&2 </dev/null; src=$?; fi
        case $src in
          0) ;;
          1) say "BLOCKED: Snyk found high-severity problems in the dependencies (details above)."; rc=1 ;;
          3) ;;  # no supported project files
          *) say "WARNING: Snyk could not run (exit $src). Check 'snyk auth' and the organization." ;;
        esac
      else
        say "WARNING: Snyk is not installed, so dependencies were not checked."
      fi
    fi
  done
  exit $rc
}
status=$?

if [ $status -ne 0 ]; then
  say ""
  say "Push stopped by the company safety check. Nothing was sent."
  say "If you believe this is a false alarm, talk to the tech lead. Don't bypass it with --no-verify."
  exit 1
fi
exit 0
```

### setup-dev-machine.ps1

```powershell
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
```

### machine-check.ps1

```powershell
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
$Version = '1.2'
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
# PolinRider payload signatures (OpenSourceMalware): string markers, decoder names, injected globals (matched case-sensitively)
$sigRegex    = 'rmcej%otb%|Cot%3t=shtP|_\$_1e42|function MDy\(|global\[''!''\]|global\[''_V''\]'
$codeExt     = @('.js', '.cjs', '.mjs', '.ts', '.cts', '.mts', '.jsx', '.tsx', '.php')
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
        elseif ($t -match 'node[^"\r\n]*\.woff2') { Add-Finding 'RED' 'VS Code task that runs a font file as code' $p }
        continue
      }
      if ($lname -match $configRegex) {
        $fi = New-Object System.IO.FileInfo($p)
        if ($fi.Length -gt 5MB) { Add-Finding 'AMBER' 'Unusually large config file' $p; continue }
        $t = [System.IO.File]::ReadAllText($p)
        if ($t -cmatch $sigRegex) { Add-Finding 'RED' 'Config file containing the PolinRider payload' $p; continue }
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
      $ext = [System.IO.Path]::GetExtension($lname)
      if ($codeExt -contains $ext) {
        $fi = New-Object System.IO.FileInfo($p)
        if ($fi.Length -le 5MB -and ([System.IO.File]::ReadAllText($p) -cmatch $sigRegex)) { Add-Finding 'RED' 'Code file containing the PolinRider payload' $p }
        continue
      }
      if ($lname -eq 'spellright.dict') {
        $t = [System.IO.File]::ReadAllText($p)
        if ($t -match '[ \t]{150,}\S|require\(|eval\(|Function\(|child_process') { Add-Finding 'RED' 'Spell-check dictionary containing code (PolinRider hides a loader here)' $p }
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

# npm's own program file: PolinRider replaces npm\lib\cli.js (normally under 1 KB) with about 1 MB of code, and it survives a reboot
$npmCli = New-Object System.Collections.Generic.List[string]
foreach ($b in @((Get-EnvPath 'ProgramFiles' 'nodejs'), (Get-EnvPath 'ProgramFiles(x86)' 'nodejs'), (Get-EnvPath 'APPDATA' 'npm'), (Get-EnvPath 'LOCALAPPDATA' 'Programs\nodejs'))) {
  if ($b) { $npmCli.Add((Join-Path $b 'node_modules\npm\lib\cli.js')) }
}
foreach ($nv in @((Get-EnvPath 'APPDATA' 'nvm'), (Get-EnvPath 'NVM_HOME' ''))) {
  if ($nv -and (Test-Path -LiteralPath $nv)) {
    Get-ChildItem -LiteralPath $nv -Directory -ErrorAction SilentlyContinue | ForEach-Object { $npmCli.Add((Join-Path $_.FullName 'node_modules\npm\lib\cli.js')) }
  }
}
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue | Select-Object -First 1
if ($npmCmd -and $npmCmd.Source) { $npmCli.Add((Join-Path (Split-Path $npmCmd.Source -Parent) 'node_modules\npm\lib\cli.js')) }
foreach ($f in @($npmCli | Select-Object -Unique)) {
  try {
    if (-not (Test-Path -LiteralPath $f)) { continue }
    $len = (Get-Item -LiteralPath $f).Length
    $t = [System.IO.File]::ReadAllText($f)
    if ($len -gt 20KB -or $t -match '[ \t]{150,}\S') { Add-Finding 'RED' "npm's own program file has been replaced (PolinRider hides code here)" "$f ($len bytes; normally under 1 KB)" }
    else { Add-Finding 'INFO' 'npm program file' "$f looks normal ($len bytes)" }
  } catch { $unreadable++ }
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
```
