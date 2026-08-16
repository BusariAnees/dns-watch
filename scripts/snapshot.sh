#!/usr/bin/env bash
# Take a normalised snapshot of DNS records for each configured domain.
# Output is deterministic so that git diffs show real changes only.

set -uo pipefail

RESOLVER="${RESOLVER:-1.1.1.1}"
OUTDIR="${OUTDIR:-snapshots}"
CONFIG="${CONFIG:-domains.txt}"

TYPES=(NS SOA A AAAA MX TXT CAA)
SUBDOMAINS=(www _dmarc)

mkdir -p "$OUTDIR"

query() {
  # query <name> <type> -> sorted, comment-free records
  dig +noall +answer +time=3 +tries=2 "@${RESOLVER}" "$1" "$2" 2>/dev/null \
    | awk '{ $2=""; print }' \
    | sed 's/[[:space:]]\+/ /g; s/[[:space:]]*$//' \
    | sort
}

for domain in $(grep -vE '^\s*(#|$)' "$CONFIG"); do
  out="${OUTDIR}/${domain}.txt"
  tmp="$(mktemp)"

  {
    echo "# snapshot of ${domain}"
    echo "# resolver: ${RESOLVER}"
    echo

    for t in "${TYPES[@]}"; do
      echo "[${t}]"
      query "$domain" "$t"
      echo
    done

    for sub in "${SUBDOMAINS[@]}"; do
      echo "[${sub}.${domain}]"
      query "${sub}.${domain}" TXT
      query "${sub}.${domain}" A
      query "${sub}.${domain}" CNAME
      echo
    done

    echo "[registration]"
    if command -v whois >/dev/null 2>&1; then
      whois "$domain" 2>/dev/null \
        | grep -iE '^\s*(registrar|registrant|expiry|expiration|paid-till|renewal|status|name server|nserver|dnssec)' \
        | sed 's/[[:space:]]\+/ /g; s/^ //; s/[[:space:]]*$//' \
        | grep -viE 'whois server|abuse contact|url:' \
        | sort -u
    else
      echo "whois not installed"
    fi
  } > "$tmp"

  # Only overwrite if we actually got records back, so a network blip
  # never looks like "all your DNS disappeared".
  if grep -qE '^[a-zA-Z0-9_.-]+\. +IN +' "$tmp"; then
    mv "$tmp" "$out"
    echo "captured ${domain}"
  else
    rm -f "$tmp"
    echo "WARNING: no records returned for ${domain} - keeping previous snapshot" >&2
  fi
done
