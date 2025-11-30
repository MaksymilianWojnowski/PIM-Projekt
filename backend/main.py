from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from routes import notifications
from routes.notifications import get_notifications
from scheduler import start_scheduler
from routes import notifications_extras 

from auth.google_auth import verify_google_token, is_user_in_db

import os
import json
import base64
import time
from typing import Any, Dict

app = FastAPI()

# CORS (opcjonalnie zostawiam szeroko)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Start scheduler (wysyłka FCM)
start_scheduler()

# REST dla powiadomień
app.include_router(notifications.router)

app.include_router(notifications_extras.router, prefix="/notifications", tags=["extras"])

# ──────────────────────────────────────────────────────────────────────────────
# Pomocnicze: tylko do logów – podgląd payloadu JWT bez weryfikacji
def _b64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)

def peek_jwt_payload(id_token: str) -> Dict[str, Any]:
    try:
        parts = id_token.split(".")
        if len(parts) != 3:
            return {"_error": "token_parts_invalid"}
        payload_raw = _b64url_decode(parts[1])
        return json.loads(payload_raw.decode("utf-8"))
    except Exception as e:
        return {"_error": f"peek_error: {e}"}
# ──────────────────────────────────────────────────────────────────────────────


@app.get("/auth/google")
def auth_google(token: str):
    # 1) Log wejściowy
    print("──────────── /auth/google ────────────")
    print(f"🔐 Otrzymany token (first 24): {token[:24]}...")

    # 2) Log ENV
    client_id = os.getenv("GOOGLE_CLIENT_ID", "")
    masked = (client_id[:12] + "...") if client_id else "<EMPTY>"
    print(f"🧩 GOOGLE_CLIENT_ID (backend .env) = {masked}")

    if not client_id:
        print("❗ Brak GOOGLE_CLIENT_ID w środowisku backendu (.env)!")
        raise HTTPException(status_code=500, detail="Server misconfigured: missing GOOGLE_CLIENT_ID")

    # 3) Podgląd payloadu (bez weryfikacji) – ułatwia diagnostykę aud/azp/email
    peek = peek_jwt_payload(token)
    aud = peek.get("aud")
    azp = peek.get("azp")
    email_claim = peek.get("email")
    iat = peek.get("iat")
    exp = peek.get("exp")
    now = int(time.time())
    print(f"🔎 JWT peek: aud={aud} | azp={azp} | email={email_claim} | iat={iat} | exp={exp} | now={now}")

    # 4) Faktyczna weryfikacja tokena (podpis + audience)
    try:
        email = verify_google_token(token)   # powinno zwrócić e-mail lub None
        if not email:
            print("❌ Weryfikacja nie powiodła się: verify_google_token zwrócił None")
            raise HTTPException(status_code=401, detail="Invalid Google token")
        print(f"✅ Weryfikacja tokena OK. email={email}")
    except HTTPException:
        # już zlogowane wyżej
        raise
    except Exception as e:
        print(f"❌ Wyjątek podczas weryfikacji tokena: {e}")
        raise HTTPException(status_code=401, detail="Invalid Google token")

    # 5) Autoryzacja po e-mailu (whitelista w DB)
    try:
        if is_user_in_db(email):
            print("✅ Email znajduje się w bazie (whitelist) – logowanie zaakceptowane")
            return {"status": "success", "email": email}
        else:
            print("⛔ Email NIE znajduje się w bazie – odrzucam (403)")
            raise HTTPException(status_code=403, detail="Unauthorized user")
    finally:
        print("──────────── /auth/google [END] ──────")


@app.get("/notifications")
def read_notifications():
    return get_notifications()
