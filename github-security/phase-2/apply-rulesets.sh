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
