# backend/scheduler.py
from apscheduler.schedulers.background import BackgroundScheduler
from datetime import datetime
from typing import List, Optional

from db.database import get_db_connection
from google.oauth2 import service_account
from google.auth.transport.requests import Request
import requests

# === KONFIG ===
SERVICE_ACCOUNT_FILE = 'firebase-key.json'  # ścieżka do klucza z Firebase (Admin SDK)
PROJECT_ID = 'insert-powiadomienia-11f34'  # Twój project_id z Firebase/GCP
SCOPES = ['https://www.googleapis.com/auth/firebase.messaging']


def _get_access_token() -> str:
    """Pozyskaj access token do FCM HTTP v1 z konta serwisowego."""
    credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE, scopes=SCOPES
    )
    credentials.refresh(Request())
    return credentials.token


def send_fcm_notification(title: str, body: str, image: Optional[str] = None) -> int:
    """
    Wyślij notyfikację na temat 'all' przez FCM HTTP v1.
    Zwraca status code odpowiedzi HTTP.
    """
    access_token = _get_access_token()

    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json; charset=UTF-8',
    }

    notification = {
        "title": title,
        "body": body,
    }
    # Pole image jest opcjonalne – dodajemy je tylko gdy jest ustawione
    if image:
        notification["image"] = image

    message = {
        "message": {
            "topic": "all",
            "notification": notification,
            "data": {
                "click_action": "FLUTTER_NOTIFICATION_CLICK"
            }
        }
    }

    url = f'https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send'
    resp = requests.post(url, headers=headers, json=message, timeout=15)
    print(f"📤 Wysłano powiadomienie: '{title}' | HTTP {resp.status_code} | body={resp.text[:200]}")
    return resp.status_code


def update_and_send_notifications():
    """
    1) Pobiera zaległe rekordy (sent=0 i scheduled_time <= NOW()) z tabeli 'notificationsigora'
       – aliasuje 'leading_image' jako 'leadingImage', by pasowało do reszty kodu.
    2) Wysyła FCM dla każdego rekordu.
    3) Po sukcesie oznacza je jako sent=1.
    """
    print(f"⏰ Sprawdzam powiadomienia: {datetime.now()}")

    conn = get_db_connection()
    try:
        cursor = conn.cursor(dictionary=True)

        # Używamy NOW() po stronie MySQL, by uniknąć rozjazdów stref czasowych.
        cursor.execute("""
            SELECT
              id,
              title,
              content,
              excerpt,
              leading_image AS leadingImage,
              scheduled_time,
              sent
            FROM notificationsigora
            WHERE sent = 0 AND scheduled_time <= NOW()
            ORDER BY scheduled_time ASC
            LIMIT 100;
        """)
        rows = cursor.fetchall()

        if not rows:
            print("ℹ️ Brak zaległych powiadomień do wysyłki")
            return

        sent_ids: List[int] = []
        for notif in rows:
            nid = notif.get('id')
            title = notif.get('title') or ''
            body = notif.get('content') or ''
            image = notif.get('leadingImage')  # po aliasie zadziała także gdy kolumna to 'leading_image'
            try:
                status = send_fcm_notification(title, body, image)
                if 200 <= status < 300:
                    sent_ids.append(nid)
                else:
                    print(f"⚠️ Błąd HTTP przy wysyłce ID={nid}: status={status}")
            except Exception as e:
                print(f"❌ Wyjątek przy wysyłce ID={nid}: {e}")

        if sent_ids:
            # batchowe oznaczenie sent=1 tylko dla wysłanych
            fmt = ",".join(["%s"] * len(sent_ids))
            cursor.execute(f"UPDATE notificationsigora SET sent = 1 WHERE id IN ({fmt})", sent_ids)
            conn.commit()
            print(f"✅ Wysłano i zaktualizowano {len(sent_ids)} powiadomienie(a)")
        else:
            print("ℹ️ Nic nie wysłano w tej iteracji")
    finally:
        try:
            cursor.close()
        except Exception:
            pass
        conn.close()


def start_scheduler():
    scheduler = BackgroundScheduler()
    # wywołuj co minutę
    scheduler.add_job(update_and_send_notifications, 'interval', minutes=1)
    scheduler.start()
    print("🚀 Scheduler wystartował")
