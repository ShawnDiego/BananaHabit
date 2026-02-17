#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
    cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
    echo "[warn] .env not found. Created from .env.example: $ENV_FILE"
    echo "[warn] Please fill APNs config in .env before sending push."
  else
    echo "[error] Missing .env and .env.example"
    exit 1
  fi
fi

cd "$SCRIPT_DIR"
echo "[info] starting push server from $SCRIPT_DIR"
exec python3 server.py
