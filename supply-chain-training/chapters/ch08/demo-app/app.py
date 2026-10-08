"""Minimale Demo-Anwendung für das Lieferketten-Labor."""
import os

from flask import Flask, jsonify

app = Flask(__name__)
APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")


@app.get("/")
def index():
    """Einfacher Lebenszeichen-Endpunkt."""
    return jsonify(status="ok")


@app.get("/version")
def version():
    """Gibt die ausgelieferte Version zurück."""
    return jsonify(version=APP_VERSION)


import subprocess
from flask import request


@app.route("/ping")
def ping():
    host = request.args.get("host", "127.0.0.1")
    # ABSICHTLICH UNSICHER - nur fuer das Lab!
    out = subprocess.run(
        f"ping -c 1 {host}", shell=True, capture_output=True, text=True
    )
    return {"output": out.stdout}


if __name__ == "__main__":
    # Nur für lokale Tests. Im Container startet gunicorn die App.
    app.run(host="127.0.0.1", port=8000)
