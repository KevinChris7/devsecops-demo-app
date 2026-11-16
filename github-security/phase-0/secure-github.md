# Phase 1 — Secure the GitHub Owner Account

**Goal:** The GitHub Pro account that owns all 300 Hexalytics repos is clean, locked down and controlled through a new, dedicated admin mailbox. If an attacker holds this account, they can undo every other control, so this phase comes first.
**Owner-account holder:** Kavitha. Kevin is available on call if needed and runs the verification checks.
**Working device:** A clean EC2 instance provided by the team (section 0).
**Go-ahead:** Confirmation received from Kavitha.

| Section | What |
| --- | --- |
| 0 | Set up the clean EC2 working device |
| 1a | Owner-account email changeover: remove Ganesh's email, add the new admin mailbox as primary |
| 1b | Secure the owner account and Kavitha's Git credentials |
| 1c | Privilege control: who can do what with the owner account |

**Before you start (all must be ticked)**
- [ ] Clean EC2 instance ready (section 0).
- [ ] The computer Kavitha connects from is confirmed clean: checked by IT, freshly reimaged, or a new machine. Malware on that computer can see and type into the EC2 session, so this gate can't be skipped.
- [ ] Company password vault available (for example Bitwarden, 1Password or Keeper business), with MFA on, and an owner-account entry visible only to Kavitha and the backup person.
- [ ] Backup person named; both have a company-controlled phone with an authenticator app (section 1c).
- [ ] Kavitha's work mailbox secured: new password, MFA on (not SMS), other sessions signed out, forwarding rules checked. It becomes the account's reset address for a few days.
- [ ] Evidence folder agreed (see rules below).

**Order**
1. **Sitting 1, in one go (about 45 minutes):** export the security log first (1b.5 step 1) → 1b.1 password and 2FA → 1b.2 sessions → 1a step 2 (Ganesh's email out) → 1b.3 keys, tokens and apps. Locking the account first cuts off anyone holding a live session or token before they can react.
2. **Same day:** the repo freeze from Phase 2, at least on active repos. Until it's on, compromised developer accounts can still push and force-push.
3. **Next:** 1b.4 to 1b.8, then 1c. Do 1b.6 and 1b.8 as early as possible: even with the repo freeze on, every collaborator can still **read and clone** the code, so leavers and unknown accounts should go the same day if Kavitha can approve the list.
4. **When the admin mailbox is ready:** 1a steps 3 to 5.

**Rules for this phase**
- **Screenshot first, delete second.** Every list you clean up is evidence.
- **Keep evidence off the laptops.** Save screenshots and exports in one folder on the EC2 instance, record a SHA-256 hash of each file (`Get-FileHash <file>` in PowerShell), and copy the folder daily to a restricted company location (for example a SharePoint folder or an S3 bucket with versioning) that only Kavitha, the backup person and Kevin can open.
- **If something can't be explained, stop and call Kevin.** For example: a login from an unknown place, 2FA turned off, a key or collaborator nobody added.
- **Use the incident Teams group** for updates, not email or other chats. Keep the group to the people working on this, and make sure each member has MFA on their Microsoft account.
- Record every action in the evidence log at the end.

---

## 0 — Clean EC2 working device

All owner-account work happens inside this instance, never on a developer laptop.

**Team sets up the instance**
- [ ] Launch from an official, current AWS AMI (Windows Server 2022/2025 if Kavitha prefers Windows), fully patched.
- [ ] **Check the AWS account first.** If AWS keys for this account were on any developer machine, rotate them before launching (see 1b.7). An attacker with those keys could reach the instance.
- [ ] No inbound ports open to the internet. Use **AWS Systems Manager Fleet Manager / Session Manager**, or allow RDP only from Kavitha's current public IP (/32).
- [ ] IMDSv2 required, encrypted disk, no IAM role except what Session Manager needs.
- [ ] Local admin password unique, stored in the company password vault.
- [ ] Only these installed, from official sites: a browser (Edge or Chrome), Git for Windows, GitHub CLI (`gh`). **No VS Code, Node.js, npm or TortoiseGit.**
- [ ] Browser: **don't sign in to browser sync** (Edge or Chrome profile), turn off password saving, and clear browsing data at the end of each session. Synced or saved logins would leave the instance.
- [ ] Windows Defender on and updated; screen locks after 5 minutes idle; RDP uses Network Level Authentication.
- [ ] In the RDP client, **turn off drive and clipboard redirection**, so files can't pass between Kavitha's laptop and the instance. Because copy-paste from the laptop is off, open this runbook **inside the EC2 browser** (from the incident Teams group or SharePoint) to copy commands.
- [ ] Record who in the team has AWS permission to access or snapshot this instance (section 1c).
- [ ] At the end of every session: run `gh auth logout`, sign out of GitHub and the mailbox in the browser, then stop the instance. Terminate it when the engagement ends.

**Kavitha's side**
- The EC2 instance is only as safe as the computer used to connect to it. Malware on that computer can capture what she types.
- Connect from a machine that has **not** run the company's repos with npm or VS Code. If her laptop is in doubt, it gets reimaged first, or she uses another clean machine.
- 2FA in this phase uses an **authenticator app on company-controlled phones**.
- **Recommended upgrade:** two FIDO2 security keys (one for Kavitha, one sealed with the backup person). Unlike authenticator codes, they can't be phished or copied. Before relying on them, test once whether the RDP client passes a USB key through to the EC2 browser.

**Done when:** instance running with only the listed software, access path agreed, AWS access holders recorded.

---

## 1a — Owner-account email changeover

**Current state:** Ganesh's email is **primary**; Kavitha's email is **secondary**. Ganesh has left the company.
**Target state:** the new, dedicated admin mailbox is **primary** and is the **only** address that can reset the password. Ganesh's email is gone. Kavitha's email stays as a secondary address (step 5).

### Step 1 — Impact check before removing Ganesh's email

| Area | What changes when Ganesh's email is removed | Action before removing |
| --- | --- | --- |
| Signing in | Nothing. Sign-in uses the username and password. Signing in *with that email address* stops working | None |
| Password reset | Ganesh's inbox can no longer reset the password. **This is the point**, especially now that he has left | None |
| Notifications | GitHub stops emailing Ganesh's address | Settings → Notifications: set the default notification email to Kavitha's address (later the admin mailbox) |
| Past commits | Commits authored with Ganesh's email no longer link to this account's profile picture. Code and history don't change | None |
| Verified signatures | Commits already shown as "Verified" keep that status | None |
| Billing | Pro receipts and billing notices may go to the primary email | Settings → Billing and licensing: check the payment method and billing contact; note whose card pays. If it's Ganesh's card, arrange a company card |
| Tools using "Sign in with GitHub" (Snyk, hosting platforms) | Sign-in keeps working; some tools store the email as a contact | Note any tool where Ganesh's email is the contact; update later |
| Ganesh's existing access | **Not removed by deleting the email.** Any session, token, SSH key or knowledge of the password still works until 1b | 1b removes them in the same sitting |
| 2FA | 2FA isn't tied to email. If the authenticator app for 2FA was ever set up on Ganesh's phone, that phone can still produce codes | Reset 2FA in 1b.1 so only company phones hold it |
| Ganesh's mailbox | If IT has kept his mailbox active or forwarded it to someone, that person currently receives GitHub reset emails | Ask IT what happened to his mailbox; removing the address closes this either way |
| Ganesh's laptop and phone | If they weren't returned and wiped, they may still hold owner-account sessions, saved credentials or 2FA codes | Ask IT to confirm both were returned and wiped. Until then, assume they hold access; 1b.1 to 1b.3 cut it off |

### Step 2 — Remove Ganesh's email today (Kavitha's email becomes primary for now)

GitHub won't delete the primary address, so swap first.

1. Confirm Kavitha's work mailbox is secured ("Before you start").
2. You're already signed in to the owner account on the EC2 instance, with the password and 2FA reset (1b.1) and other sessions revoked (1b.2).
3. **Settings → Emails:**
   - Screenshot the email list (evidence).
   - Under **Primary email address**, choose Kavitha's email and save.
   - Next to Ganesh's email, click the **delete** icon. Confirm with the password or 2FA prompt.
4. On the same page:
   - Turn on **Keep my email addresses private**. Web commits then use the GitHub no-reply address, which never changes with the primary email.
   - Turn on **Block command line pushes that expose my email**.
   - Under **Backup email address**, choose **Only allow primary email** and click **Save**. If the dropdown lists only addresses, pick the primary address itself. GitHub uses the backup address for security notifications and for password resets when the primary inbox can't be reached, so it must not be any other address.
5. **Settings → Notifications:** confirm the default notification email is Kavitha's address.
6. Carry on with 1b.3 in the same sitting.

**Rollback:** if something breaks, an address can be added back and re-verified under Settings → Emails. Nothing else is lost.

### Step 3 — Create and harden the admin mailbox (team)

This mailbox controls the GitHub owner account, so it gets the strongest settings in the company.

- [ ] A **dedicated mailbox** with its own login, for example `github-admin@<company domain>`. **Not** a distribution list or group: everyone in a group could reset the GitHub password.
- [ ] Long, unique password stored in the company vault, visible only to Kavitha and one named backup person (section 1c).
- [ ] **MFA with an authenticator app** on a company-controlled phone (security keys later if bought). No SMS.
- [ ] Recovery email and phone set to **company-controlled** ones, not anyone's personal number.
- [ ] Turn off IMAP, POP and app passwords (legacy sign-in). Block automatic forwarding to outside addresses.
- [ ] Turn on sign-in alerts and mailbox audit logging. If the platform supports it (Microsoft Entra Conditional Access or Google context-aware access), allow sign-in only from the company network or the EC2 instance.
- [ ] Use it **only** for GitHub. No newsletters, no other sign-ups.
- [ ] The mail platform's own admins can reset this mailbox's password. Confirm their accounts have MFA too.

### Step 4 — Make the admin mailbox primary (no downtime)

1. In the owner account: **Settings → Emails → Add email address** → enter the admin mailbox → **Add**.
2. Open the admin mailbox (from the EC2 instance) and click GitHub's verification link.
3. Back in **Settings → Emails**, set the admin mailbox as **Primary** and save.
4. Confirm **Backup email address = Only allow primary email**.
5. **Settings → Notifications:** set the default notification email to the admin mailbox.
6. **Test:** confirm it shows "Primary" and "Verified", and that a GitHub notification arrives in the admin mailbox.
7. Update billing contacts and any tools noted in step 1.

Nothing stops working during this switch. Signing in, repos, rulesets and collaborators don't depend on the email address.

### Step 5 — Keep Kavitha's email as a secondary address

Kavitha's email stays on the owner account as a secondary address, on these conditions:

- **Backup email address stays "Only allow primary email".** Her inbox then can't be used to reset the owner-account password; only the admin mailbox can.
- **Her own GitHub account uses a different email.** A GitHub email can be verified on only one account. While her work email sits on the owner account, any commit she makes with that email shows up as the **owner account**, not her. So in her own account, and in her Git settings (TortoiseGit → Settings → Git → Email), she uses her own account's GitHub no-reply address (`<id>+<username>@users.noreply.github.com`, shown under her account's Settings → Emails).
- **Her mailbox keeps MFA on**, since it still receives owner-account notifications.

