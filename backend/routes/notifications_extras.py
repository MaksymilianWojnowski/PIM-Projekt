# backend/routes/notifications_extras.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import pymysql
import os

router = APIRouter()

def db():
    return pymysql.connect(
        host=os.getenv("DB_HOST","127.0.0.1"),
        user=os.getenv("DB_USER","root"),
        password=os.getenv("DB_PASSWORD",""),
        database=os.getenv("DB_NAME","notificationsdawidproba"),
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
        charset="utf8mb4"
    )

# ----------------- ANKIETY -----------------

class CreatePollBody(BaseModel):
    question: str
    options: List[str]

@router.post("/{notification_id}/poll/create")
def create_poll(notification_id: int, body: CreatePollBody):
    if not body.options or len(body.options) < 2:
        raise HTTPException(400, "Min. 2 opcje")
    with db().cursor() as cur:
        cur.execute("INSERT INTO polls (notification_id, question) VALUES (%s,%s)",
                    (notification_id, body.question))
        poll_id = cur.lastrowid
        cur.executemany("INSERT INTO poll_options (poll_id, text) VALUES (%s,%s)",
                        [(poll_id, t) for t in body.options])
    return {"poll_id": poll_id}

class VoteBody(BaseModel):
    option_id: int
    voter_email: str  # podaj email zalogowanego użytkownika

@router.post("/{notification_id}/poll/vote")
def vote(notification_id: int, body: VoteBody):
    with db().cursor() as cur:
        cur.execute("SELECT id FROM polls WHERE notification_id=%s AND is_active=1", (notification_id,))
        poll = cur.fetchone()
        if not poll:
            raise HTTPException(404, "Brak aktywnej ankiety")
        poll_id = poll["id"]
        cur.execute("SELECT id FROM poll_options WHERE id=%s AND poll_id=%s", (body.option_id, poll_id))
        if not cur.fetchone():
            raise HTTPException(400, "Zła opcja")
        cur.execute(
            "INSERT INTO poll_votes (poll_id, option_id, voter_email) VALUES (%s,%s,%s) "
            "ON DUPLICATE KEY UPDATE option_id=VALUES(option_id)",
            (poll_id, body.option_id, body.voter_email)
        )
    return {"ok": True}

@router.get("/{notification_id}/poll/results")
def poll_results(notification_id: int):
    with db().cursor() as cur:
        cur.execute("SELECT id, question FROM polls WHERE notification_id=%s AND is_active=1", (notification_id,))
        poll = cur.fetchone()
        if not poll:
            return {"poll": None}
        cur.execute("""
            SELECT o.id, o.text, COUNT(v.id) AS votes
            FROM poll_options o
            LEFT JOIN poll_votes v ON v.option_id=o.id
            WHERE o.poll_id=%s
            GROUP BY o.id, o.text
            ORDER BY o.id
        """, (poll["id"],))
        options = cur.fetchall()
        total = sum(x["votes"] for x in options)
    return {"poll": {"id": poll["id"], "question": poll["question"], "total": total, "options": options}}

# ----------------- KOMENTARZE -----------------

class NewComment(BaseModel):
    author_name: str
    author_email: Optional[str] = None
    content: str

@router.post("/{notification_id}/comments")
def add_comment(notification_id: int, body: NewComment):
    if not body.content.strip():
        raise HTTPException(400, "Treść komentarza pusta")
    with db().cursor() as cur:
        cur.execute("""
          INSERT INTO comments (notification_id, author_name, author_email, content)
          VALUES (%s,%s,%s,%s)
        """, (notification_id, body.author_name, body.author_email, body.content))
        cid = cur.lastrowid
    return {"id": cid}

@router.get("/{notification_id}/comments")
def list_comments(notification_id: int, limit: int = 50, offset: int = 0):
    with db().cursor() as cur:
        cur.execute("""
          SELECT c.id, c.author_name, c.author_email, c.content, c.created_at,
                 COALESCE(SUM(cv.value),0) AS score,
                 SUM(CASE WHEN cv.value=1 THEN 1 ELSE 0 END) AS upvotes,
                 SUM(CASE WHEN cv.value=-1 THEN 1 ELSE 0 END) AS downvotes
          FROM comments c
          LEFT JOIN comment_votes cv ON cv.comment_id=c.id
          WHERE c.notification_id=%s
          GROUP BY c.id
          ORDER BY c.created_at DESC
          LIMIT %s OFFSET %s
        """, (notification_id, limit, offset))
        rows = cur.fetchall()
    return {"items": rows}

class VoteCommentBody(BaseModel):
    voter_email: str
    value: int  # +1 lub -1

@router.post("/comments/{comment_id}/vote")
def vote_comment(comment_id: int, body: VoteCommentBody):
    if body.value not in (1, -1):
        raise HTTPException(400, "value musi być +1 lub -1")
    with db().cursor() as cur:
        cur.execute("SELECT id FROM comments WHERE id=%s", (comment_id,))
        if not cur.fetchone():
            raise HTTPException(404, "Brak komentarza")
        cur.execute(
            "INSERT INTO comment_votes (comment_id, voter_email, value) VALUES (%s,%s,%s) "
            "ON DUPLICATE KEY UPDATE value=VALUES(value)",
            (comment_id, body.voter_email, body.value)
        )
    return {"ok": True}
