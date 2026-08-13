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

Run on a VPS or local computer (complete commands)
-------------------------------------------------
The following are explicit, copy-paste commands covering typical Debian/Ubuntu VPS or a local Linux box. Adjust user, paths and domain values where needed.

1) Install prerequisites
   - Debian/Ubuntu:
     sudo apt-get update
     sudo apt-get install -y curl jq git

   - RHEL/CentOS:
     sudo yum install -y curl jq git

   - macOS (Homebrew):
     brew install curl jq git

2) Get the project (clone or copy)
   - Clone via SSH:
     git clone git@github.com:<your-username>/<your-repo>.git ~/create-routes
     cd ~/create-routes

   - Or clone via HTTPS:
     git clone https://github.com/<your-username>/<your-repo>.git ~/create-routes
     cd ~/create-routes

   - If you already uploaded the three files to the VPS (create_routes.sh, names.txt, README.md), ensure they are in a directory, e.g. /opt/create-routes:
     sudo mkdir -p /opt/create-routes
     sudo chown $USER:$USER /opt/create-routes
     cp create_routes.sh names.txt README.md /opt/create-routes/
     cd /opt/create-routes

3) Make the script executable
   chmod +x create_routes.sh

4) Verify Cloudflare token (optional quick check)
   # If using CF_API_TOKEN:
   export CF_API_TOKEN="your_token_here"
   curl -sS -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
     -H "Authorization: Bearer $CF_API_TOKEN" \
     -H "Content-Type: application/json" | jq

   # If the token is valid you'll see success: true in the JSON output.

5) Provide credentials (secure, recommended)
   - Create a protected env file in your home directory:
     cat > ~/.routes_env <<'EOF'
     export CF_API_TOKEN="your_token_here"
     export ZONE_ID="your_zone_id_here"
     export NAMES_FILE="/home/ubuntu/create-routes/names.txt"   # adjust path
     export DELAY="0.4"
     EOF
     chmod 600 ~/.routes_env

   - Load it for the current shell:
     . ~/.routes_env

6) Test a dry run (one or two addresses)
   ./create_routes.sh example.com 1 you@example.com

   After running, check Cloudflare Email Routing UI or use the API to list rules:
   curl -sS -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/email/routing/rules" \
     -H "Authorization: Bearer ${CF_API_TOKEN}" \
     -H "Content-Type: application/json" | jq

7) Run interactively (screen / tmux)
   - screen:
     screen -S create-routes
     . ~/.routes_env
     ./create_routes.sh example.com 50 you@example.com
     # Detach with Ctrl-A D, reattach with screen -r create-routes

   - tmux:
     tmux new -s create-routes
     . ~/.routes_env
     ./create_routes.sh example.com 50 you@example.com
     # Detach with Ctrl-B D, reattach with tmux attach -t create-routes

8) Run in background (nohup + disown) — useful for short long-running jobs
   . ~/.routes_env
   nohup ./create_routes.sh example.com 200 you@example.com > ~/create-routes.log 2>&1 &
   disown

   # Check progress:
   tail -f ~/create-routes.log

9) Schedule with cron (absolute paths required)
   - Edit crontab for your user:
     crontab -e

   - Example: run daily at 02:00 using the env file:
     0 2 * * * . /home/ubuntu/.routes_env && /home/ubuntu/create-routes/create_routes.sh example.com 5 you@example.com >> /home/ubuntu/create-routes.log 2>&1

   Notes:
   - Use absolute paths in cron entries.
   - Make sure the env file uses full paths and is readable by the cron user (but not world-readable).

10) Run as a systemd one-shot service (recommended for repeated/manual runs)
    - Create working directory and copy files:
      sudo mkdir -p /opt/create-routes
      sudo chown $USER:$USER /opt/create-routes
      cp create_routes.sh names.txt /opt/create-routes/
      cd /opt/create-routes
      chmod +x create_routes.sh

    - Create an environment file (system-wide, owned by root):
      sudo tee /etc/default/create-routes.env > /dev/null <<'EOF'
      CF_API_TOKEN=your_token_here
      ZONE_ID=your_zone_id_here
      NAMES_FILE=/opt/create-routes/names.txt
      DELAY=0.4
      EOF
      sudo chmod 600 /etc/default/create-routes.env

    - Create the systemd unit:
      sudo tee /etc/systemd/system/create-routes.service > /dev/null <<'EOF'
      [Unit]
      Description=Create Cloudflare email routing rules (one-shot)
      After=network.target

      [Service]
      Type=oneshot
      EnvironmentFile=/etc/default/create-routes.env
      WorkingDirectory=/opt/create-routes
      ExecStart=/opt/create-routes/create_routes.sh example.com 10 you@example.com
      User=$USER
      Group=$USER

      [Install]
      WantedBy=multi-user.target
      EOF

    - Reload systemd, run now, and enable (if you want):
      sudo systemctl daemon-reload
      sudo systemctl start create-routes.service
      sudo systemctl status create-routes.service
      # Optional: enable to allow manual starts (oneshot is not typical to enable auto-run)
      sudo systemctl enable --now create-routes.service

    - Check logs:
      sudo journalctl -u create-routes.service --no-pager -n 200

11) Remove / cleanup (if needed)
    - To remove the service:
      sudo systemctl stop create-routes.service
      sudo systemctl disable create-routes.service
      sudo rm /etc/systemd/system/create-routes.service
      sudo rm /etc/default/create-routes.env
      sudo systemctl daemon-reload

    - Remove created rules via Cloudflare UI or the API (be careful; the script creates rules — deletion is separate).

Tips and important notes
------------------------
- Always test with a small COUNT and an address you control before large runs.
- Keep tokens secret: use files with chmod 600 and avoid storing them in the repo.
- Use absolute paths in cron/systemd so the working directory and env file are explicit.
- Use DELAY to avoid rate-limiting. If Cloudflare returns 429, increase DELAY.
- If you want idempotency, you'll need to modify the script to check for existing rules and skip duplicates.

Troubleshooting
---------------
- Missing jq: you will get JSON construction errors — install jq as shown above.
- API errors: the script prints Cloudflare API error messages; check token scope and ZONE_ID.
- Permission errors writing to /etc or /opt: use sudo for those steps, and set correct ownership after copying files.

Running from GitHub Actions (example)
------------------------------------
If you want to run this in CI (e.g., to populate test addresses), create a workflow with secrets referenced as environment variables. Example snippet:

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
