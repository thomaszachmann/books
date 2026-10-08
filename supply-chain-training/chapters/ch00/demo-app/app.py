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


if __name__ == "__main__":
    # Nur für lokale Tests. Im Container startet gunicorn die App.
    app.run(host="127.0.0.1", port=8000)
