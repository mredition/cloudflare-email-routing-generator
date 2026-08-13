#!/usr/bin/env bash
set -euo pipefail
# Read names from a single names file with sections and create Cloudflare email routing rules.
# Usage: ./create_routes.sh <domain> <count> <destination_email>
# Environment variables:
#   CF_API_TOKEN or (CF_EMAIL + CF_API_KEY)
#   ZONE_ID
#   NAMES_FILE (optional, default: ./names.txt)
#   DELAY (optional)

# ====================== CONFIG ======================
CF_API_TOKEN="${CF_API_TOKEN:-}"
CF_EMAIL="${CF_EMAIL:-}"
CF_API_KEY="${CF_API_KEY:-}"
ZONE_ID="${ZONE_ID:-your_zone_id_here}"
DELAY="${DELAY:-0.4}"

NAMES_FILE="${NAMES_FILE:-./names.txt}"
# ====================================================

usage() {
  cat <<EOF
Usage: $0 <domain> <count> <destination_email>
Examples:
  $0 example.com 10 you@gmail.com

Optional env vars:
  NAMES_FILE (default: ./names.txt)
  DELAY (seconds between API calls)
  CF_API_TOKEN or CF_EMAIL + CF_API_KEY
  ZONE_ID
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

# Load a named section from NAMES_FILE into an array variable passed by name.
# Section header format in names file: "# --SECTION_NAME--"
load_name_section() {
  local file="$1"
  local section="$2"
  local -n out_array=$3

  if [[ ! -f "$file" ]]; then
    echo "Error: names file not found: $file" >&2
    exit 1
  fi

  # awk: find section header "# --SECTION--", then print lines until next "# --" header or EOF.
  mapfile -t out_array < <(
    awk -v section="$section" '
      $0 ~ ("# --"section"--") {p=1; next}
      /^# --.*--/ && p {exit}
      p && NF && $1 !~ /^#/ {print tolower($0)}
    ' "$file"
  )

  if [[ ${#out_array[@]} -eq 0 ]]; then
    echo "Error: section '$section' is empty or missing in $file" >&2
    exit 1
  fi
}

load_name_section "$NAMES_FILE" "FIRST_NAMES" FIRST_NAMES
load_name_section "$NAMES_FILE" "LAST_NAMES" LAST_NAMES
load_name_section "$NAMES_FILE" "OBJECTS" OBJECTS

# Generate different styles of local parts
random_local() {
  local first=${FIRST_NAMES[$RANDOM % ${#FIRST_NAMES[@]}]}
  local style=$((RANDOM % 5))
  case $style in
    0)  # name + 3-digit + letter, e.g. james577x
      local num=$((RANDOM % 900 + 100))
      local letter
      letter=$(printf \\$(printf '%03o' $((97 + RANDOM % 26))))
      printf '%s' "${first}${num}${letter}"
      ;;
    1)  # first + short last, e.g. jamessmi
      local last=${LAST_NAMES[$RANDOM % ${#LAST_NAMES[@]}]}
      printf '%s' "${first}${last:0:3}"
      ;;
    2)  # first + object, e.g. jamesdog
      local obj=${OBJECTS[$RANDOM % ${#OBJECTS[@]}]}
      printf '%s' "${first}${obj}"
      ;;
    3)  # first.sep.object e.g. james_dog or james.dog
      local obj=${OBJECTS[$RANDOM % ${#OBJECTS[@]}]}
      local sep="."
      [[ $((RANDOM % 2)) -eq 0 ]] && sep="_"
      printf '%s' "${first}${sep}${obj}"
      ;;
    4)  # abbreviated combos e.g. j.smith77 or james.s77
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
  local custom="$1"
  local name="$2"
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
        {
          type: "literal",
          field: "to",
          value: $custom
        }
      ],
      actions: [
        {
          type: "forward",
          value: [$dest]
        }
      ]
    }')

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

# ---------- main ----------
echo "Using names file: $NAMES_FILE"
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
echo
if [[ ${#created[@]} -gt 0 ]]; then
  echo "Created addresses:"
  printf '  %s\n' "${created[@]}"
fi
