#!/usr/bin/env bash
set -euo pipefail

# Simple generator that creates Cloudflare Email Routing rules.
# Usage: ./create_routes.sh <domain> <count> <destination_email>
# Provide credentials in environment (per-session):
#   export CF_API_TOKEN="..."
#   export ZONE_ID="..."
# or
#   export CF_EMAIL="..." && export CF_API_KEY="..."

CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_EMAIL="${CF_EMAIL:-}"
CF_API_KEY="${CF_API_KEY:-}"
ZONE_ID="${ZONE_ID:-your_zone_id_here}"
DELAY="${DELAY:-0.4}"
NAMES_FILE="${NAMES_FILE:-./names.txt}"

usage() {
  cat <<EOF
Usage: $0 <domain> <count> <destination_email>
Example:
  $0 example.com 10 you@gmail.com
EOF
  exit 1
}
[[ $# -lt 3 ]] && usage
DOMAIN="$1"
COUNT="$2"
DESTINATION="$3"
[[ "$COUNT" =~ ^[0-9]+$ ]] || { echo "Error: count must be a number" >&2; exit 1; }
[[ "$COUNT" -gt 0 ]] || { echo "Error: count must be > 0" >&2; exit 1; }
[[ "$DOMAIN" =~ \. ]] || { echo "Error: invalid domain" >&2; exit 1; }

if [[ -n "$CF_API_TOKEN" ]]; then
  AUTH_HEADER=(-H "Authorization: Bearer $CF_API_TOKEN")
elif [[ -n "$CF_EMAIL" && -n "$CF_API_KEY" ]]; then
  AUTH_HEADER=(-H "X-Auth-Email: $CF_EMAIL" -H "X-Auth-Key: $CF_API_KEY")
else
  echo "Error: Set CF_API_TOKEN or both CF_EMAIL + CF_API_KEY" >&2
  exit 1
fi

API="https://api.cloudflare.com/client/v4"

# Load sections from names file into an array named by $3
# Usage: load_section "$NAMES_FILE" "FIRST_NAMES" FIRST_NAMES
load_section() {
  local file="$1"
  local section="$2"
  local varname="$3"

  if [[ ! -f "$file" ]]; then
    echo "Error: names file not found: $file" >&2
    exit 1
  fi

  # mapfile accepts a variable name; this creates an array named by $varname
  mapfile -t "$varname" < <(
    awk -v sec="# --${section}--" '
      $0 == sec {p=1; next}
      /^# --.*--/ && p {exit}
      p && NF && $1 !~ /^#/ {print tolower($0)}
    ' "$file"
  )

  # check length of the created array
  local len
  eval "len=\${#${varname}[@]}"
  if [[ $len -eq 0 ]]; then
    echo "Error: section '$section' is missing or empty in $file" >&2
    exit 1
  fi
}

# load name arrays
load_section "$NAMES_FILE" "FIRST_NAMES" FIRST_NAMES
load_section "$NAMES_FILE" "LAST_NAMES" LAST_NAMES
load_section "$NAMES_FILE" "OBJECTS" OBJECTS

# Generate different styles of local parts
random_local() {
  local first=${FIRST_NAMES[$RANDOM % ${#FIRST_NAMES[@]}]}
  local style=$((RANDOM % 5))
  case $style in
    0)
      local num=$((RANDOM % 900 + 100))
      local letter
      letter=$(printf \\$(printf '%03o' $((97 + RANDOM % 26))))
      printf '%s' "${first}${num}${letter}"
      ;;
    1)
      local last=${LAST_NAMES[$RANDOM % ${#LAST_NAMES[@]}]}
      printf '%s' "${first}${last:0:3}"
      ;;
    2)
      local obj=${OBJECTS[$RANDOM % ${#OBJECTS[@]}]}
      printf '%s' "${first}${obj}"
      ;;
    3)
      local obj=${OBJECTS[$RANDOM % ${#OBJECTS[@]}]}
      local sep="."
      [[ $((RANDOM % 2)) -eq 0 ]] && sep="_"
      printf '%s' "${first}${sep}${obj}"
      ;;
    4)
      local last=${LAST_NAMES[$RANDOM % ${#LAST_NAMES[@]}]}
      local num=$((RANDOM % 90 + 10))
      if [[ $((RANDOM % 2)) -eq 0 ]]; then
        printf '%s' "${first:0:1}.${last}${num}"
      else
        printf '%s' "${first}.${last:0:1}${num}"
      fi
      ;;
  esac
}

create_rule() {
  local custom="$1" name="$2"
  local payload
  payload=$(jq -n \
    --arg name "$name" \
    --arg custom "$custom" \
    --arg dest "$DESTINATION" \
    '{
      name: $name,
      enabled: true,
      priority: 0,
      matchers: [
        { type: "literal", field: "to", value: $custom }
      ],
      actions: [
        { type: "forward", value: [$dest] }
      ]
    }'
  )
  local response
  response=$(curl -sS -X POST "$API/zones/$ZONE_ID/email/routing/rules" \
    "${AUTH_HEADER[@]}" \
    -H "Content-Type: application/json" \
    -d "$payload")
  if echo "$response" | jq -e '.success' >/dev/null; then
    echo "✓  $custom  →  $DESTINATION"
    return 0
  else
    local err
    err=$(echo "$response" | jq -r '.errors[0].message // "unknown error"')
    echo "✗  $custom  → failed: $err" >&2
    return 1
  fi
}

# main
echo "Creating $COUNT random-style email routes on $DOMAIN → $DESTINATION"
echo "------------------------------------------------------------"
success=0
failed=0
declare -a created=()
for ((i=1; i<=COUNT; i++)); do
  local_part=$(random_local)
  custom="${local_part}@${DOMAIN}"
  rule_name="Forward ${local_part}"
  if create_rule "$custom" "$rule_name"; then
    success=$((success + 1))
    created+=("$custom")
  else
    failed=$((failed + 1))
  fi
  sleep "$DELAY"
done
echo "------------------------------------------------------------"
echo "Done.  Success: $success   Failed: $failed"
if [[ ${#created[@]} -gt 0 ]]; then
  echo
  echo "Created addresses:"
  printf '  %s\n' "${created[@]}"
fi
