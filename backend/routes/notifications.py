# backend/routes/notifications.py
from fastapi import APIRouter, HTTPException
from db.database import get_db_connection
from models.notification import Notification, NotificationCreate
from typing import List
from datetime import datetime

router = APIRouter()

def generate_excerpt(content: str) -> str:
    c = (content or "").strip()
    return (c.split('.', 1)[0] + '.') if '.' in c else c

@router.get("/notifications", response_model=List[Notification])
def get_notifications():
    """
    Zwraca tylko wysłane (sent=1) i już zaplanowane (scheduled_time <= NOW()) powiadomienia.
    Aliasujemy leading_image -> leadingImage, żeby zgadzało się z modelem Pydantic i frontendem.
    Używamy MySQL NOW() zamiast manipulacji strefą w Pythonie.
    """
    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)
        cur.execute("""
            SELECT
                id,
                title,
                content,
                excerpt,
                leading_image AS leadingImage,
                scheduled_time,
                sent
            FROM notificationsigora
            WHERE scheduled_time <= NOW() AND sent = 1
            ORDER BY scheduled_time DESC
            LIMIT 100
        """)
        rows = cur.fetchall()
        return rows
    finally:
        try:
            cur.close()
        except Exception:
            pass
        conn.close()

@router.post("/notifications", response_model=Notification)
def create_notification(notification: NotificationCreate):
    """
    Tworzy nowe powiadomienie. Zapisuje do kolumny leading_image (snake_case).
    Zwraca rekord z aliasem leadingImage, by pasował do modelu Pydantic.
    """
    excerpt = generate_excerpt(notification.content)

    conn = get_db_connection()
    try:
        cur = conn.cursor(dictionary=True)

        sql = """
            INSERT INTO notificationsigora
                (title, content, excerpt, leading_image, scheduled_time, sent)
            VALUES (%s, %s, %s, %s, %s, %s)
        """
        values = (
            notification.title,
            notification.content,
            excerpt,
            notification.leadingImage,     # w Pythonie camelCase…
            notification.scheduled_time,   # …w DB zapisujemy do leading_image
            False
        )
        cur.execute(sql, values)
        conn.commit()

        inserted_id = cur.lastrowid

        # Zwracamy z aliasem leadingImage (camelCase), żeby pasowało do response_model
        cur.execute("""
            SELECT
                id,
                title,
                content,
                excerpt,
                leading_image AS leadingImage,
                scheduled_time,
                sent
            FROM notificationsigora
            WHERE id = %s
        """, (inserted_id,))
        new_notification = cur.fetchone()

        if not new_notification:
            raise HTTPException(status_code=500, detail="Nie udało się dodać powiadomienia")

        return new_notification

    finally:
        try:
            cur.close()
        except Exception:
            pass
        conn.close()
