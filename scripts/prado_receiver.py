#!/usr/bin/env python3
"""Saves specimen images posted by scripts/prado_collect.js from a PRADO page in the browser.

    python3 -I scripts/prado_receiver.py [Fixtures/specimens/prado]

Listens on 127.0.0.1:8765 only and writes nothing but files with plain names ending in .jpg or
.json into the output folder. The browser will ask once whether the PRADO site may reach a device on
the local network; that is this receiver. See docs/SPECIMENS.md.
"""
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

OUT = sys.argv[1] if len(sys.argv) > 1 else "Fixtures/specimens/prado"
os.makedirs(OUT, exist_ok=True)


class Handler(BaseHTTPRequestHandler):
    def cors(self):
        self.send_header("Access-Control-Allow-Origin", "https://www.consilium.europa.eu")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Private-Network", "true")

    def do_OPTIONS(self):
        self.send_response(204)
        self.cors()
        self.end_headers()

    def do_POST(self):
        name = parse_qs(urlparse(self.path).query).get("name", [""])[0]
        if not re.fullmatch(r"[A-Za-z0-9_.-]{3,80}\.(jpg|json)", name):
            self.send_response(400)
            self.cors()
            self.end_headers()
            return
        data = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if len(data) > 8_000_000:
            self.send_response(413)
            self.cors()
            self.end_headers()
            return
        with open(os.path.join(OUT, name), "wb") as f:
            f.write(data)
        self.send_response(200)
        self.cors()
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"Saving to {OUT}; listening on 127.0.0.1:8765")
    HTTPServer(("127.0.0.1", 8765), Handler).serve_forever()