If either condition becomes a problem later, remove her email from the owner account at the final handover.

**Done when:** Ganesh's email removed; admin mailbox primary and verified; backup email set to primary only; notifications and billing pointing to the admin mailbox; Kavitha's Git uses her own account's no-reply email.

---

## 1b — Secure the owner account and Kavitha's credentials

All steps from the EC2 instance, in the order given at the top: 1b.1 and 1b.2 come first, before the email change.

### 1b.1 — Password and 2FA

1. **Settings → Password and authentication → Change password.** New, unique, 16+ characters, saved in the company vault (section 1c says who can see it).
2. **Two-factor authentication:**
   - Find out **which phones currently hold the authenticator code**. If any phone is personal, Ganesh's, or unknown, reset it now.
   - **Reconfigure the authenticator app.** GitHub shows a new QR code and the old codes stop working. Scan it on Kavitha's **company-controlled** phone. To give the backup person access (section 1c), scan the **same QR code** on their company phone at the same time, and record it.
   - **Remove SMS** as a 2FA method if it's set up.
   - On the same page, check **Passkeys**, **Security keys** and **GitHub Mobile** devices. Remove any that weren't added today by Kavitha. An attacker can add their own passkey or mobile device to sign in later without the password.
   - **On both phones:** screen lock on, OS updated, and the authenticator's cloud backup either tied to a **company** account or switched off. For example, Google Authenticator syncs codes to whatever Google account the app is signed in to; if that's a personal account, the codes leave company control.
3. **Regenerate recovery codes.** The old ones stop working. Store them in the company vault, plus one printed copy in a sealed envelope in the office safe, never on a laptop.

> Changing the password does **not** revoke tokens, SSH keys or app access. That's 1b.3.

### 1b.2 — Sign out every other session

1. **Settings → Sessions.** Screenshot the list.
2. **Revoke** every session except the current EC2 browser session, including GitHub Mobile sessions on phones that aren't company-controlled.

### 1b.3 — Remove keys, tokens and app access

Screenshot each page **before** changing it. Default: **remove everything**, then re-add only what's needed, from the EC2 instance.

**Impact check first, so nothing breaks by surprise:** before revoking, note which apps on these pages are used by live systems, for example a hosting platform that deploys from GitHub, Snyk, or a project-management integration. Revoking them stops those integrations until someone re-authorizes them. Agree with Kavitha which ones to re-authorize straight afterwards, from the EC2 instance, and list them in the evidence log. During an active compromise, a short break in an integration is acceptable; an unknown integration left connected is not.

| # | Where (Settings → …) | What to do |
| --- | --- | --- |
| 1 | **SSH and GPG keys** → Authentication keys | Delete all. These include any PuTTY key used by TortoiseGit |
| 2 | **SSH and GPG keys** → Signing keys, GPG keys | Delete all. An unknown signing key is a red flag: tell Kevin first |
| 3 | **Developer settings → Personal access tokens** (fine-grained and classic) | Delete all |
| 4 | **Applications → Authorized OAuth Apps** | Revoke all, including **Git Credential Manager**, GitHub CLI, VS Code and GitHub Desktop |
| 5 | **Applications → Authorized GitHub Apps** | Revoke all not actively needed |
| 6 | **Applications → Installed GitHub Apps** | Check which repos each can reach; uninstall unknown or unused |
| 7 | **Developer settings → OAuth Apps / GitHub Apps** owned by this account | Should be empty or known. An unknown app is a red flag |
| 8 | **Codespaces** (Settings → Codespaces for secrets; github.com/codespaces for running codespaces) | Delete running codespaces and unknown Codespaces secrets |

The script in 1b.6 signs in with `gh auth login`, which adds a fresh **GitHub CLI** entry under Authorized OAuth Apps. That one is expected; `gh auth logout` at the end of each session removes the stored token from the instance. If any other token is needed later, create a **fine-grained** token on the EC2 instance, scoped to the needed repos, expiring in 30 days or less, and record it.

### 1b.4 — Clean up TortoiseGit credentials on Kavitha's laptop

Kavitha uses TortoiseGit, with credentials saved in **Windows Credential Manager**. If those belong to the owner account, every Git operation on her laptop runs with full owner rights, and any malware on that laptop can read them.

**On Kavitha's laptop, after 1b.3** (the GitHub side is already revoked):

1. **List what's stored** (Command Prompt):
   ```bat
   cmdkey /list | findstr /i github
   ```
   Note each entry's **Target** and **User**: this shows which GitHub account it belongs to, the owner account or Kavitha's own. Record it in the evidence log. Never copy the secret itself. Remove the entries for **both** accounts: her own account's credentials were also on a possibly exposed laptop.
2. **Delete the GitHub entries.** Either open **Control Panel → Credential Manager → Windows Credentials** and remove each `git:https://github.com…` entry, or run:
   ```bat
   cmdkey /delete:git:https://github.com
   ```
   `cmdkey /list` shows targets as `LegacyGeneric:target=git:https://github.com`. Use the part after `target=` in the delete command. Repeat for any other GitHub target it showed, for example `git:https://kavitha@github.com`, then run `cmdkey /list | findstr /i github` again: it should print nothing.
3. **Check other places Git can keep credentials or code:**
   - `%USERPROFILE%\.git-credentials`: a plain-text password file. If it exists, note which account, then delete it.
   - `git config --global --list`: note `credential.helper`, and look for `core.hookspath` or `url.<...>.insteadof` entries nobody set. Report those to Kevin.
   - **TortoiseGit → Settings → Hook Scripts:** should be empty unless someone set them deliberately.
   - **PuTTY / Pageant keys** (`.ppk` files) used by TortoiseGit: if one was on the owner account, it was deleted from GitHub in 1b.3. Remove it from Pageant and delete the file once noted.
4. **Secure Kavitha's own GitHub account too**, from the EC2 instance, with the same steps as 1b.1 to 1b.3: new password, authenticator app on her company phone, sessions revoked, all SSH keys, tokens and app authorizations removed.
5. **From now on, Kavitha's TortoiseGit uses her own GitHub account, never the owner account** (section 1c). Set it up again only after her laptop is confirmed clean, with her own account's no-reply email (1a step 5). When Git Credential Manager next asks, sign in with her own account in the browser.

**Done when:** no owner-account credentials on any laptop, and TortoiseGit is signed in only with Kavitha's own account, or not set up yet.

### 1b.5 — Review the security log

1. **Settings → Security log** (under "Archives") → **Export** (CSV or JSON). Save with the evidence.
2. GitHub keeps only the **last 90 days** in this log, so export it in sitting 1, before anything ages out. Review the whole 90 days:

| Look for | Why it matters |
| --- | --- |
| Logins or sessions from unknown places or IPs | Direct use by the attacker |
| 2FA disabled or changed, recovery codes viewed | Account takeover |
| Password changed or email added that Kavitha didn't do | Takeover or a reset route |
| New SSH, signing or GPG key | Persistent push access; signing commits as the owner |
| Token created, OAuth app or GitHub App authorized | Persistent API access |
| Collaborator added or invitation sent | Attacker giving their own account access |
| Repo created, deleted, transferred or made public | Data theft or destruction |

3. Record every unexplained entry in the findings table. Ganesh has left, so treat any activity Kavitha can't explain as suspicious, including activity from his time.

### 1b.6 — Deploy keys, webhooks, collaborators, invitations and rulesets on every repo

The script `repo-inventory.sh` lists all of these for every repo. It only reads; it changes nothing on GitHub.

**What it checks before running:** that the GitHub CLI is signed in, and that it's signed in as the **owner account**, not Kavitha's own account. If either is wrong, it stops with a message.

