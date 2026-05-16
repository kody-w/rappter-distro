#!/usr/bin/env python3
"""tls_proxy.py — self-signed HTTPS in front of the local brainstem.

Why: the live tether at https://kody-w.github.io/RAPP/pages/tether.html
can't fetch http://localhost:7071/chat — browsers block HTTPS→HTTP
"mixed content" regardless of CORS. This standalone proxy gives the
tether a same-scheme target so the "🌐 Ground tether to local brainstem"
feature works without an external tunnel service (cloudflared, ngrok).

Architecture: kernel brainstem.py stays untouched (kernel sacred per
CONSTITUTION Article XXXIII). This is a sibling process — HTTPS
reverse-proxy. Run alongside ./start.sh.

Usage:
    # Terminal 1: the brainstem itself
    cd rapp_brainstem && ./start.sh

    # Terminal 2: the HTTPS proxy
    python3 rapp_brainstem/tls_proxy.py

    # Terminal 3 (one-time): trust the cert in your browser
    open https://localhost:7072/
    # Browser shows "Your connection isn't private" — click
    # "Advanced" → "Proceed to localhost (unsafe)" once.
    # macOS Chrome: also add the cert to Keychain if you want the
    # warning to disappear permanently.

After that the tether's "🌐 Ground" prompt accepts
https://localhost:7072/chat and grounded mode works.

Cert details: RSA-2048 self-signed, CN=localhost, SAN includes
DNS:localhost + IP:127.0.0.1, valid 825 days. Generated once into
~/.brainstem/tls/{cert.pem,key.pem} and reused on every restart so
the browser trust persists.

Pure stdlib + openssl CLI (installed on macOS + most Linux distros
by default). No pip dependencies.
"""

from __future__ import annotations

import argparse
import http.server
import os
import ssl
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

TLS_DIR = Path(os.path.expanduser("~/.brainstem/tls"))
CERT    = TLS_DIR / "cert.pem"
KEY     = TLS_DIR / "key.pem"


def ensure_cert() -> None:
    """Generate a self-signed cert at ~/.brainstem/tls/ if missing."""
    if CERT.exists() and KEY.exists():
        return
    TLS_DIR.mkdir(parents=True, exist_ok=True)
    print(f"[tls_proxy] generating self-signed cert at {CERT} …")
    try:
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048",
            "-keyout", str(KEY),
            "-out",    str(CERT),
            "-days",   "825",
            "-nodes",
            "-subj",   "/CN=localhost",
            "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1",
        ], check=True, capture_output=True)
    except FileNotFoundError:
        sys.exit("[tls_proxy] error: openssl not found. Install it "
                 "(macOS: pre-installed; apt: `apt install openssl`).")
    except subprocess.CalledProcessError as e:
        sys.exit(f"[tls_proxy] openssl failed:\n{e.stderr.decode(errors='replace')}")
    # Tighten permissions so the key is operator-only-readable.
    try:
        os.chmod(KEY, 0o600)
        os.chmod(CERT, 0o644)
    except Exception:
        pass


# ────────────────────────────────────────────────────────────────────
# Reverse-proxy HTTP handler
# ────────────────────────────────────────────────────────────────────

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    target: str = "http://localhost:7071"

    # Skip-headers: hop-by-hop + things urllib will set for us, and
    # the upstream's CORS headers (we replace with permissive ones).
    HOP = {
        "host", "connection", "keep-alive", "transfer-encoding",
        "upgrade", "proxy-authenticate", "proxy-authorization",
        "te", "trailer",
        "access-control-allow-origin",
        "access-control-allow-headers",
        "access-control-allow-methods",
        "access-control-allow-credentials",
    }

    def _write_cors(self) -> None:
        # Permissive CORS so the live tether at kody-w.github.io can
        # post + preflight. Brainstem already has flask_cors, but the
        # proxy strips upstream CORS so we apply our own consistently.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS, PUT, DELETE, PATCH")
        self.send_header("Access-Control-Max-Age", "86400")

    def do_OPTIONS(self) -> None:  # CORS preflight
        self.send_response(204)
        self._write_cors()
        self.end_headers()

    def _proxy(self) -> None:
        body = None
        clen = self.headers.get("Content-Length")
        if clen:
            try:
                body = self.rfile.read(int(clen))
            except Exception as e:
                self.send_response(400)
                self._write_cors()
                self.end_headers()
                self.wfile.write(f"read body: {e}".encode())
                return
        url = self.target + self.path
        req = urllib.request.Request(url, data=body, method=self.command)
        for h in self.headers:
            if h.lower() in self.HOP:
                continue
            req.add_header(h, self.headers[h])
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                self.send_response(r.status)
                for h, v in r.headers.items():
                    if h.lower() in self.HOP:
                        continue
                    self.send_header(h, v)
                self._write_cors()
                self.end_headers()
                self.wfile.write(r.read())
        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            for h, v in e.headers.items():
                if h.lower() in self.HOP:
                    continue
                self.send_header(h, v)
            self._write_cors()
            self.end_headers()
            try:
                self.wfile.write(e.read())
            except Exception:
                pass
        except urllib.error.URLError as e:
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self._write_cors()
            self.end_headers()
            self.wfile.write(
                f'{{"error":"brainstem at {self.target} unreachable: '
                f'{e.reason}. Is `./start.sh` running?"}}'.encode()
            )
        except Exception as e:
            self.send_response(502)
            self.send_header("Content-Type", "text/plain")
            self._write_cors()
            self.end_headers()
            self.wfile.write(f"proxy error: {e}".encode())

    # Wire every HTTP method through the same proxy path. Flask + the
    # brainstem use POST /chat, GET /agents, GET /voice/toggle etc;
    # this covers them all.
    do_GET   = _proxy
    do_POST  = _proxy
    do_PUT   = _proxy
    do_PATCH = _proxy
    do_DELETE = _proxy

    def log_message(self, fmt, *args) -> None:
        sys.stdout.write(f"[tls_proxy] {fmt % args}\n")
        sys.stdout.flush()


# ────────────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port",   type=int, default=int(os.environ.get("TLS_PORT", "7072")),
                    help="HTTPS port to listen on (default 7072 / env TLS_PORT)")
    ap.add_argument("--target", default=os.environ.get("BRAINSTEM_URL", "http://localhost:7071"),
                    help="Upstream brainstem URL (default http://localhost:7071 / env BRAINSTEM_URL)")
    args = ap.parse_args()

    ensure_cert()

    ProxyHandler.target = args.target.rstrip("/")

    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(certfile=str(CERT), keyfile=str(KEY))

    server = http.server.ThreadingHTTPServer(("0.0.0.0", args.port), ProxyHandler)
    server.socket = ctx.wrap_socket(server.socket, server_side=True)

    print(f"\n🔒 RAPP brainstem TLS proxy")
    print(f"   listening:  https://localhost:{args.port}")
    print(f"   target:     {args.target}")
    print(f"   cert:       {CERT}")
    print(f"   key:        {KEY}\n")
    print(f"FIRST RUN: visit https://localhost:{args.port}/ in the browser")
    print(f"you'll use the tether from, click 'Advanced' →")
    print(f"'Proceed to localhost (unsafe)'. After that, the browser remembers")
    print(f"the trust and the live tether's '🌐 Ground' button works against")
    print(f"https://localhost:{args.port}/chat.\n")
    print(f"Stop with Ctrl-C.\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[tls_proxy] shutting down")
        return 0


if __name__ == "__main__":
    sys.exit(main())
