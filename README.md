# dns-watch

Daily DNS and registration monitoring for a small number of domains, using
GitHub Actions. No server, no vendor, no secrets.

## What it does

Once a day it queries the public DNS records for each domain in `domains.txt`
and writes a normalised snapshot to `snapshots/`. If anything differs from
yesterday, it commits the change and opens a GitHub issue containing the diff.


## Setup

1. Create a private repo and push these files.
2. Edit `domains.txt` — one domain per line.
3. Settings > Actions > General > Workflow permissions: select
   "Read and write permissions".
4. Actions tab > dns-watch > Run workflow, to create the first baseline.

The first run records a baseline and will not alert. Every run after that
compares against it.

Notifications arrive by email through GitHub's normal issue notifications,
so there is no SMTP configuration.

## What is monitored

Per domain: NS, SOA, A, AAAA, MX, TXT, CAA.
Per domain also: `www` and `_dmarc` subdomains.
Registration: registrar, registrant, expiry date, status codes, nameservers,
DNSSEC status, from whois.

## Design notes

TTL values are stripped before comparison. TTLs count down on every query, so
including them would produce a diff every single run and the alerts would
become noise within a week.

Records are sorted before writing. Nameservers and MX records come back in a
different order each time, which would otherwise look like a change.

If a query returns no records at all, the previous snapshot is kept and a
warning is printed. Without this, one network failure would show up as
"every record deleted" and cause a false incident.

## What this does not cover

- Certificate issuance. Subscribe to certificate transparency alerts
  separately (crt.sh has RSS feeds per domain).
- DMARC aggregate reports. Those are pushed to you by mail receivers once
  `rua=` is published, and need a parser.
- Uptime. This watches what DNS says, not whether the server answers.

## Reading an alert

A diff on `[NS]` is the most serious thing this tool can show you. It means
the delegation moved, which means the whole zone can be replaced by whoever
moved it. Check the registrar account first, not the DNS host.

A diff on `[MX]` means mail is being routed somewhere new.

A diff on `[registration]` — particularly a status code appearing or
disappearing — can indicate a transfer in progress.