**How to run it (Git Bash on the EC2 instance):**

1. Inside the EC2 browser, download the three scripts from the incident Teams group into one folder: `repo-inventory.sh`, `collaborator-report.sh` and `remove-collaborators.sh`. Clipboard and drive sharing are off, so don't copy them from the laptop.
2. Open **Git Bash** and go to the download folder, for example `cd ~/Downloads`.
3. Sign in to the GitHub CLI as the owner account (the browser opens for approval):
   ```bash
   gh auth login
   ```
   Choose GitHub.com, HTTPS, and "Login with a web browser".
4. Run the script with the owner account's username:
   ```bash
   bash repo-inventory.sh <owner-account-name>
   ```
   It shows progress (`[12/300] repo-name`), then a summary of write-access deploy keys, webhook destinations, collaborators and pending invitations. For 300 repos expect roughly 15–30 minutes. It retries brief GitHub errors and pauses by itself if GitHub's hourly limit is close. If the RDP connection drops, **disconnect rather than sign out** of Windows, so the script keeps running.
5. When finished, run `gh auth logout`.

**What it produces** (in a new folder named `repo-inventory-<date>-<time>`):

| File | Contents |
| --- | --- |
| `repos.tsv` | Every repo: archived or not, fork or not, visibility, last push date (most recent first) |
| `repos.txt` | The repo names alone, used by the other scripts |
| `deploy_keys.tsv` | Deploy keys: repo, id, title, read-only or not, created date |
| `webhooks.tsv` | Webhooks: repo, id, destination URL, events, active, created date |
| `collaborators.tsv` | Who has access to each repo and with what permission. Also the backup of who had access, needed to restore people later, and the input for section 1c |
| `invitations.tsv` | Pending invitations, including email-only invitations |
| `rulesets.tsv` | Existing rulesets, as a baseline before the repo freeze |
| `errors.txt` | Any lookup that still failed after retries. If it's empty, everything was read. If not, run the script again |
| `SHA256SUMS.txt` | Hashes of all the files above, for the evidence record |

Copy the whole folder to the evidence location. The `.tsv` files open in Excel.

<details>
<summary>Full script (for review)</summary>

```bash
#!/usr/bin/env bash
# Repo inventory for the GitHub owner account.
# Lists deploy keys, webhooks, collaborators, pending invitations and rulesets on every repo.
# Read-only: it changes nothing on GitHub.
#
# Usage (Git Bash on the clean EC2 instance):
#   gh auth login                                  # once, signed in as the OWNER account
#   bash repo-inventory.sh <owner-account-name>

set -u

OWNER="${1:-}"
if [ -z "$OWNER" ]; then
  echo "Usage: bash repo-inventory.sh <owner-account-name>"
  exit 1
fi

# Must be signed in, and signed in as the owner account (not Kavitha's own account)
if ! gh auth status >/dev/null 2>&1 </dev/null; then
  echo "Not signed in to GitHub CLI. Run: gh auth login"
  exit 1
fi
ME=$(gh api user -q .login 2>/dev/null </dev/null) || { echo "Could not read the signed-in account."; exit 1; }
if [ "$(printf '%s' "$ME" | tr '[:upper:]' '[:lower:]')" != "$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')" ]; then
  echo "Signed in as '$ME', not '$OWNER'. Run 'gh auth login' as the owner account, then try again."
  exit 1
fi

OUT="repo-inventory-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$OUT" && cd "$OUT" || exit 1
TMPD=$(mktemp -d) || exit 1
trap 'rm -rf "$TMPD"' EXIT

# ---- GitHub API helpers ------------------------------------------------------
CALLS=0
GHQ_ERR=""
# Pause when the hourly API limit is nearly used up (checked every 50 calls).
ratecheck() {
  CALLS=$((CALLS + 1))
  [ $((CALLS % 50)) -ne 0 ] && return 0
  local rem reset now pause
  rem=$(gh api rate_limit -q .resources.core.remaining 2>/dev/null </dev/null) || return 0
  [ "${rem:-5000}" -ge 200 ] 2>/dev/null && return 0
  reset=$(gh api rate_limit -q .resources.core.reset 2>/dev/null </dev/null)
  now=$(date +%s); pause=$(( ${reset:-$now} - now + 5 )); [ "$pause" -lt 5 ] && pause=5
  echo "GitHub API hourly limit nearly used up; pausing about $(( (pause + 59) / 60 )) min..." >&2
  sleep "$pause"
}
# ghq <outfile> <gh api args...>: one API call, output to <outfile>.
# Retries after rate limits and server/network errors; not after "not found"-type answers.
ghq() {
  local of=$1 rc=1 attempt; shift
  for attempt in 1 2 3; do
    ratecheck
    gh api "$@" > "$of" 2> "$TMPD/err" </dev/null; rc=$?
    GHQ_ERR=$(tr '\n\t' '  ' < "$TMPD/err")
    [ $rc -eq 0 ] && return 0
    case "$GHQ_ERR" in
      *"rate limit"*|*"HTTP 429"*) echo "GitHub rate limit hit; waiting 60 s..." >&2; sleep 60 ;;
      *"HTTP 50"*|*[Tt]imeout*|*connection*|*EOF*|*TLS*) sleep 5 ;;
      *) return $rc ;;
    esac
  done
  return $rc
}

# ---- Repository list (most recently pushed first) ---------------------------
if ! ghq "$TMPD/repos" "user/repos?affiliation=owner&per_page=100" --paginate \
     -q '.[] | [.name, (.archived|tostring), (.fork|tostring), .visibility, (.pushed_at // "")] | @tsv'; then
  echo "Could not list repositories for '$OWNER': $GHQ_ERR"
  exit 1
fi
printf 'repo\tarchived\tfork\tvisibility\tlast_push\n' > repos.tsv
sort -t$'\t' -k5,5r "$TMPD/repos" >> repos.tsv
awk -F'\t' 'NR>1 {print $1}' repos.tsv > repos.txt
TOTAL=$(grep -c . repos.txt)
[ "$TOTAL" -eq 0 ] && { echo "No repositories found for '$OWNER'."; exit 1; }
echo "Repositories found: $TOTAL ($(awk -F'\t' 'NR>1 && $2=="true"' repos.tsv | wc -l | tr -d ' ') archived)"

# ---- Pre-flight: can this sign-in read webhooks? -----------------------------
first=$(head -1 repos.txt)
if ! ghq "$TMPD/x" "repos/$OWNER/$first/hooks?per_page=1"; then
  case "$GHQ_ERR" in
    *404*|*403*|*"not accessible"*)
      echo "This sign-in can't read webhooks. Run:  gh auth refresh -s admin:repo_hook   then run this script again."
      exit 1 ;;
  esac
fi

printf 'repo\tkey_id\ttitle\tread_only\tcreated_at\n'                > deploy_keys.tsv
printf 'repo\thook_id\turl\tevents\tactive\tcreated_at\n'            > webhooks.tsv
printf 'repo\tlogin\tpermission\n'                                   > collaborators.tsv
printf 'repo\tinvite_id\tinvitee\tpermission\tcreated_at\texpired\n' > invitations.tsv
printf 'repo\truleset_id\tname\ttarget\tenforcement\n'               > rulesets.tsv
: > errors.txt

# fetch <repo> <endpoint> <jq-filter> <output-file>
# Appends results only when the whole call (all pages) succeeded; otherwise records it in errors.txt.
fetch() {
  if ghq "$TMPD/out" "repos/$OWNER/$1/$2" --paginate -q "$3"; then
    cat "$TMPD/out" >> "$4"
  else
    printf 'FAILED\t%s\t%s\t%s\n' "$1" "${2%%\?*}" "$GHQ_ERR" >> errors.txt
  fi
}

n=0
while IFS= read -r r <&3; do
  r=${r%$'\r'}
  [ -z "$r" ] && continue
  n=$((n + 1))
  fetch "$r" "keys?per_page=100"          "(.[] | [\"$r\", .id, .title, (.read_only|tostring), .created_at] | @tsv)"                                  deploy_keys.tsv
  fetch "$r" "hooks?per_page=100"         "(.[] | [\"$r\", .id, (.config.url // \"\"), (.events|join(\",\")), (.active|tostring), .created_at] | @tsv)" webhooks.tsv
  fetch "$r" "collaborators?per_page=100" "(.[] | [\"$r\", .login, .role_name] | @tsv)"                                                            collaborators.tsv
  fetch "$r" "invitations?per_page=100"   "(.[] | [\"$r\", .id, (.invitee.login // \"(email invite)\"), .permissions, .created_at, (.expired|tostring)] | @tsv)" invitations.tsv
  fetch "$r" "rulesets?per_page=100"      "(.[] | [\"$r\", .id, .name, .target, .enforcement] | @tsv)"                                              rulesets.tsv
  echo "[$n/$TOTAL] $r"
done 3< repos.txt

rows() { echo $(( $(wc -l < "$1") - 1 )); }
nfail=$(grep -c '^FAILED' errors.txt)

echo
echo "================ SUMMARY ================"
echo "Repositories processed: $n of $TOTAL"
echo "Deploy keys:            $(rows deploy_keys.tsv)"
echo "Webhooks:               $(rows webhooks.tsv)"
echo "Collaborator entries:   $(rows collaborators.tsv)"
echo "Pending invitations:    $(rows invitations.tsv)"
echo "Rulesets:               $(rows rulesets.tsv)"
echo "API calls made:         $CALLS"
echo
echo "--- Deploy keys with WRITE access (review each) ---"
awk -F'\t' 'NR>1 && $4=="false"' deploy_keys.tsv
echo
echo "--- Webhook destinations (count, url) ---"
awk -F'\t' 'NR>1 {print $3}' webhooks.tsv | sort | uniq -c | sort -rn
echo
echo "--- Collaborators (number of repos, login) ---"
awk -F'\t' 'NR>1 {print $2}' collaborators.tsv | sort | uniq -c | sort -rn
echo
echo "--- Pending invitations ---"
awk -F'\t' 'NR>1' invitations.tsv

find . -maxdepth 1 -type f ! -name 'SHA256SUMS*' | sort | xargs sha256sum > SHA256SUMS.tmp && mv SHA256SUMS.tmp SHA256SUMS.txt

echo
if [ "$nfail" -gt 0 ]; then
  echo "WARNING: $nfail lookups failed (see errors.txt). Those repos are missing from the files above."
  echo "Run the script again; if the same lookups keep failing, send errors.txt to Kevin."
else
  echo "No lookup failures."
fi
echo "Results saved in: $PWD"
```

