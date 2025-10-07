from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class Notification(BaseModel):
    id: int
    title: str
    content: str
    excerpt: Optional[str]
    leadingImage: Optional[str]
    scheduled_time: Optional[datetime]
    sent: bool

class NotificationCreate(BaseModel):
    title: str
    content: str
    leadingImage: Optional[str]
    scheduled_time: datetime
