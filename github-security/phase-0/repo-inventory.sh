#!/usr/bin/env bash
# Repo inventory for the GitHub owner account.
# Lists deploy keys, webhooks, collaborators, pending invitations and rulesets on every repo.
# Read-only: it changes nothing on GitHub.
#
# Usage (Terminal on the clean EC2 instance):
#   gh auth login                                  # once, signed in as the OWNER account
#   bash repo-inventory.sh <owner-account-name>

set -u

OWNER="${1:-}"
if [ -z "$OWNER" ]; then
  echo "Usage: bash repo-inventory.sh <owner-account-name>"
  exit 1
fi

# Must be signed in, and signed in as the owner account (not Kavitha's own account)
retry3() { local i; for i in 1 2 3; do "$@" >/dev/null 2>&1 </dev/null && return 0; [ $i -lt 3 ] && sleep 5; done; return 1; }
if ! retry3 gh auth status; then
  echo "Not signed in to GitHub CLI. Run: gh auth login"
  exit 1
fi
ME=""
for _try in 1 2 3; do ME=$(gh api user -q .login 2>/dev/null </dev/null) && [ -n "$ME" ] && break; ME=""; sleep 5; done
[ -n "$ME" ] || { echo "Could not read the signed-in account: GitHub did not answer after 3 tries. Check the connection and run again."; exit 1; }
if [ "$(printf '%s' "$ME" | tr '[:upper:]' '[:lower:]')" != "$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')" ]; then
  echo "Signed in as '$ME', not '$OWNER'. Run 'gh auth login' as the owner account, then try again."
  exit 1
fi

OUT="repo-inventory-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$OUT" && cd "$OUT" || exit 1
TMPD=$(mktemp -d) || exit 1
# On any exit: record checksums of whatever was produced, then clean up
trap 'find . -maxdepth 1 -type f ! -name "SHA256SUMS*" | sort | xargs -r sha256sum > SHA256SUMS.tmp 2>/dev/null && mv SHA256SUMS.tmp SHA256SUMS.txt; rm -rf "$TMPD"' EXIT

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

find . -maxdepth 1 -type f ! -name 'SHA256SUMS*' | sort | xargs -r sha256sum > SHA256SUMS.tmp && mv SHA256SUMS.tmp SHA256SUMS.txt

echo
if [ "$nfail" -gt 0 ]; then
  echo "WARNING: $nfail lookups failed (see errors.txt). Those repos are missing from the files above."
  echo "Run the script again; if the same lookups keep failing, send errors.txt to Kevin."
else
  echo "No lookup failures."
fi
echo "Results saved in: $PWD"