</details>


| Finding | Action |
| --- | --- |
| Deploy key with `read_only = false` | Delete unless a named system needs it; then replace with a new **read-only** key |
| Unknown deploy key, or one created after the infection date | Screenshot, delete |
| Webhook to an unknown domain, or created after the infection date | Screenshot, delete |
| Unknown collaborator | Goes into the review in 1b.8 |
| Invitation nobody sent | Cancel (blocking in 1b.8 also cancels invitations to blocked users) |
| Ganesh's own GitHub account, or other collaborators who left | Goes into the review in 1b.8 |

```bash
gh api -X DELETE "repos/$OWNER/REPO/keys/ID"          # deploy key
gh api -X DELETE "repos/$OWNER/REPO/hooks/ID"         # webhook
gh api -X DELETE "repos/$OWNER/REPO/invitations/ID"   # invitation
```

### 1b.7 — Rotate deployment and service credentials

Assume every credential that was on a developer machine, in a `.env` file or in a repo is stolen. **Revoke the old one first, issue the new one from the EC2 instance, then update whatever uses it.**

| Area | What to rotate |
| --- | --- |
| Cloud (AWS / Azure / GCP) | Access keys, service principal secrets, deployment service accounts. **Do AWS first if it hosts the EC2 instance** |
| Hosting and deployment | Platform tokens, deploy hooks, FTP/SSH deploy credentials |
| Package registries | npm tokens, container registry passwords |
| Databases | Passwords in `.env` files and connection strings |
| Third-party APIs | Payment, email, SMS, maps and other API keys |
| GitHub repo secrets | Any Actions or Codespaces secrets still configured |
| Client systems | Any client credential stored on consultancy machines: flag to Hexalytics leadership |

Anything a later secret scan of the repos finds gets added to this list.

### 1b.8 — Review collaborators and remove leavers and unknown users

**Why:** the repo freeze stops pushes, but every collaborator can still **read and clone** the code. People who have left, and accounts nobody recognises, need to go.

**The catch:** GitHub lists collaborators by **username**, not email. Kavitha's list of about 37 Gmail addresses is matched to usernames by `collaborator-report.sh`, using each account's public email and the email addresses on their commits. Nothing is removed until Kavitha approves the final list of usernames.

