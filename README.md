Cloudflare Email Routing — Quickstart
A minimal, professional README showing exactly which commands to run to use create_routes.sh locally or on a VPS. Commands are grouped and presented as copy/paste blocks. Each block should be executed line-by-line in order.

Files required (keep together)

create_routes.sh
names.txt
Both files must be in the same directory when you run the script.

Requirements

Bash (modern)
jq
curl
git (only if cloning)
Usage — copy/paste command blocks

Run the commands in each block in order. There is a blank line between lines for readability.

Local — files already present
Run these commands where create_routes.sh and names.txt live.

chmod +x create_routes.sh

export CF_API_TOKEN="your_token_here"

export ZONE_ID="your_zone_id_here"

./create_routes.sh example.com 10 you@example.com

Local — clone then run (HTTPS)
Clone into ~/create-routes, enter the folder, then run.

git clone https://github.com/mredition/cloudflare-email-routing-generator.git ~/create-routes

cd ~/create-routes

chmod +x create_routes.sh

export CF_API_TOKEN="your_token_here"

export ZONE_ID="your_zone_id_here"

./create_routes.sh example.com 10 you@example.com

Local — clone then run (SSH)
Use SSH if your key is configured in GitHub.

git clone git@github.com:mredition/cloudflare-email-routing-generator.git ~/create-routes

cd ~/create-routes

chmod +x create_routes.sh

export CF_API_TOKEN="your_token_here"

export ZONE_ID="your_zone_id_here"

./create_routes.sh example.com 10 you@example.com

VPS — clone then run (HTTPS)
Run these on the VPS. This block creates the folder, clones, and runs the script.

mkdir -p "$HOME/create-routes"

git clone https://github.com/mredition/cloudflare-email-routing-generator.git "$HOME/create-routes"

cd "$HOME/create-routes"

chmod +x create_routes.sh

export CF_API_TOKEN="your_token_here"

export ZONE_ID="your_zone_id_here"

./create_routes.sh example.com 10 you@example.com

VPS — clone then run (SSH)
If your VPS user has an SSH key registered in GitHub, use SSH clone.

mkdir -p "$HOME/create-routes"

git clone git@github.com:mredition/cloudflare-email-routing-generator.git "$HOME/create-routes"

cd "$HOME/create-routes"

chmod +x create_routes.sh

export CF_API_TOKEN="your_token_here"

export ZONE_ID="your_zone_id_here"

./create_routes.sh example.com 10 you@example.com

Dry run (recommended before large runs)
Test with a single address to verify everything.

export CF_API_TOKEN="your_token_here"

export ZONE_ID="your_zone_id_here"

./create_routes.sh example.com 1 you@example.com

What the script does

Reads name pools from names.txt (sections: # --FIRST_NAMES--, # --LAST_NAMES--, # --OBJECTS--).
Generates the requested COUNT of randomized local-parts.
Calls the Cloudflare Email Routing API to create forwarding rules to the destination.
Prints created addresses and success/failure counts to stdout.
Minimal troubleshooting

"Error: Set CF_API_TOKEN..." — export CF_API_TOKEN (or CF_EMAIL + CF_API_KEY) in the same shell before running.
Missing jq — install with sudo apt-get install -y jq.
"names file not found" — ensure names.txt is in the same directory as create_routes.sh.
API errors — the script prints Cloudflare's API error messages; verify token scope and ZONE_ID.
Security note

The script does not store credentials to disk. Export credentials only in the shell session you use.
Use a scoped Cloudflare API Token with the minimum required permissions.
