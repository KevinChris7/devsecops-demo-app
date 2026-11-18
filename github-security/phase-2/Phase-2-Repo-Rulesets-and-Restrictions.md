# Phase 2 — Repo Rulesets and Restrictions

**Goal:** Nobody can force-push to any repo, ever. While the clean-up runs, only the owner account can change anything (the **freeze**). Once a repo is cleaned, it gets permanent protection (the **baseline**). Inactive repos are archived.
**Who:** Kavitha, signed in as the owner account on the clean EC2 instance. Kevin runs the verification checks.
**When:** Start as soon as Phase 1 sitting 1 is done (owner account locked down). Until the freeze is on, compromised developer accounts can still push and force-push.
**Tool:** `apply-rulesets.sh`, which handles all 300 repos. It changes nothing without `--apply` and a typed confirmation, is safe to run again, and leaves rulesets it didn't create (such as the one Kavitha made earlier) untouched.

GitHub Pro enforces rulesets on private repos ([GitHub Docs](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)). Pro has no organization-wide rulesets, so the script sets them repo by repo.

---

## The rulesets

| Ruleset | When | Applies to | What it does | Who can get past it |
| --- | --- | --- | --- | --- |
| `IR-freeze-branches` | **Now**, every repo | All branches | No new branches, no pushes, no deletions, no force pushes | Owner account only |
| `IR-freeze-tags` | **Now**, every repo | All tags | No new tags, no changes, no deletions, no force pushes | Owner account only |
| `baseline-no-force-push` | After the repo is cleaned | All branches | No force pushes | **Nobody**, owner included |
| `baseline-protected-branches` | After the repo is cleaned | Each repo's default branch, plus `dev`, `qa`, `uat`, `prod`, `main` | Changes only through a pull request with 1 approval from someone else; a new push cancels earlier approvals; the last push must be approved by another person; Code Owner review; all review comments resolved; branch can't be deleted or force-pushed | Owner account, and only by merging a pull request |
| `baseline-tags` | After the repo is cleaned | All tags | Tags can't be moved, changed or deleted | **Nobody** |

**The freeze is temporary.** When a repo gets the baseline, the script removes that repo's freeze, but only after all three baseline rulesets are confirmed in place. A repo is never left unprotected in between. Once every repo is cleaned and on the baseline, no freeze rulesets remain. The baseline is permanent.

**Different branch names?** The protected list is set when the script runs. For example, to add a release branch pattern: `PROTECTED_BRANCHES="dev qa uat prod main release/*" bash apply-rulesets.sh ...`. The default is `dev qa uat prod main`.

**Typed confirmations.** Before any change, the script shows a line such as `Type FREEZE 288 to go ahead:`. Type exactly what it shows, in capitals, with the number it printed: that number is how many repos will change. Anything else (lowercase, a different number) cancels with nothing changed. This stops a command being run by accident, or against more repos than expected.

---

## Before you start

- [ ] Phase 1 sitting 1 complete (owner account password, 2FA, sessions, keys and tokens done)
- [ ] The repo inventory folder from Phase 1 (`repo-inventory-<date-time>`) is on the EC2 instance
- [ ] `apply-rulesets.sh` downloaded inside the EC2 browser into the same folder as the other scripts
- [ ] In the Terminal: `gh auth login`, signed in as the **owner account**
- [ ] Developers told (message below)

**Message to developers (Teams group):**
> From today, all company GitHub repos are frozen while we clean them. Pushes, new branches and force pushes will be refused; nothing is lost. Please don't try to work around it. Each repo reopens with normal pull-request rules once it's cleaned. Force pushes will stay blocked permanently, so use merge instead of rebase + force push.

---

## Step 1 — Prove the rules work, on a test repo

Do this once, before touching the real repos. It confirms GitHub enforces the rules on this account, and that the owner exception points at the right role.

1. In the EC2 browser, as the owner account, create a **private** repo named `ruleset-test`, ticking **Add a README file**.
2. Add Kavitha's own account (already secured in Phase 1) as a collaborator (**Settings → Collaborators → Add people**) and accept the invitation from her own account.
3. Freeze just this repo:
   ```bash
   printf 'ruleset-test\n' > test-repo.txt
   bash apply-rulesets.sh <owner> repo-inventory-<date-time> freeze --repos test-repo.txt --apply
   ```
   The script asks `Type FREEZE 1 to go ahead:`; type `FREEZE 1`. Expected: `All 1 repos are in the expected state.`
