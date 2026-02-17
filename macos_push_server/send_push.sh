#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_URL="${PUSH_SERVER_URL:-http://192.168.31.217:8787}"
TITLE=""
BODY=""
TOKEN=""
SEND_TO_ALL=0
BADGE=""
SOUND="default"

usage() {
  cat <<'EOF'
Usage:
  ./send_push.sh -t "Title" -b "Message" [options]

Options:
  -t, --title <text>      Push title (required)
  -b, --body <text>       Push body (required)
  -u, --url <url>         Server URL (default: http://127.0.0.1:8787)
  --token <hex>           Send to one device token
  --all                   Send to all registered devices
  --badge <number>        Badge value
  --sound <name>          Sound name (default: default)
  -h, --help              Show this help

Examples:
  ./send_push.sh -t "BananaHabit" -b "Test push"
  ./send_push.sh -t "BananaHabit" -b "Broadcast" --all
  ./send_push.sh -t "BananaHabit" -b "Single device" --token <token>
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -t|--title)
      TITLE="$2"
      shift 2
      ;;
    -b|--body)
      BODY="$2"
      shift 2
      ;;
    -u|--url)
      SERVER_URL="$2"
      shift 2
      ;;
    --token)
      TOKEN="$2"
      shift 2
      ;;
    --all)
      SEND_TO_ALL=1
      shift
      ;;
    --badge)
      BADGE="$2"
      shift 2
      ;;
    --sound)
      SOUND="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[error] Unknown arg: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TITLE" || -z "$BODY" ]]; then
  echo "[error] title and body are required"
  usage
  exit 1
fi

if [[ "$SERVER_URL" != *"://"* ]]; then
  SERVER_URL="http://$SERVER_URL"
fi
SERVER_URL="${SERVER_URL%/}"

python3 - <<'PY' "$SERVER_URL" "$TITLE" "$BODY" "$TOKEN" "$SEND_TO_ALL" "$BADGE" "$SOUND"
import json
import sys
import urllib.error
import urllib.request

server_url, title, body, token, send_to_all, badge, sound = sys.argv[1:8]
url = f"{server_url}/api/push/send"

payload = {
    "title": title,
    "body": body,
    "sound": sound,
}
if token:
    payload["deviceToken"] = token
if send_to_all == "1":
    payload["sendToAll"] = True
if badge:
    payload["badge"] = int(badge)

request = urllib.request.Request(
    url,
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)

try:
    with urllib.request.urlopen(request, timeout=20) as response:
        body_text = response.read().decode("utf-8", errors="replace")
        print(body_text)
except urllib.error.HTTPError as exc:
    text = exc.read().decode("utf-8", errors="replace")
    print(text)
    sys.exit(1)
except Exception as exc:
    print(f"[error] failed to send push: {exc}")
    sys.exit(1)
PY
