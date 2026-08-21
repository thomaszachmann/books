#!/usr/bin/env python3
"""A back-channel logout receiver that does nothing but show its post.

Chapter 9. Keycloak sends a logout token here; this prints it so you can
decode it. A real application would verify the signature, find the
session by its `sid`, and end it.

Deliberately about forty lines: back-channel logout is not complicated,
it is merely one more endpoint that has to exist.
"""
import http.server
import urllib.parse

PORT = 8000
seen = []


class Sink(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n).decode()
        form = urllib.parse.parse_qs(body)
        token = form.get("logout_token", [body])[0]
        seen.append(token)
        print(f"--- logout token #{len(seen)} ---", flush=True)
        print(token, flush=True)
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        # /last returns the most recent token, so the lab can pipe it
        if self.path == "/last" and seen:
            payload = seen[-1].encode()
            self.send_response(200)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"logout sink listening on {PORT}", flush=True)
    http.server.HTTPServer(("", PORT), Sink).serve_forever()
