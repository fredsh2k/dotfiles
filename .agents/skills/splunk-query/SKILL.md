---
name: splunk-query
description: Query Splunk logs via the Splunk API. Use when the user asks to search logs, investigate incidents, or query Splunk indexes.
---
# Splunk API Query

## Prerequisites

Requires Tailscale prod-vpn JIT: `.jit me to prod_vpn for 3h because querying splunk`
Set env var: `export SPLUNK_TOKEN=$(security find-generic-password -a "$USER" -s "splunk-token" -w)`

## Query Template

```bash
curl -s -k -H "Authorization: Bearer $SPLUNK_TOKEN" \
  "https://splunkazure-api-azure-eastus.octoca.ts.net/services/search/jobs/export" \
  --data-urlencode 'search=search index=<INDEX> <QUERY>' \
  -d earliest_time=-7d \
  -d output_mode=csv
```

## Options

- `output_mode`: csv, json.
- For readable CSV output pipe through: `| column -t -s,`
- Available indexes: https://github.com/github/splunkazure-indexmaster/blob/main/INDEXES_README.md
