# Cloudflare Email Routing: random-route-generator

This repository contains:
- create_routes.sh — a script that generates random local-parts using name pools and creates Cloudflare Email Routing rules.
- names.txt — combined name pools for first names, last names, and objects (single file with sections).
- README.md — this file.

Overview
--------
create_routes.sh reads names from names.txt (three sections) and posts email routing rules to the Cloudflare API to forward those addresses to a destination address.

Quick usage (local)
-------------------
1. Make script executable:
   chmod +x create_routes.sh

2. Export Cloudflare credentials and zone:
   export CF_API_TOKEN="your_token_here"
   export ZONE_ID="your_zone_id_here"

   Or export email + key:
   export CF_EMAIL="you@example.com"
   export CF_API_KEY="your_global_api_key"

3. Run:
   ./create_routes.sh example.com 10 you@example.com

   Optional:
   - NAMES_FILE to point to a different names file
   - DELAY to adjust seconds between API calls

Notes
-----
- names.txt must exist and contain three sections:
  - # --FIRST_NAMES--
  - # --LAST_NAMES--
  - # --OBJECTS--
  Lines starting with `#` (aside from section markers) and blank lines are ignored.
- The script requires `jq` and `curl`.
- The script normalizes name lines to lowercase.