**How removal works:** `remove-collaborators.sh` **blocks** each approved user from the owner account. Blocking removes the user as a collaborator on every repo the account owns, cancels their pending invitations, and stops them forking or being added again ([GitHub Docs](https://docs.github.com/en/communities/maintaining-your-safety-on-github/blocking-a-user-from-your-personal-account)). That's one action per person instead of up to 300. It can be undone in **Settings → Blocked users → Unblock**; the person then has to be invited again. The script then checks that each person is really gone and removes them repo by repo anywhere they aren't.

**Step 1 — Save the email list (inside the EC2 instance).**
Create `emails-to-remove.txt` in the same folder as the scripts with all the addresses Kavitha has shared (currently about 51). Any layout works: one per line, comma-separated, `Name <email>`, or pasted from Excel; saved by Notepad in any encoding. Capital letters, duplicates and Gmail variants (`a.b@gmail.com` vs `ab@gmail.com` vs `ab+work@gmail.com`, which Gmail treats as one inbox) are handled. Lines with no email address are listed in `email-list-lines-ignored.txt` so nothing is dropped silently.

**Step 2 — Build the review sheet** (read-only; uses the folder from 1b.6):
```bash
bash collaborator-report.sh <owner-account-name> repo-inventory-<date-time> emails-to-remove.txt
```
For each person it runs one commit search across all repos, and checks their repos directly if the search finds nothing. Expect roughly 10–20 minutes. It creates a `collaborator-review-<date-time>` folder inside the inventory folder:

| File | What it tells Kavitha |
| --- | --- |
| `collaborators_review.tsv` | Every collaborator **and pending invitee**: username, name, **account creation date**, emails seen, repos with access, pending invitations, permission, whether they matched the list. Matched people are at the top. Opens in Excel with names shown correctly |
| `email_lookup.tsv` | Each email on the list and what was found: the username and how (public profile email, email on their commits, commit history search); an account with **no access** (nothing to remove); **commits found but not linked to any account** (the name on those commits is shown, so Kavitha can identify the person); **OWNER ACCOUNT** (the list contains the owner's own email: check the list); or **not found** |
| `remove-logins-suggested.txt` | The usernames matched to the list, ready for Kavitha to check |

**Step 3 — Kavitha reviews.**
- Go through `collaborators_review.tsv`, **including people not on her list**. Warning signs: an account created recently (after the infection started), no name, no commits, or a username nobody recognises.
- For emails marked **"not found - check manually"**: the person never committed with that email and doesn't show it publicly. Ask them or HR for their GitHub username, or look for them in a repo's **Settings → Collaborators** page, which shows names and profile pictures. If several remain, a slower full scan of all 300 repos can be run: `LOOKUP_REPOS=300 bash collaborator-report.sh ...`.
- **People not on her list still matter.** Anyone in the sheet she doesn't recognise, especially with an account created after the infection began or no name, should be added.
- Check `invitations.tsv` from 1b.6 for pending invitations to anyone who shouldn't join.
- Make sure **her own account and current developers are not on the list**.
- Save the final list as `remove-logins.txt`: **one GitHub username per line, no email addresses**. Start from `remove-logins-suggested.txt`, delete anyone who should stay, and add any extra usernames.
- Post her approval of the final list in the incident Teams group, and screenshot it for the evidence log.

**Step 4 — Dry run** (changes nothing):
```bash
bash remove-collaborators.sh <owner-account-name> repo-inventory-<date-time> remove-logins.txt
```
It checks every username exists on GitHub (catching typos such as `old0l` for `old01`), refuses email addresses, organizations and the owner account itself, then shows each person's name, how many repos they can reach, their pending invitations, and any **forks** of the account's repos they hold (`forks_found.tsv`). If forks are listed, keep that file as evidence and tell Kevin before the next step: GitHub doesn't document what happens to existing forks when a user is blocked.

**Step 5 — Remove.**
```bash
gh auth refresh -s user        # one-time: lets the CLI manage blocked users
bash remove-collaborators.sh <owner-account-name> repo-inventory-<date-time> remove-logins.txt --apply
```
Type `BLOCK <number>` when asked; anything else cancels. Each block is logged, then each person is checked on up to 10 of their repos. Anyone still found, or not blocked, is removed repo by repo automatically. Results are in `removal-<date-time>/verification.tsv` and `removal_log.tsv`. If anything failed, running the same command again is safe: people already blocked are skipped.

**Step 6 — Confirm.** Run `repo-inventory.sh` again. None of the removed usernames should appear in the new `collaborators.tsv`. Then run `gh auth logout`.

**Done when:** Kavitha's approval is recorded, every approved username is blocked, the new inventory shows none of them, and the "not found" emails have each been resolved or noted.

<details>
<summary>collaborator-report.sh (for review)</summary>

```bash
#!/usr/bin/env bash
# Collaborator review sheet for the GitHub owner account.
# Reads a repo-inventory folder, looks up each collaborator's (and invitee's) profile and the
# email addresses on their commits, and matches them against a list of email addresses to remove.
# Read-only: it changes nothing on GitHub.
#
# Usage (Git Bash on the clean EC2 instance, signed in as the owner account):
#   bash collaborator-report.sh <owner-account-name> <repo-inventory-folder> [emails-to-remove.txt]
#
# emails-to-remove.txt: email addresses in any layout (one per line, comma-separated,
# "Name <email>", pasted from Excel). Lines starting with # are ignored.

set -u

OWNER="${1:-}"; INV="${2:-}"; EMAILS="${3:-}"
LOOKUP_REPOS="${LOOKUP_REPOS:-50}"   # if commit search finds nothing for an email, repos checked directly (most recently pushed first). Set to 300 for a full scan.

if [ -z "$OWNER" ] || [ -z "$INV" ]; then
  echo "Usage: bash collaborator-report.sh <owner-account-name> <repo-inventory-folder> [emails-to-remove.txt]"
  exit 1
fi
[ -f "$INV/collaborators.tsv" ] || { echo "No collaborators.tsv in '$INV'. Run repo-inventory.sh first."; exit 1; }
[ -f "$INV/repos.txt" ]         || { echo "No repos.txt in '$INV'. Run repo-inventory.sh first."; exit 1; }
if [ -n "$EMAILS" ] && [ ! -f "$EMAILS" ]; then echo "Email list '$EMAILS' not found."; exit 1; fi

lower() { tr '[:upper:]' '[:lower:]'; }
OWNER_L=$(printf '%s' "$OWNER" | lower)

if ! gh auth status >/dev/null 2>&1 </dev/null; then echo "Not signed in to GitHub CLI. Run: gh auth login"; exit 1; fi
ME=$(gh api user -q .login 2>/dev/null </dev/null) || { echo "Could not read the signed-in account."; exit 1; }
if [ "$(printf '%s' "$ME" | lower)" != "$OWNER_L" ]; then
  echo "Signed in as '$ME', not '$OWNER'. Run 'gh auth login' as the owner account, then try again."
  exit 1
fi

OUT="$INV/collaborator-review-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$OUT" || exit 1
ERR="$OUT/errors.txt"; : > "$ERR"
TMPD=$(mktemp -d) || exit 1
trap 'rm -rf "$TMPD"' EXIT

# ---- GitHub API helpers ------------------------------------------------------
CALLS=0
GHQ_ERR=""
ratecheck() {
  CALLS=$((CALLS + 1))
  [ $((CALLS % 50)) -ne 0 ] && return 0
  local rem reset now pause
  rem=$(gh api rate_limit -q .resources.core.remaining 2>/dev/null </dev/null) || return 0
  [ "${rem:-5000}" -ge 200 ] 2>/dev/null && return 0
  reset=$(gh api rate_limit -q .resources.core.reset 2>/dev/null </dev/null)
  now=$(date +%s); pause=$(( ${reset:-$now} - now + 5 )); [ "$pause" -lt 5 ] && pause=5
  echo "GitHub API hourly limit nearly used up; pausing about $(( (pause + 59) / 60 )) min..." >&2
  sleep "$pause"
}
ghq() {
  local of=$1 rc=1 attempt; shift
  for attempt in 1 2 3; do
    ratecheck
    gh api "$@" > "$of" 2> "$TMPD/err" </dev/null; rc=$?
    GHQ_ERR=$(tr '\n\t' '  ' < "$TMPD/err")
    [ $rc -eq 0 ] && return 0
    case "$GHQ_ERR" in
      *"rate limit"*|*"HTTP 429"*) echo "GitHub rate limit hit; waiting 60 s..." >&2; sleep 60 ;;
      *"HTTP 50"*|*[Tt]imeout*|*connection*|*EOF*|*TLS*) sleep 5 ;;
      *) return $rc ;;
    esac
  done
  return $rc
}

# ---- Text helpers ------------------------------------------------------------
# Tolerates Windows files: UTF-8 with BOM, UTF-16 ("Unicode" in Notepad), CRLF line endings.
readtext() { tr -d '\000\377\376\r' < "$1" | sed '1s/^\xEF\xBB\xBF//'; }
# GitHub's search API allows about 30 searches a minute: space them out.
searchpace() { sleep 2.1; }
# Matching key: lower case; for Gmail, dots and "+tags" are ignored (Gmail treats them as the same inbox).
gnorm() {
  local e lp dom
  e=$(printf '%s' "$1" | lower); lp=${e%@*}; dom=${e##*@}
  case "$dom" in gmail.com|googlemail.com) lp=${lp%%+*}; lp=${lp//./}; dom=gmail.com ;; esac
  printf '%s@%s' "$lp" "$dom"
}
US=$'\x1f'
EMAIL_RE='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'

# ---- Emails to remove -------------------------------------------------------
declare -A REMOVE_KEY=()     # matching key -> email as given
REMOVE_KEYS=()
if [ -n "$EMAILS" ]; then
  readtext "$EMAILS" | sed 's/^[[:space:]]*#.*//' > "$TMPD/emails.txt"
  while IFS= read -r e; do
    k=$(gnorm "$e")
    if [ -z "${REMOVE_KEY[$k]:-}" ]; then REMOVE_KEY["$k"]="$e"; REMOVE_KEYS+=("$k"); fi
  done < <(grep -oE "$EMAIL_RE" "$TMPD/emails.txt" | lower)
  grep -vE "$EMAIL_RE" "$TMPD/emails.txt" | grep -v '^[[:space:]]*$' > "$OUT/email-list-lines-ignored.txt"
  if [ ${#REMOVE_KEYS[@]} -eq 0 ]; then
    echo "No email addresses found in '$EMAILS'. Check the file and try again."; exit 1
  fi
  for k in "${REMOVE_KEYS[@]}"; do printf '%s\n' "${REMOVE_KEY[$k]}"; done > "$OUT/emails-to-remove.normalised.txt"
  echo "Email addresses on the removal list: ${#REMOVE_KEYS[@]} (after removing duplicates)"
  [ -s "$OUT/email-list-lines-ignored.txt" ] && echo "NOTE: some lines had no email address; see email-list-lines-ignored.txt"
fi

# ---- People to review: collaborators and pending invitees (not the owner) ----
{
  awk -F'\t' 'NR>1 { print $2 }' "$INV/collaborators.tsv"
  [ -f "$INV/invitations.tsv" ] && awk -F'\t' 'NR>1 && $3!="(email invite)" { print $3 }' "$INV/invitations.tsv"
} | tr -d '\r' | grep -v '^$' | awk -v o="$OWNER_L" 'tolower($0)!=o' | sort -u > "$TMPD/logins"
mapfile -t LOGINS < "$TMPD/logins"
TOTAL=${#LOGINS[@]}
echo "People to review (collaborators and invitees, excluding the owner account): $TOTAL"

declare -A NAME=() CREATED=() NREPOS=() NINV=() PERMS=() SAMPLE=() EMAILS_OF=() MATCH=() IS_PERSON=()
declare -A KEY_TO_LOGIN=() HOW=()
for login in "${LOGINS[@]}"; do IS_PERSON["$(printf '%s' "$login" | lower)"]="$login"; done

addmatch() {  # addmatch <login> <email-as-given>
  case ",${MATCH[$1]:-}," in *",$2,"*) ;; *) MATCH["$1"]="${MATCH[$1]:+${MATCH[$1]},}$2" ;; esac
}

n=0
for login in "${LOGINS[@]}"; do
  n=$((n + 1))
  mapfile -t repos < <(awk -F'\t' -v l="$login" 'NR>1 { x=$2; gsub(/\r/,"",x); if (x==l) print $1 }' "$INV/collaborators.tsv")
  NREPOS["$login"]=${#repos[@]}
  NINV["$login"]=0
  [ -f "$INV/invitations.tsv" ] && NINV["$login"]=$(awk -F'\t' -v l="$login" 'NR>1 { x=$3; gsub(/\r/,"",x); if (x==l) c++ } END { print c+0 }' "$INV/invitations.tsv")
  PERMS["$login"]=$(awk -F'\t' -v l="$login" 'NR>1 { x=$2; p=$3; gsub(/\r/,"",x); gsub(/\r/,"",p); if (x==l) print p }' "$INV/collaborators.tsv" | sort -u | paste -sd, -)
  SAMPLE["$login"]=$(printf '%s\n' "${repos[@]:0:3}" | grep -v '^$' | paste -sd, -)

  p_name=""; p_pub=""; p_created=""
  if ghq "$TMPD/prof" "users/$login" -q "[(.name // \"\"), (.email // \"\"), (.created_at // \"\")] | join(\"$US\")"; then
    IFS="$US" read -r p_name p_pub p_created < "$TMPD/prof"
  else
    printf 'FAILED\tusers/%s\t%s\n' "$login" "$GHQ_ERR" >> "$ERR"
  fi
  NAME["$login"]=$p_name; CREATED["$login"]=$p_created
  p_pub=$(printf '%s' "$p_pub" | lower)

  # Emails on this person's commits: one search across all the owner's repos. If the search
  # finds nothing (its index can lag), check each of their repos directly until one has commits.
  : > "$TMPD/cem"
  searchpace
  if ! ghq "$TMPD/cem" -X GET search/commits -f q="author:$login user:$OWNER" -f per_page=50 -q '.items[].commit.author.email'; then
    printf 'FAILED\tsearch author:%s\t%s\n' "$login" "$GHQ_ERR" >> "$ERR"; : > "$TMPD/cem"
  fi
  if [ ! -s "$TMPD/cem" ]; then
    for repo in "${repos[@]}"; do
      if ghq "$TMPD/cem" -X GET "repos/$OWNER/$repo/commits" -f author="$login" -f per_page=20 -q '.[].commit.author.email'; then
        [ -s "$TMPD/cem" ] && break
      else
        case "$GHQ_ERR" in *409*|*404*) ;; *) printf 'FAILED\tcommits %s %s\t%s\n' "$repo" "$login" "$GHQ_ERR" >> "$ERR" ;; esac
        : > "$TMPD/cem"
      fi
    done
  fi
  { [ -n "$p_pub" ] && printf '%s\n' "$p_pub"; lower < "$TMPD/cem"; } | grep -v '^$' | sort -u > "$TMPD/all"
  EMAILS_OF["$login"]=$(paste -sd, - < "$TMPD/all")

  while IFS= read -r e; do
    [ -z "$e" ] && continue
    k=$(gnorm "$e")
    KEY_TO_LOGIN["$k"]="$login"
    if [ -n "${REMOVE_KEY[$k]:-}" ]; then
      addmatch "$login" "${REMOVE_KEY[$k]}"
      if [ "$e" = "$p_pub" ]; then HOW["$k"]="public profile email"; else HOW["$k"]="email on their commits"; fi
    fi
  done < "$TMPD/all"
  echo "[$n/$TOTAL] $login"
done

# ---- Emails not matched yet: search the most active repos' commit history ----
mapfile -t ALLREPOS < <(tr -d '\r' < "$INV/repos.txt" | grep -v '^$')
BOM=$'\xEF\xBB\xBF'
printf '%semail\tgithub_login\thow_found\tis_collaborator_or_invitee\tname_on_commits\n' "$BOM" > "$OUT/email_lookup.tsv"
if [ ${#REMOVE_KEYS[@]} -gt 0 ]; then
  unmatched=0; for k in "${REMOVE_KEYS[@]}"; do [ -z "${KEY_TO_LOGIN[$k]:-}" ] && unmatched=$((unmatched + 1)); done
  echo
  echo "Searching commit history for $unmatched unmatched email addresses..."
  for k in "${REMOVE_KEYS[@]}"; do
    given="${REMOVE_KEY[$k]}"; login="${KEY_TO_LOGIN[$k]:-}"; cname=""
    if [ -z "$login" ]; then
      found=0
      # 1) One commit search across all the owner's repos
      searchpace
      if ghq "$TMPD/rev" -X GET search/commits -f q="author-email:$given user:$OWNER" -f per_page=1 \
           -q "if (.items|length) > 0 then (.items[0] | [\"found\", (.author.login // \"\"), (.commit.author.name // \"\")] | join(\"$US\")) else empty end"; then
        [ -s "$TMPD/rev" ] && found=1
      else
        printf 'FAILED\tsearch author-email:%s\t%s\n' "$given" "$GHQ_ERR" >> "$ERR"
      fi
      # 2) If search found nothing, check the most recently pushed repos directly
      if [ $found -eq 0 ]; then
        for repo in "${ALLREPOS[@]:0:$LOOKUP_REPOS}"; do
          if ghq "$TMPD/rev" -X GET "repos/$OWNER/$repo/commits" -f author="$given" -f per_page=1 \
               -q "if length > 0 then (.[0] | [\"found\", (.author.login // \"\"), (.commit.author.name // \"\")] | join(\"$US\")) else empty end"; then
            [ -s "$TMPD/rev" ] && { found=1; break; }
          else
            case "$GHQ_ERR" in *409*|*404*) ;; *) printf 'FAILED\tcommits %s %s\t%s\n' "$repo" "$given" "$GHQ_ERR" >> "$ERR" ;; esac
          fi
        done
      fi
      if [ $found -eq 1 ]; then
        IFS="$US" read -r _ login cname < "$TMPD/rev"
        HOW["$k"]="commit history search"
        [ -z "$login" ] && HOW["$k"]="commits found, but this email isn't linked to any GitHub account"
      fi
      if [ -n "$login" ]; then
        canon="${IS_PERSON[$(printf '%s' "$login" | lower)]:-}"
        [ -n "$canon" ] && { login="$canon"; addmatch "$login" "$given"; }
      fi
    fi
    if [ -n "$login" ] && [ "$(printf '%s' "$login" | lower)" = "$OWNER_L" ]; then
      printf '%s\t%s\t%s\t%s\t%s\n' "$given" "$login" "${HOW[$k]:-}" "OWNER ACCOUNT - never removed" "$cname" >> "$OUT/email_lookup.tsv"
    elif [ -n "$login" ]; then
      who="no (nothing to remove)"; [ -n "${IS_PERSON[$(printf '%s' "$login" | lower)]:-}" ] && who="yes"
      printf '%s\t%s\t%s\t%s\t%s\n' "$given" "$login" "${HOW[$k]:-}" "$who" "$cname" >> "$OUT/email_lookup.tsv"
    else
      printf '%s\t\t%s\t\t%s\n' "$given" "${HOW[$k]:-not found - check manually}" "$cname" >> "$OUT/email_lookup.tsv"
    fi
  done
fi

# ---- Review sheet (UTF-8 with BOM so Excel shows names correctly) ------------
REVIEW="$OUT/collaborators_review.tsv"
printf '%slogin\tname\taccount_created\temails_seen\trepos_with_access\tpending_invitations\tpermissions\tsample_repos\ton_removal_list\tmatched_emails\tnotes\n' "$BOM" > "$REVIEW"
row() {
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t\n' "$1" "${NAME[$1]}" "${CREATED[$1]}" "${EMAILS_OF[$1]}" \
    "${NREPOS[$1]}" "${NINV[$1]}" "${PERMS[$1]}" "${SAMPLE[$1]}" "$2" "${MATCH[$1]:-}"
}
for login in "${LOGINS[@]}"; do [ -n "${MATCH[$login]:-}" ] && row "$login" YES; done >> "$REVIEW"   # matched first
for login in "${LOGINS[@]}"; do [ -z "${MATCH[$login]:-}" ] && row "$login" no;  done >> "$REVIEW"

SUGG="$OUT/remove-logins-suggested.txt"
{
  echo "# GitHub usernames matched to the removal email list."
  echo "# Kavitha: check each one, delete any line that should stay, add any extra username to remove."
  echo "# Save as remove-logins.txt and pass it to remove-collaborators.sh."
  for login in "${LOGINS[@]}"; do [ -n "${MATCH[$login]:-}" ] && echo "$login"; done | sort -f
} > "$SUGG"

( cd "$OUT" && find . -maxdepth 1 -type f ! -name 'SHA256SUMS*' | sort | xargs sha256sum > SHA256SUMS.tmp && mv SHA256SUMS.tmp SHA256SUMS.txt )

matched=$(grep -vc '^#' "$SUGG")
c_notfound=$(awk -F'\t' 'NR>1 && $2=="" && $3 ~ /^not found/' "$OUT/email_lookup.tsv" | wc -l | tr -d ' ')
c_unlinked=$(awk -F'\t' 'NR>1 && $2=="" && $3 ~ /^commits found/' "$OUT/email_lookup.tsv" | wc -l | tr -d ' ')
c_noaccess=$(awk -F'\t' 'NR>1 && $4 ~ /^no/' "$OUT/email_lookup.tsv" | wc -l | tr -d ' ')
c_owner=$(awk -F'\t' 'NR>1 && $4 ~ /^OWNER/' "$OUT/email_lookup.tsv" | wc -l | tr -d ' ')

echo
echo "================ SUMMARY ================"
echo "People reviewed:                              $TOTAL"
if [ ${#REMOVE_KEYS[@]} -gt 0 ]; then
  echo "Emails on the removal list:                   ${#REMOVE_KEYS[@]}"
  echo "People matched to those emails:               $matched"
  echo "Emails of accounts with no access (nothing to remove): $c_noaccess"
  echo "Emails on commits but not linked to an account (check by name): $c_unlinked"
  echo "Emails not found anywhere (check manually):   $c_notfound"
  [ "$c_owner" -gt 0 ] && echo "WARNING: $c_owner email(s) on the list belong to the OWNER account. Check the list with Kavitha."
fi
grep -q '^FAILED' "$ERR" && echo "WARNING: some lookups failed. See errors.txt; run the script again if many failed."
echo "API calls made: $CALLS"
echo
echo "Review sheet (opens in Excel):  $REVIEW"
echo "Email-to-account matches:       $OUT/email_lookup.tsv"
echo "Suggested removal list:         $SUGG"
```

</details>

<details>
<summary>remove-collaborators.sh (for review)</summary>

```bash
#!/usr/bin/env bash
# Removes approved users from every repo of the GitHub owner account by blocking them.
# Blocking removes the user as a collaborator on all of the account's repos, cancels their
# pending invitations, and stops them forking or being added again. It can be undone:
# Settings -> Blocked users -> Unblock (the person then has to be invited again).
#
# DRY RUN by default: nothing changes on GitHub unless --apply is given.
#
# Usage (Git Bash on the clean EC2 instance, signed in as the owner account):
#   bash remove-collaborators.sh <owner> <repo-inventory-folder> <remove-logins.txt>           # dry run
#   bash remove-collaborators.sh <owner> <repo-inventory-folder> <remove-logins.txt> --apply   # block
#
# remove-logins.txt: one GitHub username per line, approved by Kavitha. Lines starting with # ignored.

set -u

OWNER="${1:-}"; INV="${2:-}"; LIST="${3:-}"; MODE="${4:-}"
VERIFY_REPOS="${VERIFY_REPOS:-10}"   # repos re-checked per user after blocking

usage() { echo "Usage: bash remove-collaborators.sh <owner> <repo-inventory-folder> <remove-logins.txt> [--apply]"; exit 1; }
if [ -z "$OWNER" ] || [ -z "$INV" ] || [ -z "$LIST" ]; then usage; fi
APPLY=0
case "$MODE" in "") ;; --apply) APPLY=1 ;; *) usage ;; esac

[ -f "$INV/collaborators.tsv" ] || { echo "No collaborators.tsv in '$INV'. Run repo-inventory.sh first."; exit 1; }
[ -f "$LIST" ] || { echo "Removal list '$LIST' not found."; exit 1; }

lower() { tr '[:upper:]' '[:lower:]'; }
OWNER_L=$(printf '%s' "$OWNER" | lower)

if ! gh auth status >/dev/null 2>&1 </dev/null; then echo "Not signed in to GitHub CLI. Run: gh auth login"; exit 1; fi
ME=$(gh api user -q .login 2>/dev/null </dev/null) || { echo "Could not read the signed-in account."; exit 1; }
if [ "$(printf '%s' "$ME" | lower)" != "$OWNER_L" ]; then
  echo "Signed in as '$ME', not '$OWNER'. Run 'gh auth login' as the owner account, then try again."
  exit 1
fi
if ! gh api user/blocks --silent >/dev/null 2>&1 </dev/null; then
  echo "The GitHub CLI doesn't have permission to manage blocked users yet."
  echo "Run:  gh auth refresh -s user    then run this script again."
  exit 1
fi

OUT="$INV/removal-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$OUT" || exit 1
ERR="$OUT/errors.txt"; : > "$ERR"
TMPD=$(mktemp -d) || exit 1
trap 'rm -rf "$TMPD"' EXIT

# ---- GitHub API helpers ------------------------------------------------------
CALLS=0
GHQ_ERR=""
ratecheck() {
  CALLS=$((CALLS + 1))
  [ $((CALLS % 50)) -ne 0 ] && return 0
  local rem reset now pause
  rem=$(gh api rate_limit -q .resources.core.remaining 2>/dev/null </dev/null) || return 0
  [ "${rem:-5000}" -ge 200 ] 2>/dev/null && return 0
  reset=$(gh api rate_limit -q .resources.core.reset 2>/dev/null </dev/null)
  now=$(date +%s); pause=$(( ${reset:-$now} - now + 5 )); [ "$pause" -lt 5 ] && pause=5
  echo "GitHub API hourly limit nearly used up; pausing about $(( (pause + 59) / 60 )) min..." >&2
  sleep "$pause"
}
ghq() {
  local of=$1 rc=1 attempt; shift
  for attempt in 1 2 3; do
    ratecheck
    gh api "$@" > "$of" 2> "$TMPD/err" </dev/null; rc=$?
    GHQ_ERR=$(tr '\n\t' '  ' < "$TMPD/err")
    [ $rc -eq 0 ] && return 0
    case "$GHQ_ERR" in
      *"rate limit"*|*"HTTP 429"*) echo "GitHub rate limit hit; waiting 60 s..." >&2; sleep 60 ;;
      *"HTTP 50"*|*[Tt]imeout*|*connection*|*EOF*|*TLS*) sleep 5 ;;
      *) return $rc ;;
    esac
  done
  return $rc
}
US=$'\x1f'

# ---- Read and check the approved list ---------------------------------------
# Tolerates UTF-8 with BOM, UTF-16 ("Unicode" in Notepad) and CRLF line endings.
tr -d '\000\377\376\r' < "$LIST" | sed '1s/^\xEF\xBB\xBF//; s/^[[:space:]]*#.*//; s/[[:space:]]//g' | grep -v '^$' | sort -fu > "$TMPD/users"
mapfile -t USERS < "$TMPD/users"
[ ${#USERS[@]} -eq 0 ] && { echo "No usernames found in '$LIST'."; exit 1; }
cp "$LIST" "$OUT/approved-list-as-given.txt"

echo "Checking ${#USERS[@]} usernames..."
bad=0
declare -A NAME_OF=() IS_REMOVE=()
for u in "${USERS[@]}"; do
  if ! [[ $u =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,37}[A-Za-z0-9])?$ ]]; then
    echo "  Not a valid GitHub username: '$u'  (use usernames, not email addresses)"; bad=1; continue
  fi
  if [ "$(printf '%s' "$u" | lower)" = "$OWNER_L" ]; then
    echo "  Refusing: '$u' is the owner account itself."; bad=1; continue
  fi
  if ghq "$TMPD/u" "users/$u" -q "[.login, (.name // \"\"), .type] | join(\"$US\")"; then
    IFS="$US" read -r ulogin uname utype < "$TMPD/u"
    if [ "$utype" != "User" ]; then echo "  Refusing: '$u' is an organization, not a person."; bad=1; continue; fi
    NAME_OF["$u"]=$uname
  else
    echo "  Username not found on GitHub: '$u' (typo, or the account was renamed or deleted?)"; bad=1; continue
  fi
  IS_REMOVE["$(printf '%s' "$u" | lower)"]="$u"
done
[ $bad -eq 1 ] && { echo "Fix the list and run again. Nothing changed."; exit 1; }
printf '%s\n' "${USERS[@]}" > "$OUT/approved-usernames.txt"

repos_of() {  # repos where the user is a collaborator, from the inventory
  awk -F'\t' -v l="$(printf '%s' "$1" | lower)" 'NR>1 { x=$2; gsub(/\r/,"",x); if (tolower(x)==l) print $1 }' "$INV/collaborators.tsv"
}

# ---- Plan --------------------------------------------------------------------
printf 'login\tname\trepos_with_access\tpending_invitations\tnote\n' > "$OUT/removal_plan.tsv"
declare -A INVOLVED=()
for u in "${USERS[@]}"; do
  nrep=0
  while IFS= read -r r; do [ -n "$r" ] && { nrep=$((nrep + 1)); INVOLVED["$r"]=1; }; done < <(repos_of "$u")
  ninv=0
  if [ -f "$INV/invitations.tsv" ]; then
    ninv=$(awk -F'\t' -v l="$(printf '%s' "$u" | lower)" 'NR>1 { x=$3; gsub(/\r/,"",x); if (tolower(x)==l) c++ } END { print c+0 }' "$INV/invitations.tsv")
  fi
  note=""
  [ "$nrep" -eq 0 ] && [ "$ninv" -eq 0 ] && note="no access in the inventory: blocked to prevent future access"
  printf '%s\t%s\t%s\t%s\t%s\n' "$u" "${NAME_OF[$u]}" "$nrep" "$ninv" "$note" >> "$OUT/removal_plan.tsv"
done

# Forks these users hold of the owner's repos (evidence: capture before removal)
printf 'fork_owner\tfork\tforked_from\tcreated_at\n' > "$OUT/forks_found.tsv"
echo "Checking forks of ${#INVOLVED[@]} repos..."
for r in "${!INVOLVED[@]}"; do
  if ghq "$TMPD/f" "repos/$OWNER/$r/forks?per_page=100" --paginate -q '.[] | [.owner.login, .full_name, .created_at] | @tsv'; then
    while IFS=$'\t' read -r fo fn fc; do
      [ -n "${IS_REMOVE[$(printf '%s' "$fo" | lower)]:-}" ] && printf '%s\t%s\t%s\t%s\n' "$fo" "$fn" "$r" "$fc"
    done < "$TMPD/f" >> "$OUT/forks_found.tsv"
  else
    printf 'FAILED\tforks %s\t%s\n' "$r" "$GHQ_ERR" >> "$ERR"
  fi
done
nforks=$(( $(wc -l < "$OUT/forks_found.tsv") - 1 ))
nferr=$(grep -c '^FAILED' "$ERR")

echo
echo "================ PLAN ================"
column -t -s$'\t' "$OUT/removal_plan.tsv" 2>/dev/null || cat "$OUT/removal_plan.tsv"
echo
echo "Users to block: ${#USERS[@]}"
echo "Forks held by these users: $nforks  (listed in forks_found.tsv)"
[ "$nferr" -gt 0 ] && echo "WARNING: forks couldn't be checked for $nferr repos (see errors.txt)."

if [ $APPLY -eq 0 ]; then
  ( cd "$OUT" && find . -maxdepth 1 -type f ! -name 'SHA256SUMS*' | sort | xargs sha256sum > SHA256SUMS.tmp && mv SHA256SUMS.tmp SHA256SUMS.txt )
  echo
  echo "DRY RUN: nothing was changed on GitHub."
  echo "Review $OUT/removal_plan.tsv and forks_found.tsv, get Kavitha's go-ahead, then run again with --apply."
  exit 0
fi

# ---- Apply -------------------------------------------------------------------
[ "$nforks" -gt 0 ] && { echo; echo "NOTE: $nforks forks are held by these users. Their list is saved in forks_found.tsv as evidence."; }
echo
printf 'Type BLOCK %s to block these users now: ' "${#USERS[@]}"
read -r answer
if [ "$answer" != "BLOCK ${#USERS[@]}" ]; then echo "Cancelled. Nothing changed."; exit 1; fi

printf 'time\tlogin\taction\tresult\tdetail\n' > "$OUT/removal_log.tsv"
log() { printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$1" "$2" "$3" "${4:-}" >> "$OUT/removal_log.tsv"; }

for u in "${USERS[@]}"; do
  if ghq "$TMPD/b" "user/blocks/$u" --silent; then
    log "$u" block "already blocked"; echo "Already blocked: $u"
  elif ghq "$TMPD/b" -X PUT "user/blocks/$u" --silent; then
    log "$u" block ok; echo "Blocked: $u"
  else
    log "$u" block FAILED "$GHQ_ERR"; echo "FAILED to block: $u"
  fi
  sleep 1
done

# ---- Verify (and remove directly anywhere blocking didn't take effect) -------
echo
echo "Verifying..."
printf 'login\tblocked\tstill_collaborator_after_block\taction_taken\n' > "$OUT/verification.tsv"
for u in "${USERS[@]}"; do
  blocked="no"; ghq "$TMPD/v" "user/blocks/$u" --silent && blocked="yes"
  mapfile -t urepos < <(repos_of "$u")
  still=()
  for r in "${urepos[@]:0:$VERIFY_REPOS}"; do
    [ -z "$r" ] && continue
    if ghq "$TMPD/v" "repos/$OWNER/$r/collaborators/$u" --silent; then
      still+=("$r")
    else
      case "$GHQ_ERR" in *404*) ;; *) log "$u" "check $r" "COULD NOT CHECK" "$GHQ_ERR"; still+=("$r?") ;; esac
    fi
  done
  action="none needed"
  if [ ${#still[@]} -gt 0 ] || [ "$blocked" = "no" ]; then
    action="removed directly from ${#urepos[@]} repos"
    for r in "${urepos[@]}"; do
      [ -z "$r" ] && continue
      if ghq "$TMPD/d" -X DELETE "repos/$OWNER/$r/collaborators/$u" --silent; then
        log "$u" "remove from $r" ok
      else
        log "$u" "remove from $r" FAILED "$GHQ_ERR"; action="direct removal had failures (see removal_log.tsv)"
      fi
      sleep 0.3
    done
    [ ${#urepos[@]} -eq 0 ] && action="not blocked and no repos in the inventory: check by hand"
  fi
  printf '%s\t%s\t%s\t%s\n' "$u" "$blocked" "$(printf '%s\n' "${still[@]:-}" | grep -v '^$' | paste -sd, -)" "$action" >> "$OUT/verification.tsv"
done

( cd "$OUT" && find . -maxdepth 1 -type f ! -name 'SHA256SUMS*' | sort | xargs sha256sum > SHA256SUMS.tmp && mv SHA256SUMS.tmp SHA256SUMS.txt )

echo
echo "================ RESULT ================"
column -t -s$'\t' "$OUT/verification.tsv" 2>/dev/null || cat "$OUT/verification.tsv"
fails=$(awk -F'\t' 'NR>1 && ($4=="FAILED" || $4=="COULD NOT CHECK")' "$OUT/removal_log.tsv" | wc -l | tr -d ' ')
echo
[ "$fails" -gt 0 ] && echo "WARNING: $fails actions failed. See removal_log.tsv. Running the script again with --apply is safe: blocked users are skipped."
echo "API calls made: $CALLS"
echo "Records saved in: $OUT"
echo "Final check: run repo-inventory.sh again. None of these usernames should appear in collaborators.tsv or invitations.tsv."
```

</details>

---

## 1c — Privilege control

### What the owner account can do

On repos owned by a personal account, **whoever signs in to the owner account has full control of all 300 repos.** There is no smaller admin role to hand out, and Kavitha's own account can't be made a second owner.

| The owner account can | Risk if misused or stolen |
| --- | --- |
| Push to any branch, and bypass rulesets (it holds the repository admin role) | Undo protections; inject code that passes every rule |
| Add or remove collaborators, send invitations | Give an attacker access; lock developers out |
| Create, delete or edit rulesets, deploy keys and webhooks | Remove protections; exfiltrate code |
| Delete, transfer, rename or make public any repo | Data destruction or leak |
| Install GitHub Apps and authorize OAuth apps | Hidden persistent access |
| Change billing, the plan, the account email, password and 2FA | Full takeover; lock the company out |

### Who holds what today (fill in during 1b.5 and 1b.6)

| Person | Owner-account password? | 2FA on their phone? | Owner-account creds on their laptop? | Own GitHub account as collaborator? | Collaborator permission |
| --- | --- | --- | --- | --- | --- |
| Kavitha | Yes | | Yes (TortoiseGit, until 1b.4) | Yes (username: ________) | |
| Ganesh (left) | Unknown: treat as yes until the password is changed | Unknown: reset in 1b.1 | n/a | | |
| Others found | | | | | |

### Target model

| Identity | Used for | Used from | Privilege |
| --- | --- | --- | --- |
| **Owner account** (admin mailbox primary, Kavitha's email secondary) | Administration only: rulesets, collaborators, keys, security reviews | EC2 instance, browser and `gh` only | Full owner. Never used for daily Git work |
| **Kavitha's own GitHub account** | Her day-to-day Git work, including TortoiseGit | Her laptop, once confirmed clean | Collaborator (push) on the repos she needs, under the same rulesets as everyone else |
| **Developers' own accounts** | Development | Rebuilt machines | Collaborator, restored per repo as each is cleared |

**Access register (keep it current)**

| Item | Primary holder | Backup holder | Where kept |
| --- | --- | --- | --- |
| Owner-account password | Kavitha | (name) | Company vault, restricted entry |
| Owner-account 2FA (authenticator app) | Kavitha's company phone | (name)'s company phone | Phones |
| Recovery codes | — | — | Company vault, restricted entry, plus one sealed printed copy in the office safe |
| Admin mailbox password and MFA | Kavitha | (name) | Company vault / company phones |
| EC2 instance access | Kavitha | (AWS admins listed in section 0) | AWS IAM |

**Rules**
- Exactly **two** people can reach the owner account: Kavitha and one named backup. Nobody else gets the password, and it isn't shared over chat or email.
- Every use of the owner account is logged (date, who, why) in the evidence log.
- **During the incident, check the admin mailbox (or Kavitha's, until step 4) every day** for GitHub security emails: new sign-in, new key or token, password or 2FA change, new app. Anything Kavitha didn't do means stop and call Kevin.
- Monthly: review the owner account's security log, sessions, keys, tokens, apps and the collaborator list.
- When Kavitha or the backup person leaves or changes role: change the password, reconfigure 2FA, regenerate recovery codes, update the register. Ganesh's departure is the reason this phase exists.

**Done when:** the "today" table is filled in, the target model is agreed with Hexalytics management, a backup holder is named, and Kavitha's daily Git work no longer uses the owner account.

---

## Verification (Kevin, by screen share: after sitting 1, and again before sign-off)

| Check | Expected result |
| --- | --- |
| Settings → Emails | Kavitha's email (later the admin mailbox) primary; Ganesh's email gone; backup email = primary only; "Keep my email addresses private" on |
| Settings → Password and authentication | Authenticator app registered today; no SMS; recovery codes regenerated today; no passkeys, security keys or GitHub Mobile devices except those added today |
| Settings → Sessions | Only the current EC2 session |
| SSH and GPG keys; Personal access tokens | Empty, or only items created today and recorded in the evidence log |
| Applications (authorized OAuth apps, GitHub apps, installed apps) | Only the integrations agreed in 1b.3 |
| Security log, entries since sitting 1 | Only actions recorded in the evidence log |
| Kavitha's laptop: `cmdkey /list \| findstr /i github` | No owner-account entries |
| Repo inventory (1b.6) | No write-access deploy keys, unknown webhooks or unknown collaborators left unexplained |
| Collaborator removal (1b.8) | Fresh inventory shows none of the approved usernames; `verification.tsv` shows every one blocked |
| Repo freeze (Phase 2), spot-check one active repo | A collaborator push and a force push are both rejected |

---

## Evidence log

| Date & time | Step | Action taken | Screenshot / file | Done by |
| --- | --- | --- | --- | --- |
| | 0 | EC2 instance ready; access path; AWS access holders | | |
| | Before start | Connecting computer cleared; vault ready; backup person named; Kavitha's mailbox secured | | |
| | 1b.1 | Password changed; 2FA reconfigured (which phones); recovery codes regenerated | | |
| | 1b.2 | Sessions revoked (count) | | |
| | 1a.2 | Kavitha's email made primary; Ganesh's email removed; privacy and backup-email settings on | | |
| | 1b.3 | Keys, tokens and apps removed (counts and names) | | |
| | 1b.4 | Credential Manager entries removed (targets and users); Kavitha's own account secured | | |
| | 1b.5 | Security log exported (file name) | | |
| | 1b.6 | Repo inventory folder saved (with SHA256SUMS.txt); errors.txt empty; items removed | | |
| | 1b.7 | Credentials rotated (see rotation log) | | |
| | 1b.8 | Review sheet produced; Kavitha's approval screenshot; users blocked (count); forks_found.tsv saved; re-inventory clean | | |
| | 1a.3 | Admin mailbox created and hardened | | |
| | 1a.4 | Admin mailbox primary and verified; notifications and billing updated | | |
| | 1a.5 | Kavitha's email kept as secondary; her Git uses her own no-reply email | | |
| | 1c | Privilege tables filled; backup holder named | | |

**Findings (anything unexplained)**

| Date seen | Where | What | IP / location | Explained? | Action |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

**Credential rotation log**

| Credential | Used by | Old revoked (date) | New issued (date) | Issued from EC2? | Done by |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

---

## Sign-off

- [ ] 0 — Clean EC2 instance in use
- [ ] 1a — Ganesh's email removed; admin mailbox primary and hardened; backup email = primary only; Kavitha's email secondary with conditions met
- [ ] 1b.1 — Password, 2FA and recovery codes reset; 2FA only on company phones
- [ ] 1b.2 — Only the current session remains
- [ ] 1b.3 — Every key, token and app recognised or removed
- [ ] 1b.4 — No owner-account credentials on any laptop; Kavitha's own account secured
- [ ] 1b.5 — Security log exported; unexplained findings shared with Kevin
- [ ] 1b.6 — Deploy keys, webhooks, collaborators, invitations and rulesets reviewed on all repos; errors.txt empty
- [ ] 1b.7 — Rotation log complete
- [ ] 1b.8 — Leavers and unknown users blocked on Kavitha's approved list; "not found" emails resolved
- [ ] 1c — Privilege model agreed; access register filled in
- [ ] Verification checks passed (after sitting 1 and before sign-off)
- [ ] Evidence log, screenshots and SHA-256 hashes saved in the restricted company location

Signed off by: Kavitha ______________________  Date: ____________
Verified by: Kevin Christopher Clement ______________________  Date: ____________
