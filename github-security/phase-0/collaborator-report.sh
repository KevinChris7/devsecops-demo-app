#!/usr/bin/env bash
# Collaborator review sheet for the GitHub owner account.
# Reads a repo-inventory folder, looks up each collaborator's (and invitee's) profile and the
# email addresses on their commits, and matches them against a list of email addresses to remove.
# Read-only: it changes nothing on GitHub.
#
# Usage (Terminal on the clean EC2 instance, signed in as the owner account):
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

retry3() { local i; for i in 1 2 3; do "$@" >/dev/null 2>&1 </dev/null && return 0; [ $i -lt 3 ] && sleep 5; done; return 1; }
if ! retry3 gh auth status; then echo "Not signed in to GitHub CLI. Run: gh auth login"; exit 1; fi
ME=""
for _try in 1 2 3; do ME=$(gh api user -q .login 2>/dev/null </dev/null) && [ -n "$ME" ] && break; ME=""; sleep 5; done
[ -n "$ME" ] || { echo "Could not read the signed-in account: GitHub did not answer after 3 tries. Check the connection and run again."; exit 1; }
if [ "$(printf '%s' "$ME" | lower)" != "$OWNER_L" ]; then
  echo "Signed in as '$ME', not '$OWNER'. Run 'gh auth login' as the owner account, then try again."
  exit 1
fi

OUT="$INV/collaborator-review-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$OUT" || exit 1
ERR="$OUT/errors.txt"; : > "$ERR"
TMPD=$(mktemp -d) || exit 1
# On any exit: record checksums of whatever was produced, then clean up
trap '( cd "$OUT" && find . -maxdepth 1 -type f ! -name "SHA256SUMS*" | sort | xargs -r sha256sum > SHA256SUMS.tmp 2>/dev/null && mv SHA256SUMS.tmp SHA256SUMS.txt ); rm -rf "$TMPD"' EXIT

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

( cd "$OUT" && find . -maxdepth 1 -type f ! -name 'SHA256SUMS*' | sort | xargs -r sha256sum > SHA256SUMS.tmp && mv SHA256SUMS.tmp SHA256SUMS.txt )

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
