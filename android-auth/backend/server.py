"""Minimal PGS OpenID exchange reference, not a production account/save service.

Run behind HTTPS with a rate-limiting reverse proxy. Secrets are server environment
variables; never put them in the APK, repository, request or logs.
"""
import hashlib
import os
import secrets
import threading
import time
from uuid import UUID

import requests
from flask import Flask, jsonify, request
from google.auth.transport.requests import Request
from google.oauth2 import id_token

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 8192
_sessions = {}
_lock = threading.Lock()
SESSION_TTL = 3600


class BoundedGoogleRequest(Request):
    def __call__(self, *args, **kwargs):
        kwargs["timeout"] = (5, 10)
        return super().__call__(*args, **kwargs)


def verify_code(code):
    client_id = os.environ["GOOGLE_WEB_CLIENT_ID"]
    response = requests.post(
        "https://oauth2.googleapis.com/token",
        data={"client_id": client_id,
              "client_secret": os.environ["GOOGLE_WEB_CLIENT_SECRET"],
              "code": code, "grant_type": "authorization_code", "redirect_uri": ""},
        timeout=(5, 10), allow_redirects=False)
    if response.status_code != 200:
        raise ValueError("Exchange rejected")
    data = response.json()
    # OPEN_ID can be declined independently. A PGS access token/player ID is NOT an IGA identity.
    encoded = data.get("id_token")
    if not isinstance(encoded, str) or not encoded:
        raise ValueError("OpenID not granted")
    claims = id_token.verify_oauth2_token(encoded, BoundedGoogleRequest(), audience=client_id)
    # The official verifier checks signature, expiry, issuer, and audience.
    # Hybrid Android/Web tokens may name the Android client as presenter (azp).
    # Only project-owned Android client IDs may be added to this server allowlist.
    allowed_presenters = {client_id} | {value.strip() for value in os.environ.get("GOOGLE_ANDROID_CLIENT_IDS", "").split(",") if value.strip()}
    if claims.get("azp", client_id) not in allowed_presenters:
        raise ValueError("Unexpected authorized party")
    subject = claims.get("sub")
    if not isinstance(subject, str) or not 1 <= len(subject) <= 255:
        raise ValueError("Missing subject")
    # No Google access/refresh/ID tokens are retained by this identity-only sample.
    return subject


@app.after_request
def no_cache(response):
    response.headers["Cache-Control"] = "no-store"
    response.headers["Pragma"] = "no-cache"
    return response


@app.post("/auth/google")
def google_login():
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        return jsonify(error="invalid_request"), 400
    code, request_id = body.get("auth_code"), body.get("request_id")
    if not isinstance(code, str) or not 1 <= len(code) <= 4096 or not isinstance(request_id, str):
        return jsonify(error="invalid_request"), 400
    try:
        UUID(request_id)
    except (ValueError, TypeError):
        return jsonify(error="invalid_request"), 400
    try:
        subject = verify_code(code)
    except (ValueError, requests.RequestException):
        return jsonify(error="verification_failed"), 401
    except Exception:
        # Deliberately no exception/request logging; provider responses can contain credentials.
        return jsonify(error="service_unavailable"), 503
    token = secrets.token_urlsafe(32)
    digest = hashlib.sha256(token.encode()).hexdigest()
    now = time.time()
    with _lock:
        for old in list(_sessions):
            if _sessions[old][1] <= now:
                del _sessions[old]
        _sessions[digest] = (subject, now + SESSION_TTL)
    return jsonify(subject=subject, session_token=token, expires_in=SESSION_TTL, request_id=request_id)


@app.post("/auth/google/logout")
def logout():
    scheme, _, token = request.headers.get("Authorization", "").partition(" ")
    if scheme != "Bearer" or not token or len(token) > 4096:
        return jsonify(error="invalid_request"), 400
    with _lock:
        _sessions.pop(hashlib.sha256(token.encode()).hexdigest(), None)
    return jsonify(ok=True)


if __name__ == "__main__":
    if not os.environ.get("GOOGLE_WEB_CLIENT_ID") or not os.environ.get("GOOGLE_WEB_CLIENT_SECRET"):
        raise SystemExit("Set GOOGLE_WEB_CLIENT_ID and GOOGLE_WEB_CLIENT_SECRET on the server first")
    app.run(host="127.0.0.1", port=8080, debug=False)
