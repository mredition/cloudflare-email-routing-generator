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
  Lines beginning with `#` (aside from section markers) and blank lines are ignored.
- The script requires `jq` and `curl`.
- Name lines are normalized to lowercase by the script.

Run on a VPS (self-contained, copy/paste)
----------------------------------------
This section is a standalone quickstart for a Debian/Ubuntu VPS. Paste each block into the VPS shell and run it. Each block is self-contained for its purpose — do not mix lines from different blocks.

IMPORTANT: Replace example.com, you@example.com, "your_token_here" and "your_zone_id_here" with real values before executing the step that runs the script or writes system files.

A — Install prerequisites (one-shot)
# Update package list and install git, curl and jq
sudo apt-get update && sudo apt-get install -y git curl jq

B — Download the repository and enter its folder (HTTPS)
# Create target directory, clone and change directory
mkdir -p "$HOME/create-routes" && git clone https://github.com/mredition/cloudflare-email-routing-generator.git "$HOME/create-routes" && cd "$HOME/create-routes"

# Optional SSH clone (only if your SSH key is configured on GitHub):
# mkdir -p "$HOME/create-routes" && git clone git@github.com:mredition/cloudflare-email-routing-generator.git "$HOME/create-routes" && cd "$HOME/create-routes"

C — Make the script executable
chmod +x create_routes.sh

D — Create a secure environment file (store secrets, reusable)
# Create ~/.routes_env with your credentials and configuration
cat > "$HOME/.routes_env" <<'EOF'
export CF_API_TOKEN="your_token_here"
export ZONE_ID="your_zone_id_here"
export NAMES_FILE="$HOME/create-routes/names.txt"
export DELAY="0.4"
EOF
chmod 600 "$HOME/.routes_env"

# Load the file into the current shell
. "$HOME/.routes_env"

E — Verify Cloudflare token (optional)
curl -sS -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | jq

F — Test run (dry run, single address)
./create_routes.sh example.com 1 you@example.com

# After this command, check Cloudflare Email Routing in the dashboard to confirm the rule was created.

Background and scheduling (standalone blocks)
---------------------------------------------
Each block assumes steps A–F are done and that ~/.routes_env and the repo exist in $HOME/create-routes.

1) Run in background now (nohup)
. "$HOME/.routes_env"
nohup "$HOME/create-routes/create_routes.sh" example.com 200 you@example.com > "$HOME/create-routes.log" 2>&1 &
disown
# Monitor:
tail -f "$HOME/create-routes.log"

2) Schedule with cron (daily at 02:00)
# Open your crontab editor and add exactly the following line (replace paths as needed):
0 2 * * * . $HOME/.routes_env && $HOME/create-routes/create_routes.sh example.com 5 you@example.com >> $HOME/create-routes.log 2>&1

3) Run once via systemd (one-shot)
# Copy files to /opt/create-routes and set permissions
sudo mkdir -p /opt/create-routes
sudo chown "$(whoami)":"$(whoami)" /opt/create-routes
sudo cp "$HOME/create-routes/create_routes.sh" "$HOME/create-routes/names.txt" /opt/create-routes/
cd /opt/create-routes
sudo chmod +x create_routes.sh

# Create a system-wide environment file (edit values as needed)
sudo tee /etc/default/create-routes.env > /dev/null <<'EOF'
CF_API_TOKEN=your_token_here
ZONE_ID=your_zone_id_here
NAMES_FILE=/opt/create-routes/names.txt
DELAY=0.4
EOF
sudo chmod 600 /etc/default/create-routes.env

# Create the systemd unit file
sudo tee /etc/systemd/system/create-routes.service > /dev/null <<'EOF'
[Unit]
Description=Create Cloudflare email routing rules (one-shot)
After=network.target

[Service]
Type=oneshot
EnvironmentFile=/etc/default/create-routes.env
WorkingDirectory=/opt/create-routes
ExecStart=/opt/create-routes/create_routes.sh example.com 10 you@example.com
User=$(whoami)
Group=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and run the unit now
sudo systemctl daemon-reload
sudo systemctl start create-routes.service
sudo systemctl status create-routes.service
# View logs
sudo journalctl -u create-routes.service --no-pager -n 200

# To remove the unit and env later:
sudo systemctl stop create-routes.service || true
sudo systemctl disable create-routes.service || true
sudo rm -f /etc/systemd/system/create-routes.service
sudo rm -f /etc/default/create-routes.env
sudo systemctl daemon-reload

Tips and important notes
------------------------
- Always test with a small COUNT and an address you control before large runs.
- Keep tokens secret: use files with chmod 600 and avoid storing them in the repo.
- Use absolute paths in cron/systemd so the working directory and env file are explicit.
- Use DELAY to avoid rate-limiting. If Cloudflare returns 429, increase DELAY.
- If you want idempotency, you'll need to modify the script to check for existing rules and skip duplicates.

Troubleshooting
---------------
- Missing jq: install jq (sudo apt-get install -y jq).
- API errors: the script prints Cloudflare API error messages; check token scope and ZONE_ID.
- Permission errors writing to /etc or /opt: use sudo for those steps and set correct ownership after copying files.

Running from GitHub Actions (example)
------------------------------------
Example workflow snippet:

```yaml
# .github/workflows/create-routes.yml (example)
name: Create random routes
on:
  workflow_dispatch:
jobs:
  create:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install jq
        run: sudo apt-get update && sudo apt-get install -y jq
      - name: Run generator
        env:
          CF_API_TOKEN: ${{ secrets.CF_API_TOKEN }}
          ZONE_ID: ${{ secrets.ZONE_ID }}
        run: ./create_routes.sh example.com 5 you@example.com
