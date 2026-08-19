#!/usr/bin/env bash
# A webhook receiver that does the one thing a webhook receiver must do:
# answer immediately.
#
# Harbor allows three seconds and three attempts. A receiver that works
# before it responds gets retried, then dropped, and Harbor does not
# tell you it gave up. This one acknowledges first and prints after.
#
#   ./webhook-listen.sh 9000
set -euo pipefail
PORT="${1:-9000}"
echo "listening on :$PORT - point a webhook policy here, ^C to stop"
exec python3 - "$PORT" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer

class H(BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get("content-length", 0))
        body = self.rfile.read(n)
        # Acknowledge before doing anything at all.
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")
        try:
            d = json.loads(body)
        except ValueError:
            print(body.decode("utf-8", "replace")); return
        # CloudEvents carries type/id/operator at the top level; the
        # default format does not, which is the reason to prefer it.
        t = d.get("type") or d.get("event_type") or "?"
        op = d.get("operator", "?")
        print(f"--- {t}  operator={op}")
        print(json.dumps(d, indent=2, sort_keys=True))
        sys.stdout.flush()

    def log_message(self, *a):
        pass

HTTPServer(("", int(sys.argv[1])), H).serve_forever()
PY
