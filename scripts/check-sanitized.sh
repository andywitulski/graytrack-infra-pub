#!/usr/bin/env bash
# scripts/check-sanitized.sh [--staged]
# Fails if something that identifies a real environment is about to be published. Generic rules only, so
# this file is safe to publish. Add your own terms in a file OUTSIDE the repository, one per line:
#   SANITIZE_DENYLIST=~/private/denylist.txt scripts/check-sanitized.sh
# That list is also matched inside decoded base64 blobs: certificates embed names a text search cannot see.
set -uo pipefail
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd); cd "$root"
self=scripts/check-sanitized.sh
fail=0
report() { echo "FAIL: $1"; echo "$2" | sed 's/^/  /' | cut -c1-160 | head -20; fail=1; }

files=$(if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && [[ -n $(git ls-files | head -1) ]]; then
          [[ ${1:-} == --staged ]] && git diff --cached --name-only --diff-filter=ACMR || git ls-files
        else find . -type f -not -path './.git/*' | sed 's|^\./||'; fi | grep -vE "^($self|config/placeholders\.example\.env|bin/render-placeholders)$")
scan() { echo "$files" | tr '\n' '\0' | xargs -0 grep -nIE "$1" 2>/dev/null; }
# Prints file:line:value for every match, so one allowed value cannot hide a real one on the same line
scan_each() { echo "$files" | tr '\n' '\0' | xargs -0 grep -noIE "$1" 2>/dev/null; }

# Private addresses, apart from the generic range definitions the code legitimately names
r=$(scan_each '\b(10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3})\b' |
    grep -vE ':(10\.0\.0\.0|192\.168\.0\.0|172\.16\.0\.0)$')
[[ -n $r ]] && report "RFC 1918 address (use a __TOKEN__)" "$r"

r=$(scan_each '\b100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.[0-9]{1,3}\.[0-9]{1,3}\b' | grep -vE ':(100\.64\.0\.0|100\.100\.100\.100)$')
[[ -n $r ]] && report "overlay (CGNAT) address" "$r"

r=$(scan_each '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | grep -viE ':(00:00:5e:00:53:[0-9a-f]{2}|ff:ff:ff:ff:ff:ff|33:33:[0-9a-f:]+|01:00:5e:[0-9a-f:]+)$')
[[ -n $r ]] && report "MAC address outside the RFC 7042 documentation range" "$r"

r=$(scan_each '[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+\.[a-z]{2,}' | grep -vE '@([a-z0-9-]+\.)*example\.(com|org|net)$|@openssh\.com$|@github\.com$|@[a-z.]*\.(service|timer)$')
[[ -n $r ]] && report "e-mail address outside example.*" "$r"

r=$(scan 'BEGIN [A-Z ]*(PRIVATE KEY|CERTIFICATE)|ENC\[AES256|\bage1[a-z0-9]{50,}\b|AGE-SECRET-KEY|tskey-|ghp_|hvs\.[A-Za-z0-9]{20}|^sops:$')
[[ -n $r ]] && report "key, certificate or encrypted secret" "$r"

r=$(echo "$files" | grep -vE '^\.sops\.yaml$' | grep -E '(\.enc\.|\.sops\.ya?ml$|\.pem$|\.pub$|\.tfstate|keys\.txt$)')
[[ -n $r ]] && report "file type that must never be published" "$r"

if [[ -n ${SANITIZE_DENYLIST:-} && -f ${SANITIZE_DENYLIST:-} ]]; then
  r=$(echo "$files" | tr '\n' '\0' | xargs -0 grep -nIiFf "$SANITIZE_DENYLIST" 2>/dev/null)
  [[ -n $r ]] && report "denylisted term" "$r"
  r=$(echo "$files" | tr '\n' '\0' | SANITIZE_DENYLIST="$SANITIZE_DENYLIST" xargs -0 perl -MMIME::Base64 -e '
    open L, $ENV{SANITIZE_DENYLIST}; chomp(@t = <L>); @t = grep length, @t;
    for $f (@ARGV) { next unless -f $f; open F, "<", $f or next; local $/; $c = <F>; $c =~ s/\s+\n\s*//g;
      while ($c =~ m{([A-Za-z0-9+/]{40,}={0,2})}g) { $d = decode_base64($1);
        for (@t) { print "$f: base64 contains a denylisted term\n" if index(lc $d, lc $_) >= 0 } } }')
  [[ -n $r ]] && report "denylisted term inside base64" "$r"
fi

[[ $fail == 0 ]] && echo "check-sanitized: clean ($(echo "$files" | wc -l | tr -d ' ') files)"
exit $fail
