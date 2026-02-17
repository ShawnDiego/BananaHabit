#!/usr/bin/env python3
"""Lightweight APNs push server that runs on macOS."""

from __future__ import annotations

import base64
import json
import os
import subprocess
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

ROOT_DIR = Path(__file__).resolve().parent
ENV_PATH = ROOT_DIR / ".env"
DEVICES_PATH = ROOT_DIR / "devices.json"


def load_env_file(path: Path) -> None:
    if not path.exists():
        return

    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


@dataclass
class ServerConfig:
    host: str
    port: int
    apns_key_id: str
    apns_team_id: str
    apns_auth_key_path: str
    apns_bundle_id: str
    apns_environment: str

    @staticmethod
    def from_env() -> "ServerConfig":
        apns_environment = os.getenv("APNS_ENV", "development").strip().lower()
        if apns_environment not in {"development", "production"}:
            apns_environment = "development"

        return ServerConfig(
            host=os.getenv("SERVER_HOST", "0.0.0.0").strip() or "0.0.0.0",
            port=int(os.getenv("SERVER_PORT", "8787")),
            apns_key_id=os.getenv("APNS_KEY_ID", "").strip(),
            apns_team_id=os.getenv("APNS_TEAM_ID", "").strip(),
            apns_auth_key_path=os.getenv("APNS_AUTH_KEY_PATH", "").strip(),
            apns_bundle_id=os.getenv("APNS_BUNDLE_ID", "").strip(),
            apns_environment=apns_environment,
        )

    @property
    def apns_host(self) -> str:
        if self.apns_environment == "production":
            return "api.push.apple.com"
        return "api.sandbox.push.apple.com"

    def missing_apns_fields(self, bundle_id: Optional[str] = None) -> List[str]:
        missing: List[str] = []
        if not self.apns_key_id:
            missing.append("APNS_KEY_ID")
        if not self.apns_team_id:
            missing.append("APNS_TEAM_ID")
        if not self.apns_auth_key_path:
            missing.append("APNS_AUTH_KEY_PATH")
        elif not Path(self.apns_auth_key_path).expanduser().exists():
            missing.append("APNS_AUTH_KEY_PATH(file-not-found)")

        effective_bundle_id = (bundle_id or self.apns_bundle_id).strip()
        if not effective_bundle_id:
            missing.append("APNS_BUNDLE_ID")

        return missing


