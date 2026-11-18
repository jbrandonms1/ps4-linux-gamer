#!/usr/bin/env python3
# Sirve setup-arch.sh (GET /s) y archivos de ~/ps4linux; recibe logs por PUT /log.
import http.server, os, time
ROOT = os.path.dirname(os.path.abspath(__file__))
os.makedirs(os.path.join(ROOT, "logs"), exist_ok=True)

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)
    def do_GET(self):
        if self.path == "/s":
            self.path = "/setup-arch.sh"
        return super().do_GET()
    def do_PUT(self):
        n = int(self.headers.get("Content-Length", 0))
        data = self.rfile.read(n)
        name = os.path.basename(self.path)
        if name.endswith((".png", ".jpg")):          # capturas de pantalla
            p = os.path.join(ROOT, "logs", time.strftime("%H%M%S-") + name)
            with open(p, "wb") as f:
                f.write(data)
            self.send_response(201); self.end_headers()
            print("IMAGEN RECIBIDA", p, len(data), flush=True); return
        p = os.path.join(ROOT, "logs", time.strftime("ps4-%H%M%S.log"))
        with open(p, "wb") as f:
            f.write(data)
        with open(os.path.join(ROOT, "logs", "latest.log"), "wb") as f:
            f.write(data)
        self.send_response(201); self.end_headers()
        print("LOG RECIBIDO", p, len(data), flush=True)

http.server.ThreadingHTTPServer(("0.0.0.0", 8000), H).serve_forever()