4. In the browser, open `ruleset-test` → **Settings → Rules → Rulesets → IR-freeze-branches**. Check the bypass list shows **Repository admin**. If it shows anything else, stop and tell Kevin.
5. **As a collaborator, the change is refused:** open a private window, sign in as Kavitha's **own** account, open `README.md`, click edit, and try to commit to `main`. GitHub must refuse it. It won't let her commit or create a branch.
6. **As the owner, the change is allowed** (the owner exception). In the Terminal:
   ```bash
   gh auth setup-git
   git clone https://github.com/<owner>/ruleset-test.git && cd ruleset-test
   git commit --allow-empty -m "freeze test" && git push            # expected: accepted
   cd ..
   ```
7. **Baseline: force push refused for everyone, including the owner:**
   ```bash
   bash apply-rulesets.sh <owner> repo-inventory-<date-time> baseline --repos test-repo.txt --apply
   cd ruleset-test
   git commit --allow-empty -m "direct push test" && git push        # expected: REJECTED, pull request required
   git reset --hard origin/main
   git commit --amend --allow-empty -m "rewrite" && git push --force # expected: REJECTED, force push blocked
   cd ..
   ```
   Type `PROTECT 1` when asked. Both pushes must be refused, with an error about repository rule violations (often code `GH013`).
8. Screenshot steps 4, 5 and 7, then delete `ruleset-test` (**Settings → Danger zone → Delete this repository**).

**Done when:** a collaborator can't push under the freeze, the owner can, and under the baseline nobody can push directly or force-push.

---

## Step 2 — Freeze every repo

1. **Dry run** (changes nothing):
   ```bash
   bash apply-rulesets.sh <owner> repo-inventory-<date-time> freeze
   ```
   ```
   Repos: 288   (archived repos are already read-only and are skipped: 12)
   Rulesets to set: IR-freeze-branches IR-freeze-tags
   ================ PLAN ================
   Repos to process:                 288
   Repos with other rulesets (kept): 1   (rulesets add up: the strictest rule applies)
   DRY RUN: nothing was changed on GitHub. Run again with --apply.
   ```
   `plan.tsv` shows, for every repo, what will be created or updated and any other rulesets already there.
2. **Apply:**
   ```bash
   bash apply-rulesets.sh <owner> repo-inventory-<date-time> freeze --apply
   ```
   Type `FREEZE <number>` exactly as shown. Expected:
   ```
   [1/288] repo-name ok
   ...
   ================ RESULT ================
   Repos checked:            288
   Frozen:                   288
   Baseline protection:      0
   Partly frozen:            0
   Archived since inventory: 0   (read-only, so protected)
   Neither (UNPROTECTED):    0
   Check failed:             0
   Rulesets not active:      0
   All 288 repos are in the expected state.
   ```
   The numbers will differ. If it says `WARNING: N repos are not in the expected state`, run the same command again: existing rulesets are updated, never duplicated. If the same repos keep failing, see "If something goes wrong" below.

## Step 3 — Check

```bash
bash apply-rulesets.sh <owner> repo-inventory-<date-time> status
```
Expected: `Frozen` equals the number of non-archived repos, and `Partly frozen`, `Neither (UNPROTECTED)` and `Check failed` are all `0`. Then spot-check two busy repos in the browser (**Settings → Rules → Rulesets**): both freeze rulesets should be listed as **Active**.

---

## Step 4 — Archive inactive repos

Archived repos are read-only for everyone, including the owner. That removes them from the attack surface entirely. It's reversible and deletes nothing.

1. **List candidates** (no push in 90 days):
   ```bash
   bash apply-rulesets.sh <owner> repo-inventory-<date-time> archive-candidates 90
   ```
   This writes `inactive-repos-suggested.txt`.
2. **Kavitha reviews:** she deletes any repo that must stay active (for example, one a client still depends on), saves the file as `inactive-repos.txt`, and posts her approval in the Teams group.
3. **Dry run, then archive:**
   ```bash
   bash apply-rulesets.sh <owner> repo-inventory-<date-time> archive --repos inactive-repos.txt
   bash apply-rulesets.sh <owner> repo-inventory-<date-time> archive --repos inactive-repos.txt --apply
   ```
   Type `ARCHIVE <number>`. Expected: `Archived and confirmed: N of N`.

**To unarchive later:** repo **Settings → Danger zone → Unarchive this repository**. Then freeze it again with `freeze --repos <file>`, because it comes back without the freeze.

---

## Step 5 — Permanent protection, repo by repo (after each repo is cleaned)

This runs during the clean-up phase. A repo gets the baseline only once it's clean, has a CODEOWNERS file, and its developers are cleared. Until then it stays frozen.