class DeviceStore:
    def __init__(self, path: Path) -> None:
        self.path = path
        self.lock = threading.Lock()
        self.records: List[Dict[str, Any]] = []
        self._load()

    def _load(self) -> None:
        if not self.path.exists():
            self.records = []
            return

        try:
            data = json.loads(self.path.read_text(encoding="utf-8"))
            if isinstance(data, list):
                self.records = [item for item in data if isinstance(item, dict)]
            else:
                self.records = []
        except Exception as exc:  # pylint: disable=broad-except
            print(f"[warn] failed to load {self.path.name}: {exc}")
            self.records = []

    def _persist(self) -> None:
        self.path.write_text(
            json.dumps(self.records, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )

    def register(self, record: Dict[str, Any]) -> int:
        with self.lock:
            token = record["deviceToken"]
            self.records = [item for item in self.records if item.get("deviceToken") != token]
            self.records.append(record)
            self._persist()
            return len(self.records)

    def all_tokens(self) -> List[str]:
        with self.lock:
            return [item.get("deviceToken", "") for item in self.records if item.get("deviceToken")]

    def latest_token(self) -> Optional[str]:
        with self.lock:
            if not self.records:
                return None
            token = self.records[-1].get("deviceToken")
            return token if token else None

    def count(self) -> int:
        with self.lock:
            return len(self.records)


def now_iso8601() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def build_apns_jwt(config: ServerConfig) -> str:
    header = {"alg": "ES256", "kid": config.apns_key_id}
    claims = {"iss": config.apns_team_id, "iat": int(time.time())}

    header_segment = b64url(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    claims_segment = b64url(json.dumps(claims, separators=(",", ":")).encode("utf-8"))
    unsigned_token = f"{header_segment}.{claims_segment}"

    key_path = str(Path(config.apns_auth_key_path).expanduser())
    sign_process = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=unsigned_token.encode("utf-8"),
        capture_output=True,
        check=False,
    )

    if sign_process.returncode != 0:
        message = sign_process.stderr.decode("utf-8", errors="ignore").strip()
        raise RuntimeError(message or "openssl sign failed")

    signature_segment = b64url(sign_process.stdout)
    return f"{unsigned_token}.{signature_segment}"


def build_payload(request_data: Dict[str, Any]) -> Tuple[Dict[str, Any], str, str]:
    title = request_data.get("title")
    body = request_data.get("body")
    sound = request_data.get("sound", "default")
    badge = request_data.get("badge")
    mutable_content = bool(request_data.get("mutableContent", False))
    content_available = bool(request_data.get("contentAvailable", False))

    aps: Dict[str, Any] = {}

    if title or body:
        aps["alert"] = {
            "title": str(title or ""),
            "body": str(body or ""),
        }

    if sound:
        aps["sound"] = sound

    if badge is not None:
        aps["badge"] = int(badge)

    if mutable_content:
        aps["mutable-content"] = 1

    if content_available:
        aps["content-available"] = 1

    if not aps:
        raise ValueError("payload is empty; provide title/body or contentAvailable")

    payload: Dict[str, Any] = {"aps": aps}

    custom_data = request_data.get("customData")
    if custom_data is not None:
        if not isinstance(custom_data, dict):
            raise ValueError("customData must be an object")
        payload.update(custom_data)

    push_type = str(request_data.get("pushType", "")).strip().lower()
    if not push_type:
        push_type = "background" if content_available and "alert" not in aps else "alert"

    priority = str(request_data.get("priority", "")).strip()
    if not priority:
        priority = "5" if push_type == "background" else "10"

    return payload, push_type, priority


def send_apns_request(
    *,
    config: ServerConfig,
    jwt_token: str,
    device_token: str,
    topic: str,
    payload: Dict[str, Any],
    push_type: str,
    priority: str,
) -> Tuple[int, str]:
    url = f"https://{config.apns_host}/3/device/{device_token}"

    command = [
        "curl",
        "--silent",
        "--show-error",
        "--http2",
        "--write-out",
        "\n%{http_code}",
        "--header",
        f"authorization: bearer {jwt_token}",
        "--header",
        f"apns-topic: {topic}",
        "--header",
        f"apns-push-type: {push_type}",
        "--header",
        f"apns-priority: {priority}",
        "--data",
        json.dumps(payload, separators=(",", ":"), ensure_ascii=False),
        url,
    ]

    result = subprocess.run(command, capture_output=True, text=True, check=False)

    if result.returncode != 0:
        message = result.stderr.strip() or "curl request failed"
        raise RuntimeError(message)

    output = result.stdout
    if "\n" in output:
        body, status_raw = output.rsplit("\n", 1)
    else:
        body, status_raw = "", output

    status_code = int(status_raw.strip() or 0)
    return status_code, body.strip()


class PushRequestHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self) -> None:  # noqa: N802
        path = self._normalized_path()

        if path == "/health":
            self._send_json(
                200,
                {
                    "status": "ok",
                    "time": now_iso8601(),
                    "registeredDevices": DEVICE_STORE.count(),
                    "apnsEnvironment": CONFIG.apns_environment,
                },
            )
            return

        if path == "/api/device/list":
            self._send_json(
                200,
                {
                    "count": DEVICE_STORE.count(),
                    "tokens": DEVICE_STORE.all_tokens(),
                },
            )
            return

        self._send_json(404, {"message": "not found"})

    def do_POST(self) -> None:  # noqa: N802
        path = self._normalized_path()

        try:
            data = self._read_json_body()
        except ValueError as exc:
            self._send_json(400, {"message": str(exc)})
            return

        if path == "/api/device/register":
            self._handle_register(data)
            return

        if path == "/api/push/send":
            self._handle_send_push(data)
            return

        self._send_json(404, {"message": "not found"})

    def _handle_register(self, data: Dict[str, Any]) -> None:
        token = str(data.get("deviceToken", "")).strip()
        if not token:
            self._send_json(400, {"message": "deviceToken is required"})
            return

        record = {
            "deviceToken": token,
            "bundleId": str(data.get("bundleId", CONFIG.apns_bundle_id)).strip(),
            "environment": str(data.get("environment", CONFIG.apns_environment)).strip(),
            "platform": str(data.get("platform", "ios")).strip(),
            "registeredAt": str(data.get("registeredAt", now_iso8601())),
        }

        count = DEVICE_STORE.register(record)
        self._send_json(
            200,
            {
                "message": "device registered",
                "registeredDevices": count,
                "deviceToken": token,
            },
        )

    def _handle_send_push(self, data: Dict[str, Any]) -> None:
        bundle_id = str(data.get("bundleId", CONFIG.apns_bundle_id)).strip()
        missing = CONFIG.missing_apns_fields(bundle_id=bundle_id)
        if missing:
            self._send_json(
                400,
                {
                    "message": "missing APNs configuration",
                    "missing": missing,
                },
            )
            return

        tokens = self._resolve_target_tokens(data)
        if not tokens:
            self._send_json(
                400,
                {
                    "message": "no target device token",
                    "hint": "register device first or pass deviceToken/deviceTokens",
                },
            )
            return

        try:
            payload, push_type, priority = build_payload(data)
        except (ValueError, TypeError) as exc:
            self._send_json(400, {"message": str(exc)})
            return

        try:
            jwt_token = build_apns_jwt(CONFIG)
        except RuntimeError as exc:
            self._send_json(500, {"message": f"failed to create APNs JWT: {exc}"})
            return

        results: List[Dict[str, Any]] = []
        success = 0

        for token in tokens:
            try:
                status_code, response_body = send_apns_request(
                    config=CONFIG,
                    jwt_token=jwt_token,
                    device_token=token,
                    topic=bundle_id,
                    payload=payload,
                    push_type=push_type,
                    priority=priority,
                )
                if status_code == 200:
                    success += 1
                results.append(
                    {
                        "deviceToken": token,
                        "status": status_code,
                        "response": response_body,
                    }
                )
            except RuntimeError as exc:
                results.append(
                    {
                        "deviceToken": token,
                        "status": 0,
                        "response": str(exc),
                    }
                )

        all_ok = success == len(tokens)
        status = 200 if all_ok else 207
        self._send_json(
            status,
            {
                "message": "push sent" if all_ok else "push partially sent",
                "success": success,
                "failed": len(tokens) - success,
                "apnsHost": CONFIG.apns_host,
                "results": results,
            },
        )

    def _resolve_target_tokens(self, data: Dict[str, Any]) -> List[str]:
        single = str(data.get("deviceToken", "")).strip()
        if single:
            return [single]

        multiple = data.get("deviceTokens")
        if isinstance(multiple, list):
            return [str(item).strip() for item in multiple if str(item).strip()]

        send_to_all = bool(data.get("sendToAll", False))
        if send_to_all:
            return DEVICE_STORE.all_tokens()

        latest = DEVICE_STORE.latest_token()
        return [latest] if latest else []

    def _read_json_body(self) -> Dict[str, Any]:
        content_length = int(self.headers.get("Content-Length", "0"))
        if content_length <= 0:
            raise ValueError("request body is required")

        raw = self.rfile.read(content_length)
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ValueError(f"invalid JSON body: {exc.msg}") from exc

        if not isinstance(data, dict):
            raise ValueError("JSON body must be an object")

        return data

    def _normalized_path(self) -> str:
        path = self.path.split("?", 1)[0]
        if path != "/":
            path = path.rstrip("/")
        return path

    def _send_json(self, status_code: int, payload: Dict[str, Any]) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: Any) -> None:  # noqa: A003
        print(f"[{self.log_date_time_string()}] {self.address_string()} - {format % args}")


def run() -> None:
    server = ThreadingHTTPServer((CONFIG.host, CONFIG.port), PushRequestHandler)
    print(f"[info] push server started at http://{CONFIG.host}:{CONFIG.port}")
    print(f"[info] APNs environment: {CONFIG.apns_environment} ({CONFIG.apns_host})")

    missing = CONFIG.missing_apns_fields()
    if missing:
        print("[warn] APNs is not fully configured yet.")
        print(f"[warn] Missing: {', '.join(missing)}")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[info] shutting down...")
    finally:
        server.server_close()


load_env_file(ENV_PATH)
CONFIG = ServerConfig.from_env()
DEVICE_STORE = DeviceStore(DEVICES_PATH)

if __name__ == "__main__":
    run()
