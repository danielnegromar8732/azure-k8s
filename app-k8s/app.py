import os
from http.server import BaseHTTPRequestHandler, HTTPServer

DATA_DIR = "/data"
COUNTER_FILE = os.path.join(DATA_DIR, "contador.txt")

def leer_contador() -> int:
    try:
        with open(COUNTER_FILE) as f:
            return int(f.read().strip() or "0")
    except (FileNotFoundError, ValueError):
        return 0

def guardar_contador(valor: int) -> None:
    os.makedirs(DATA_DIR, exist_ok=True)
    with open(COUNTER_FILE, "w") as f:
        f.write(str(valor))

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/":
            self.send_response(404)
            self.end_headers()
            return

        valor = leer_contador() + 1
        guardar_contador(valor)

        cuerpo_html = f"""
        <!DOCTYPE html>
        <html lang="es">
        <head>
            <meta charset="UTF-8">
            <title>Caso Práctico 2 - App Kubernetes</title>
            <style>
                body {{ font-family: sans-serif; background: #0d1b2a; color: #e0e1dd; text-align: center; padding-top: 10vh; }}
                h1 {{ color: #4cc9f0; }}
            </style>
        </head>
        <body>
            <h1>Contador de visitas: {valor}</h1>
            <p>Los datos persisten en el volumen.</p>
        </body>
        </html>
        """

        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(cuerpo_html.encode("utf-8"))

if __name__ == "__main__":
    print("App escuchando en :8080", flush=True)
    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