1. Put the cleaned repos in `cleaned-repos.txt`, one per line.
2. Dry run, then apply:
   ```bash
   bash apply-rulesets.sh <owner> repo-inventory-<date-time> baseline --repos cleaned-repos.txt
   bash apply-rulesets.sh <owner> repo-inventory-<date-time> baseline --repos cleaned-repos.txt --apply
   ```
   Type `PROTECT <number>`. Expected: `Baseline protection: N`, `Frozen: 0` for those repos, and `All N repos are in the expected state.`

**What developers experience after the baseline:**

| Action | Allowed? |
| --- | --- |
| Push to their own feature branch | Yes |
| Force push to any branch (including after a rebase) | **No**, for anyone. Use merge, or push to a new branch |
| Push directly to dev / qa / uat / prod / main (or the repo's default branch) | **No**. Open a pull request |
| Merge a pull request | After 1 approval from someone other than the last pusher, with comments resolved and Code Owner approval |
| Delete a protected branch | No |
| Move or delete a tag | No |

Code Owner approval only applies once the repo has a `CODEOWNERS` file, which is added during the clean-up. Every repo needs at least two people who can approve, since the last pusher can't approve their own change.

---

## If something goes wrong

| Situation | What to do |
| --- | --- |
| `WARNING: N repos are not in the expected state` | Run the same command again. If the same repos still fail, send `log.tsv` and `errors.txt` from that run's folder to Kevin |
| A repo shows `Neither (UNPROTECTED)` | That repo has no freeze. Re-run `freeze --repos <file>` for it; if it still fails, create the ruleset by hand in **Settings → Rules → New branch ruleset** and tell Kevin |
| A repo shows `Partly frozen` | One freeze ruleset is missing, disabled, or left over after the baseline. Run the same command again; it repairs this |
| A repo shows `Check failed` | Usually the repo was deleted or renamed after the inventory. Run `repo-inventory.sh` again, then repeat the step with the new inventory folder |
| The script was interrupted (window closed, connection lost) | Run the same command again. Repos already done are updated, not duplicated, and the rest are completed |
| An urgent fix is needed on a frozen repo | The owner account can push (it's the exception). Record who, what and why in the evidence log |
| A ruleset blocks something legitimate after the baseline | Don't delete it. Tell Kevin; the owner can temporarily set it to **Disabled** in **Settings → Rules**, and re-running `baseline` restores it |
| A repo is created or unarchived later | `freeze --repos <file>` with its name. Repos not in the inventory are checked on GitHub and included |
| GitHub limits or brief errors | Handled: the script retries and pauses by itself |

Every run creates a folder `rulesets-<mode>-<date-time>` inside the inventory folder, containing `plan.tsv`, `log.tsv`, `verification.tsv` or `status.tsv`, the exact ruleset definitions used, and `SHA256SUMS.txt`. Copy each folder to the evidence location.

---

## Verification (Kevin, by screen share)

| Check | Expected |
| --- | --- |
| Step 1 screenshots | Bypass = Repository admin; collaborator refused; owner allowed under freeze; direct push and force push refused under baseline |
| `status` output | Frozen = number of non-archived repos; Unprotected = 0; Check failed = 0 |
| Two repos checked in the browser | Both freeze rulesets **Active** |
| Archived repos | `Archived and confirmed: N of N`; matches Kavitha's approved list |
| Force-push activity after the freeze | No new force pushes in the repo activity logs (check again with `repo-inventory.sh` a day later) |

---

## Sign-off

- [ ] Step 1: rules proven on the test repo; test repo deleted
- [ ] Step 2: all non-archived repos frozen
- [ ] Step 3: status shows no unprotected repos
- [ ] Step 4: Kavitha-approved inactive repos archived
- [ ] Step 5: baseline applied to each repo as it's cleaned (ongoing)
- [ ] Run folders and screenshots saved in the evidence location

Signed off by: Kavitha ______________________  Date: ____________
Verified by: Kevin Christopher Clement ______________________  Date: ____________

---

<details>
<summary>apply-rulesets.sh (for review)</summary>

```bash
#!/usr/bin/env bash
# Phase 2: rulesets and restrictions for every repo of the GitHub owner account.
#
#   freeze               Only the owner account can push, create or delete branches and tags.
#                        Nobody can force-push. Applied to every non-archived repo.
#   baseline             Permanent protection for repos that have been cleaned (list required):
#                        no force pushes on any branch; pull request + 1 approval + Code Owner review
#                        on the default branch and dev, qa, uat, prod, main; those branches can't be deleted;
#                        tags can't be moved or deleted. The freeze is then removed from those repos.
#                        (Change the protected branches with PROTECTED_BRANCHES="dev qa uat prod main".)
#   status               Report which rulesets each repo has. Changes nothing.
#   archive-candidates N List repos with no push in the last N days (for Kavitha to approve). Changes nothing.
#   archive              Archive the approved repos (read-only for everyone; can be undone).
#
# DRY RUN by default: nothing changes on GitHub unless --apply is given.
#
# Usage (Terminal on the clean EC2 instance, signed in as the owner account):
#   bash apply-rulesets.sh <owner> <repo-inventory-folder> freeze   [--repos list.txt] [--apply]
#   bash apply-rulesets.sh <owner> <repo-inventory-folder> baseline --repos cleaned-repos.txt [--apply]
#   bash apply-rulesets.sh <owner> <repo-inventory-folder> status
#   bash apply-rulesets.sh <owner> <repo-inventory-folder> archive-candidates 90
#   bash apply-rulesets.sh <owner> <repo-inventory-folder> archive  --repos inactive-repos.txt [--apply]

set -u

OWNER="${1:-}"; INV="${2:-}"; MODE="${3:-}"
if [ $# -ge 3 ]; then shift 3; else set --; fi
APPLY=0; LIST=""; DAYS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --repos) LIST="${2:-}"
             if [ -z "$LIST" ] || [[ $LIST == --* ]]; then echo "--repos needs a file name, e.g. --repos cleaned-repos.txt"; exit 1; fi
             shift ;;
    *) if [[ $1 =~ ^[0-9]+$ ]]; then DAYS=$1; else echo "Unknown option: $1"; exit 1; fi ;;
  esac
  shift
done
BYPASS_ROLE_ID="${BYPASS_ROLE_ID:-5}"   # GitHub's built-in "Repository admin" role

usage() {
  cat <<'EOF'
Usage:
  bash apply-rulesets.sh <owner> <repo-inventory-folder> freeze   [--repos list.txt] [--apply]
  bash apply-rulesets.sh <owner> <repo-inventory-folder> baseline --repos cleaned-repos.txt [--apply]
  bash apply-rulesets.sh <owner> <repo-inventory-folder> status
  bash apply-rulesets.sh <owner> <repo-inventory-folder> archive-candidates 90
  bash apply-rulesets.sh <owner> <repo-inventory-folder> archive  --repos inactive-repos.txt [--apply]
EOF
  exit 1
}
[ -z "$OWNER" ] || [ -z "$INV" ] || [ -z "$MODE" ] && usage
case "$MODE" in freeze|baseline|status|archive-candidates|archive) ;; *) usage ;; esac
[ -f "$INV/repos.tsv" ] || { echo "No repos.tsv in '$INV'. Run repo-inventory.sh first."; exit 1; }
if [ "$MODE" = baseline ] || [ "$MODE" = archive ]; then
  [ -n "$LIST" ] || { echo "'$MODE' needs --repos <file> with the approved repo names."; exit 1; }
fi
[ -n "$LIST" ] && [ ! -f "$LIST" ] && { echo "Repo list '$LIST' not found."; exit 1; }
[ "$MODE" = archive-candidates ] && [ -z "$DAYS" ] && { echo "Give the number of days, e.g.: archive-candidates 90"; exit 1; }

lower() { tr '[:upper:]' '[:lower:]'; }
retry3() { local i; for i in 1 2 3; do "$@" >/dev/null 2>&1 </dev/null && return 0; [ $i -lt 3 ] && sleep 5; done; return 1; }
if ! retry3 gh auth status; then echo "Not signed in to GitHub CLI. Run: gh auth login"; exit 1; fi
ME=""
for _try in 1 2 3; do ME=$(gh api user -q .login 2>/dev/null </dev/null) && [ -n "$ME" ] && break; ME=""; sleep 5; done
[ -n "$ME" ] || { echo "Could not read the signed-in account: GitHub did not answer after 3 tries. Check the connection and run again."; exit 1; }
if [ "$(printf '%s' "$ME" | lower)" != "$(printf '%s' "$OWNER" | lower)" ]; then
  echo "Signed in as '$ME', not '$OWNER'. Run 'gh auth login' as the owner account, then try again."
  exit 1
fi

OUT="$INV/rulesets-$MODE-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$OUT" || exit 1
ERR="$OUT/errors.txt"; : > "$ERR"
TMPD=$(mktemp -d) || exit 1
trap 'sums 2>/dev/null; rm -rf "$TMPD"' EXIT   # checksums are recorded on any exit

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
  local of=$1 rc=1; shift
  for _ in 1 2 3; do
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
sums() { ( cd "$OUT" && find . -maxdepth 1 -type f ! -name 'SHA256SUMS*' | sort | xargs -r sha256sum > SHA256SUMS.tmp && mv SHA256SUMS.tmp SHA256SUMS.txt ); }
confirm() {  # confirm <WORD> <count>
  printf '\nType %s %s to go ahead: ' "$1" "$2"
  read -r answer
  [ "$answer" = "$1 $2" ] || { echo "Cancelled. Nothing changed."; exit 1; }
}

# ---- Repos -------------------------------------------------------------------
# repos.tsv columns: repo, archived, fork, visibility, last_push
awk -F'\t' 'NR>1 && $2=="false" {print $1}' "$INV/repos.tsv" | tr -d '\r' > "$TMPD/active"
awk -F'\t' 'NR>1 && $2=="true"  {print $1}' "$INV/repos.tsv" | tr -d '\r' > "$TMPD/archived"

readlist() {  # approved list -> target repos; refuses names not in the inventory or already archived
  tr -d '\000\377\376\r' < "$LIST" | sed '1s/^\xEF\xBB\xBF//; s/^[[:space:]]*#.*//; s/[[:space:]]//g' | grep -v '^$' | sort -u > "$TMPD/list"
  local bad=0 r
  while IFS= read -r r <&5; do
    if grep -qxF "$r" "$TMPD/active"; then echo "$r"
    elif grep -qxF "$r" "$TMPD/archived"; then echo "  '$r' is already archived" >&2; bad=1
    elif ghq "$TMPD/chk" "repos/$OWNER/$r" -q .archived; then   # e.g. a repo created after the inventory
      if [ "$(cat "$TMPD/chk")" = "false" ]; then echo "$r"; echo "  '$r' is not in the inventory but exists on GitHub: included" >&2
      else echo "  '$r' is already archived" >&2; bad=1; fi
    else echo "  '$r' not found in the inventory or on GitHub (typo?)" >&2; bad=1; fi
  done 5< "$TMPD/list" > "$TMPD/targets"
  [ $bad -eq 1 ] && { echo "Fix the list and run again. Nothing changed."; exit 1; }
  [ -s "$TMPD/targets" ] || { echo "No repos in '$LIST'."; exit 1; }
  cp "$LIST" "$OUT/approved-list-as-given.txt"
}

# ---- Ruleset definitions -----------------------------------------------------
RS="$OUT/ruleset-definitions"; mkdir -p "$RS"
BYPASS_ALWAYS="[{\"actor_id\":$BYPASS_ROLE_ID,\"actor_type\":\"RepositoryRole\",\"bypass_mode\":\"always\"}]"
BYPASS_PR="[{\"actor_id\":$BYPASS_ROLE_ID,\"actor_type\":\"RepositoryRole\",\"bypass_mode\":\"pull_request\"}]"
# Protected branches: each repo's default branch plus the team's environment branches
PROTECTED_BRANCHES="${PROTECTED_BRANCHES:-dev qa uat prod main}"
PROTECTED='["~DEFAULT_BRANCH"'
for b in $PROTECTED_BRANCHES; do
  if ! [[ $b =~ ^[A-Za-z0-9._/*-]+$ ]]; then echo "Invalid branch name in PROTECTED_BRANCHES: '$b'"; exit 1; fi
  PROTECTED+=",\"refs/heads/$b\""
done
PROTECTED+=']'

cat > "$RS/IR-freeze-branches.json" <<EOF
{"name":"IR-freeze-branches","target":"branch","enforcement":"active","bypass_actors":$BYPASS_ALWAYS,
 "conditions":{"ref_name":{"include":["~ALL"],"exclude":[]}},
 "rules":[{"type":"creation"},{"type":"update"},{"type":"deletion"},{"type":"non_fast_forward"}]}
EOF
cat > "$RS/IR-freeze-tags.json" <<EOF
{"name":"IR-freeze-tags","target":"tag","enforcement":"active","bypass_actors":$BYPASS_ALWAYS,
 "conditions":{"ref_name":{"include":["~ALL"],"exclude":[]}},
 "rules":[{"type":"creation"},{"type":"update"},{"type":"deletion"},{"type":"non_fast_forward"}]}
EOF
# No bypass at all: force pushes are blocked for everyone, the owner included.
cat > "$RS/baseline-no-force-push.json" <<EOF
{"name":"baseline-no-force-push","target":"branch","enforcement":"active","bypass_actors":[],
 "conditions":{"ref_name":{"include":["~ALL"],"exclude":[]}},
 "rules":[{"type":"non_fast_forward"}]}
EOF
cat > "$RS/baseline-protected-branches.json" <<EOF
{"name":"baseline-protected-branches","target":"branch","enforcement":"active","bypass_actors":$BYPASS_PR,
 "conditions":{"ref_name":{"include":$PROTECTED,"exclude":[]}},
 "rules":[{"type":"deletion"},{"type":"non_fast_forward"},
  {"type":"pull_request","parameters":{"required_approving_review_count":1,"dismiss_stale_reviews_on_push":true,
   "require_code_owner_review":true,"require_last_push_approval":true,"required_review_thread_resolution":true}}]}
EOF
cat > "$RS/baseline-tags.json" <<EOF
{"name":"baseline-tags","target":"tag","enforcement":"active","bypass_actors":[],
 "conditions":{"ref_name":{"include":["~ALL"],"exclude":[]}},
 "rules":[{"type":"update"},{"type":"deletion"},{"type":"non_fast_forward"}]}
EOF
FREEZE=(IR-freeze-branches IR-freeze-tags)
BASELINE=(baseline-no-force-push baseline-protected-branches baseline-tags)

# Existing rulesets of a repo -> $TMPD/rs as "id<TAB>name<TAB>enforcement"
list_rulesets() { ghq "$TMPD/rs" "repos/$OWNER/$1/rulesets?per_page=100" --paginate -q '.[] | [.id, .name, .enforcement] | @tsv'; }
rs_id() { awk -F'\t' -v n="$1" '$2==n {print $1; exit}' "$TMPD/rs"; }

printf 'time\trepo\taction\tresult\tdetail\n' > "$OUT/log.tsv"
log() { printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$1" "$2" "$3" "${4:-}" >> "$OUT/log.tsv"; }

upsert() {  # upsert <repo> <ruleset-name>  (create, or update the existing one with that name)
  local id; id=$(rs_id "$2")
  if [ -n "$id" ]; then
    if ghq "$TMPD/w" -X PUT "repos/$OWNER/$1/rulesets/$id" --input "$RS/$2.json"; then log "$1" "update $2" ok; return 0; fi
  else
    if ghq "$TMPD/w" -X POST "repos/$OWNER/$1/rulesets" --input "$RS/$2.json"; then log "$1" "create $2" ok; return 0; fi
  fi
  log "$1" "set $2" FAILED "$GHQ_ERR"; return 1
}
remove_rs() {  # remove_rs <repo> <ruleset-name>
  local id; id=$(rs_id "$2"); [ -z "$id" ] && return 0
  if ghq "$TMPD/w" -X DELETE "repos/$OWNER/$1/rulesets/$id"; then log "$1" "delete $2" ok; return 0; fi
  log "$1" "delete $2" FAILED "$GHQ_ERR"; return 1
}

# ---- status ------------------------------------------------------------------
do_status() {  # do_status <repo-file> <out-file>
  printf 'repo\tfrozen\tbaseline\tall_active\tother_rulesets\n' > "$2"
  local r n=0 total; total=$(grep -c . "$1")
  while IFS= read -r r <&4; do
    n=$((n + 1))
    if list_rulesets "$r"; then
      local fz="no" bl="no" act="yes" fb tb
      fb=$(awk -F'\t' '$2=="IR-freeze-branches" && $3=="active"' "$TMPD/rs" | wc -l)
      tb=$(awk -F'\t' '$2=="IR-freeze-tags" && $3=="active"' "$TMPD/rs" | wc -l)
      [ "$fb" -ge 1 ] && [ "$tb" -ge 1 ] && fz="yes"
      # Some freeze ruleset present, but not both active: half-applied or half-removed
      [ "$fz" = no ] && awk -F'\t' '$2 ~ /^IR-freeze-/' "$TMPD/rs" | grep -q . && fz="partial"
      [ "$(awk -F'\t' '($2=="baseline-no-force-push"||$2=="baseline-protected-branches"||$2=="baseline-tags") && $3=="active"' "$TMPD/rs" | wc -l)" -ge 3 ] && bl="yes"
      awk -F'\t' '$3!="active"' "$TMPD/rs" | grep -q . && act="NO"
      local other; other=$(awk -F'\t' '$2!~/^(IR-freeze-|baseline-)/ {print $2" ("$3")"}' "$TMPD/rs" | paste -sd, -)
      # Neither freeze nor baseline: check whether the repo was archived since the inventory (read-only, so safe)
      if [ "$fz" = no ] && [ "$bl" = no ] && ghq "$TMPD/arch" "repos/$OWNER/$r" -q .archived && [ "$(cat "$TMPD/arch")" = "true" ]; then
        fz="archived"
      fi
      printf '%s\t%s\t%s\t%s\t%s\n' "$r" "$fz" "$bl" "$act" "$other" >> "$2"
    else
      printf '%s\tCHECK FAILED\t\t\t%s\n' "$r" "$GHQ_ERR" >> "$2"
    fi
    [ $((n % 25)) -eq 0 ] && echo "  checked $n/$total"
  done 4< "$1"
}
summary_status() {  # summary_status <status-file>
  echo "Repos checked:            $(( $(wc -l < "$1") - 1 ))"
  echo "Frozen:                   $(awk -F'\t' 'NR>1 && $2=="yes"' "$1" | wc -l | tr -d ' ')"
  echo "Baseline protection:      $(awk -F'\t' 'NR>1 && $3=="yes"' "$1" | wc -l | tr -d ' ')"
  echo "Partly frozen:            $(awk -F'\t' 'NR>1 && $2=="partial"' "$1" | wc -l | tr -d ' ')   (a freeze ruleset is missing, disabled, or left over: run again)"
  echo "Archived since inventory: $(awk -F'\t' 'NR>1 && $2=="archived"' "$1" | wc -l | tr -d ' ')   (read-only, so protected)"
  echo "Neither (UNPROTECTED):    $(awk -F'\t' 'NR>1 && $2=="no" && $3=="no"' "$1" | wc -l | tr -d ' ')"
  echo "Check failed:             $(awk -F'\t' 'NR>1 && $2=="CHECK FAILED"' "$1" | wc -l | tr -d ' ')"
  echo "Rulesets not active:      $(awk -F'\t' 'NR>1 && $4=="NO"' "$1" | wc -l | tr -d ' ')"
}

case "$MODE" in
# ==============================================================================
status)
  echo "Checking rulesets on $(grep -c . "$TMPD/active") non-archived repos ($(grep -c . "$TMPD/archived") archived repos are read-only and skipped)..."
  do_status "$TMPD/active" "$OUT/status.tsv"
  sums
  echo; echo "================ STATUS ================"; summary_status "$OUT/status.tsv"
  echo; echo "Details: $OUT/status.tsv"
  ;;
# ==============================================================================
archive-candidates)
  cutoff=$(date -u -d "-$DAYS days" +%Y-%m-%dT%H:%M:%SZ)
  {
    echo "# Repos with no push since $cutoff ($DAYS days). Archiving makes a repo read-only for everyone."
    echo "# Kavitha: delete any line that must stay active, then save as inactive-repos.txt."
    awk -F'\t' -v c="$cutoff" 'NR>1 && $2=="false" && $5 < c {print $1}' "$INV/repos.tsv"
  } > "$OUT/inactive-repos-suggested.txt"
  sums
  echo "Repos with no push in the last $DAYS days: $(grep -vc '^#' "$OUT/inactive-repos-suggested.txt")"
  echo "List for Kavitha's review: $OUT/inactive-repos-suggested.txt"
  ;;
# ==============================================================================
archive)
  readlist
  N=$(grep -c . "$TMPD/targets")
  cp "$TMPD/targets" "$OUT/repos-to-archive.txt"
  echo "Repos to archive: $N  (list: $OUT/repos-to-archive.txt)"
  if [ $APPLY -eq 0 ]; then sums; echo; echo "DRY RUN: nothing was changed. Run again with --apply to archive them."; exit 0; fi
  confirm ARCHIVE "$N"
  while IFS= read -r r <&4; do
    if ghq "$TMPD/w" -X PATCH "repos/$OWNER/$r" -F archived=true; then log "$r" archive ok; echo "Archived: $r"
    else log "$r" archive FAILED "$GHQ_ERR"; echo "FAILED: $r"; fi
  done 4< "$TMPD/targets"
  printf 'repo\tarchived_now\n' > "$OUT/verification.tsv"
  while IFS= read -r r <&4; do
    a="CHECK FAILED"; ghq "$TMPD/v" "repos/$OWNER/$r" -q .archived && a=$(cat "$TMPD/v")
    printf '%s\t%s\n' "$r" "$a" >> "$OUT/verification.tsv"
  done 4< "$TMPD/targets"
  sums
  ok=$(awk -F'\t' 'NR>1 && $2=="true"' "$OUT/verification.tsv" | wc -l | tr -d ' ')
  echo; echo "Archived and confirmed: $ok of $N"
  [ "$ok" -ne "$N" ] && echo "WARNING: some repos were not archived. See verification.tsv and log.tsv; running again is safe."
  echo "Records saved in: $OUT"
  ;;
# ==============================================================================
freeze|baseline)
  if [ "$MODE" = freeze ]; then
    if [ -n "$LIST" ]; then readlist; else cp "$TMPD/active" "$TMPD/targets"; fi   # --repos: only those repos
    WANT=("${FREEZE[@]}"); DROP=()
  else readlist; WANT=("${BASELINE[@]}"); DROP=("${FREEZE[@]}"); fi
  N=$(grep -c . "$TMPD/targets")
  [ "$N" -eq 0 ] && { echo "No repos to process."; exit 1; }
  echo "Repos: $N   (archived repos are already read-only and are skipped: $(grep -c . "$TMPD/archived"))"
  echo "Rulesets to set: ${WANT[*]}"
  [ "$MODE" = baseline ] && echo "Protected branches: each repo's default branch + $PROTECTED_BRANCHES"
  [ ${#DROP[@]} -gt 0 ] && echo "Rulesets to remove afterwards: ${DROP[*]}"

  # Plan: read each repo's current rulesets
  printf 'repo\tplanned_actions\tother_existing_rulesets\n' > "$OUT/plan.tsv"
  n=0
  while IFS= read -r r <&4; do
    n=$((n + 1))
    if list_rulesets "$r"; then
      acts=""
      for w in "${WANT[@]}"; do if [ -n "$(rs_id "$w")" ]; then acts+="update $w; "; else acts+="create $w; "; fi; done
      for d in "${DROP[@]}"; do [ -n "$(rs_id "$d")" ] && acts+="delete $d; "; done
      other=$(awk -F'\t' '$2!~/^(IR-freeze-|baseline-)/ {print $2}' "$TMPD/rs" | paste -sd, -)
      printf '%s\t%s\t%s\n' "$r" "$acts" "$other" >> "$OUT/plan.tsv"
    else
      printf '%s\tCOULD NOT READ RULESETS\t%s\n' "$r" "$GHQ_ERR" >> "$OUT/plan.tsv"
    fi
    [ $((n % 25)) -eq 0 ] && echo "  planned $n/$N"
  done 4< "$TMPD/targets"
  unreadable=$(grep -c 'COULD NOT READ' "$OUT/plan.tsv")
  others=$(awk -F'\t' 'NR>1 && $3!=""' "$OUT/plan.tsv" | wc -l | tr -d ' ')
  echo
  echo "================ PLAN ================"
  echo "Repos to process:                 $N"
  echo "Repos with other rulesets (kept): $others   (rulesets add up: the strictest rule applies)"
  [ "$unreadable" -gt 0 ] && echo "WARNING: rulesets could not be read on $unreadable repos (see plan.tsv)."
  echo "Plan: $OUT/plan.tsv    Definitions: $RS/"
  if [ $APPLY -eq 0 ]; then sums; echo; echo "DRY RUN: nothing was changed on GitHub. Run again with --apply."; exit 0; fi

  WORD=FREEZE; [ "$MODE" = baseline ] && WORD=PROTECT
  confirm "$WORD" "$N"
  n=0
  while IFS= read -r r <&4; do
    n=$((n + 1))
    if ! list_rulesets "$r"; then log "$r" "read rulesets" FAILED "$GHQ_ERR"; echo "FAILED to read: $r"; continue; fi
    allok=1
    for w in "${WANT[@]}"; do upsert "$r" "$w" || allok=0; done
    if [ $allok -eq 1 ]; then
      for d in "${DROP[@]}"; do remove_rs "$r" "$d"; done
    elif [ ${#DROP[@]} -gt 0 ] && [ -n "$(rs_id IR-freeze-branches)" ]; then
      log "$r" "keep freeze" "kept" "baseline incomplete, so the freeze stays in place"
    elif [ ${#DROP[@]} -gt 0 ]; then
      log "$r" "no protection" "WARNING" "baseline failed and the repo has no freeze: fix by hand"
    fi
    echo "[$n/$N] $r $([ $allok -eq 1 ] && echo ok || echo 'HAD FAILURES')"
  done 4< "$TMPD/targets"

  echo; echo "Verifying..."
  do_status "$TMPD/targets" "$OUT/verification.tsv"
  sums
  echo; echo "================ RESULT ================"; summary_status "$OUT/verification.tsv"
  if [ "$MODE" = freeze ]; then bad=$(awk -F'\t' 'NR>1 && $2!="yes" && $2!="archived"' "$OUT/verification.tsv" | wc -l | tr -d ' ')
  else bad=$(awk -F'\t' 'NR>1 && ($3!="yes" || $2=="yes" || $2=="partial")' "$OUT/verification.tsv" | wc -l | tr -d ' '); fi
  fails=$(awk -F'\t' 'NR>1 && $4=="FAILED"' "$OUT/log.tsv" | wc -l | tr -d ' ')
  echo
  if [ "$bad" -gt 0 ] || [ "$fails" -gt 0 ]; then
    echo "WARNING: $bad repos are not in the expected state; $fails actions failed. See verification.tsv and log.tsv."
    echo "Running the same command again is safe: existing rulesets are updated, not duplicated."
  else
    echo "All $N repos are in the expected state."
  fi
  echo "API calls made: $CALLS"
  echo "Records saved in: $OUT"
  ;;
esac
```

</details>