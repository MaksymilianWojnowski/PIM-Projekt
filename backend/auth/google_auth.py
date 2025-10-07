# auth/google_auth.py
import os
import logging
from typing import Optional
from google.oauth2 import id_token
from google.auth.transport import requests as g_requests
import mysql.connector
from db.database import get_db_connection

logger = logging.getLogger("auth.google_auth")

WEB_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID")  # musi być WEB CLIENT ID (z GCP → OAuth client: Web)

def verify_google_token(token: str) -> Optional[str]:
    """
    Zwraca email z prawidłowego idToken albo None.
    Weryfikujemy kryptograficznie token u Google, a potem ręcznie sprawdzamy aud==WEB_CLIENT_ID.
    """
    logger.info("🧪 Próba weryfikacji tokena Google")
    if not WEB_CLIENT_ID:
        logger.error("❗ Brak GOOGLE_CLIENT_ID w env (powinien być WEB CLIENT ID)!")
        return None

    try:
        # 1) Weryfikacja podpisu i poprawności tokena (bez podawania audience).
        idinfo = id_token.verify_oauth2_token(token, g_requests.Request())

        aud = idinfo.get("aud")
        azp = idinfo.get("azp")
        email = idinfo.get("email")

        logger.info(f"🔎 Token payload: aud={aud} | azp={azp} | email={email}")

        # 2) Ręczny check: aud musi być naszym WEB CLIENT ID (tym samym, który ustawiłeś w front/back)
        if aud != WEB_CLIENT_ID:
            logger.error(f"❌ Wrong audience. expected={WEB_CLIENT_ID}, got={aud}")
            return None

        # (opcjonalnie) możesz sprawdzić również iss
        iss = idinfo.get("iss")
        if iss not in ("https://accounts.google.com", "accounts.google.com"):
            logger.error(f"❌ Invalid issuer: {iss}")
            return None

        # (opcjonalnie) sprawdź email_verified
        if not idinfo.get("email_verified", False):
            logger.error("❌ Email niezweryfikowany przez Google")
            return None

        return email

    except Exception as e:
        logger.error(f"❌ Błąd weryfikacji tokena: {e}")
        return None


def is_user_in_db(email: str) -> bool:
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT 1 FROM users WHERE email=%s LIMIT 1", (email,))
            return cur.fetchone() is not None
    finally:
        conn.close()
