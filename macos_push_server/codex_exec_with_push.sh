#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SEND_SCRIPT="$SCRIPT_DIR/send_push.sh"

if [[ ! -x "$SEND_SCRIPT" ]]; then
  echo "[error] send_push.sh not found or not executable: $SEND_SCRIPT"
  exit 1
fi

usage() {
  cat <<'EOF'
Usage:
  ./codex_exec_with_push.sh "your prompt"
  ./codex_exec_with_push.sh -- "your prompt"

Description:
  Run `codex exec` with your prompt, then send push notification when it finishes.

Env:
  PUSH_SERVER_URL   Optional, default: http://127.0.0.1:8787
EOF
}

if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == "--" ]]; then
  shift
fi

if [[ $# -eq 0 ]]; then
  echo "[error] missing prompt"
  usage
  exit 1
fi

PROMPT="$*"

# Keep the original Codex exit code
set +e
codex exec "$PROMPT"
CODEX_EXIT=$?
set -e

TITLE="Codex 任务完成"
BODY="任务执行成功"
if [[ $CODEX_EXIT -ne 0 ]]; then
  TITLE="Codex 任务失败"
  BODY="退出码: $CODEX_EXIT"
fi

# Trim prompt for push preview
SHORT_PROMPT="$PROMPT"
if [[ ${#SHORT_PROMPT} -gt 80 ]]; then
  SHORT_PROMPT="${SHORT_PROMPT[1,80]}..."
fi

"$SEND_SCRIPT" -t "$TITLE" -b "$BODY | $SHORT_PROMPT" || true
exit $CODEX_EXIT
