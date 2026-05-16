#!/usr/bin/env python3
"""tools/test_brainstem_server.py — minimal HTTP server wrapping the
neighborhood_membership_organ for federation tests.

Boots a stdlib http.server on the requested port that exposes the same
/api/neighborhoods/* surface as the full brainstem. Used in scenarios
that need to exercise REAL cross-process HTTP federation (one process
POSTs to another's /api/.../contribute) without the cost of starting
multiple full Flask brainstems with venvs and deps.

Usage:
    python3 tools/test_brainstem_server.py --port 7081 --home /tmp/bs-A
    # in another terminal:
    python3 tools/test_brainstem_server.py --port 7082 --home /tmp/bs-B
    # then POST a join + contribute between them.

Mounts:
  GET  /health                                  → {"ok": true, "port": <port>, "home": <home>}
  GET  /api/neighborhoods                       → list subscriptions
  POST /api/neighborhoods/join                  → join via gate_url
  GET  /api/neighborhoods/estate                → synthesized estate
  GET  /api/neighborhoods/by-rappid/<rappid>    → estate-by-identity lookup
  GET  /api/neighborhoods/<owner>/<repo>        → subscription detail
  POST /api/neighborhoods/<owner>/<repo>/sync   → resync
  GET  /api/neighborhoods/<owner>/<repo>/members
  POST /api/neighborhoods/<owner>/<repo>/leave
  POST /api/neighborhoods/<owner>/<repo>/contribute   ← federation receiver
  GET  /api/neighborhoods/<owner>/<repo>/contributions

The organ's HOME_BRAINSTEM / SUBS_FILE / CACHE_DIR are redirected to the
provided --home so each test process has its own subscription cache.
Logs to stderr; uses no third-party deps.
"""

import argparse
import http.server
import importlib.util
import json
import os
import socket
import socketserver
import sys
import threading
import time


REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_ORGAN = os.path.join(
    REPO_ROOT,
    "rapp_brainstem", "utils", "organs", "neighborhood_membership_organ.py",
)


def _load_organ(path, home_dir):
    spec = importlib.util.spec_from_file_location("test_membership_organ", path)
    organ = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(organ)
    organ.HOME_BRAINSTEM = home_dir
    organ.SUBS_FILE = os.path.join(home_dir, "neighborhoods.json")
    organ.CACHE_DIR = os.path.join(home_dir, "neighborhoods")
    os.makedirs(organ.CACHE_DIR, exist_ok=True)
    return organ


def _build_handler(organ, port, home_dir):
    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, fmt, *args):
            sys.stderr.write(f"[{port}] {fmt % args}\n")

        def _read_body(self):
            length = int(self.headers.get("Content-Length") or 0)
            if not length:
                return None
            raw = self.rfile.read(length).decode("utf-8")
            if not raw:
                return None
            try:
                return json.loads(raw)
            except ValueError:
                return None

        def _send(self, status, body):
            payload = json.dumps(body).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def _handle(self, method):
            path = self.path.split("?", 1)[0]
            if path == "/health":
                self._send(200, {
                    "ok": True, "port": port, "home": home_dir,
                    "schema": "rapp-test-brainstem/1.0",
                    "organ": "neighborhood_membership_organ",
                })
                return
            # /chat — the unified twin-chat federation primitive. Returns the
            # SAME shape as the canonical brainstem.py /chat ({response,
            # agent_logs}), so callers (human OR twin OR vbrainstem) are
            # agnostic to who's on the other end. Real Flask brainstems route
            # through the LLM + tool-call loop; this stand-in just echoes a
            # structured response so cross-process federation is verifiable
            # without an LLM.
            if path == "/chat" and method == "POST":
                body = self._read_body() or {}
                user_input = body.get("user_input") or ""
                self._send(200, {
                    "response": f"[test brainstem at :{port}] received: {user_input[:200]}",
                    "agent_logs": "",
                    "schema": "rapp-chat-response/1.0",
                    "_test_meta": {
                        "to_port": port,
                        "to_home": home_dir,
                        "echo": True,
                    },
                })
                return
            if not path.startswith("/api/neighborhoods"):
                self._send(404, {"error": "no route"})
                return
            rest = path[len("/api/neighborhoods"):].lstrip("/")
            body = self._read_body() if method == "POST" else None
            try:
                result, status = organ.handle(method, rest, body)
            except Exception as e:
                import traceback
                self._send(500, {"error": str(e), "traceback": traceback.format_exc()[-2000:]})
                return
            self._send(status, result)

        def do_GET(self):    self._handle("GET")
        def do_POST(self):   self._handle("POST")
        def do_PATCH(self):  self._handle("PATCH")
        def do_DELETE(self): self._handle("DELETE")
        def do_OPTIONS(self):
            self.send_response(204)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.end_headers()
    return Handler


class _ThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def _wait_for_port(port, timeout=5.0):
    end = time.time() + timeout
    while time.time() < end:
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.3):
                return True
        except (OSError, ConnectionRefusedError):
            time.sleep(0.05)
    return False


def main(argv=None):
    p = argparse.ArgumentParser(description="test brainstem server (membership organ only)")
    p.add_argument("--port", type=int, required=True)
    p.add_argument("--home", type=str, required=True, help="sandboxed ~/.brainstem dir")
    p.add_argument("--organ", type=str, default=DEFAULT_ORGAN, help="path to membership organ")
    p.add_argument("--bind", type=str, default="127.0.0.1")
    args = p.parse_args(argv)

    os.makedirs(args.home, exist_ok=True)
    organ = _load_organ(args.organ, args.home)
    handler = _build_handler(organ, args.port, args.home)
    server = _ThreadingServer((args.bind, args.port), handler)

    sys.stdout.write(f"PORT={args.port} HOME={args.home}\n")
    sys.stdout.flush()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        sys.stderr.write("interrupted; shutting down\n")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
