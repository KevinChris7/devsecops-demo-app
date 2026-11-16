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
