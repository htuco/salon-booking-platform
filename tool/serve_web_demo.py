#!/usr/bin/env python3
"""Servira Flutter web build sa SPA fallbackom, na svim interfejsima.

Postoji zbog dvije stvari koje `python -m http.server` ne radi:

- **SPA fallback.** Adresa kao `/appointments?status=pending` nema svoj fajl na disku, pa
  osnovni server vraća 404 — a upravo se na toj adresi provjerava da filter preživi refresh.
- **Pristup sa telefona.** Veže se na `0.0.0.0`, pa se isti build otvara i sa telefona na
  istoj mreži.

    python tool/serve_web_demo.py apps/admin/build/live-admin 4320

Nije production posluživanje: bez HTTPS-a, bez keša, bez ikakve autorizacije.
"""
import functools
import http.server
import os
import socket
import socketserver
import sys


class SpaHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):  # noqa: N802 - ime dolazi iz stdlib-a
        putanja = self.translate_path(self.path.split("?")[0])
        if not os.path.exists(putanja) or (
            os.path.isdir(putanja)
            and not os.path.exists(os.path.join(putanja, "index.html"))
        ):
            self.path = "/index.html"
        return super().do_GET()

    def log_message(self, *_):
        pass


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    direktorij = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 4320

    socketserver.TCPServer.allow_reuse_address = True
    handler = functools.partial(SpaHandler, directory=direktorij)
    with socketserver.TCPServer(("0.0.0.0", port), handler) as server:
        ip = socket.gethostbyname(socket.gethostname())
        print(f"Racunar:  http://localhost:{port}/")
        print(f"Telefon:  http://{ip}:{port}/   (ista Wi-Fi mreza)")
        server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
