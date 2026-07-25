from datetime import datetime, timedelta, timezone


BEIJING_TZ = timezone(timedelta(hours=8), name="Asia/Shanghai")


def beijing_now_iso() -> str:
    return datetime.now(BEIJING_TZ).isoformat()

