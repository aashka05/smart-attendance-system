# database.py
# Shared database and auth functions used by all route files

import os
import psycopg2
from psycopg2 import pool, extras
import hmac
import hashlib
import time
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

# ─────────────────────────────────────────
# CONFIG
# ─────────────────────────────────────────
SECRET_KEY = "attendance_secret_key_change_in_production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24  # 24 hours
BLE_TOKEN_WINDOW = 300  # 5 minutes

DATABASE_URL = os.environ.get(
    "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/attendance"
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# ─────────────────────────────────────────
# DATABASE
# ─────────────────────────────────────────
db_pool = pool.SimpleConnectionPool(1, 10, DATABASE_URL)


class DBConnection:
    """Wrapper around psycopg2 connection that mimics sqlite3's conn.execute() API.

    This lets existing route code keep using:
        conn.execute(query, params).fetchone()
        conn.execute(query, params).fetchall()
        conn.commit()
        conn.close()
    without rewriting every call site to use explicit cursors.
    """

    def __init__(self, conn):
        self._conn = conn

    def execute(self, query, params=None):
        cur = self._conn.cursor(cursor_factory=extras.RealDictCursor)
        cur.execute(query, params)
        return cur

    def commit(self):
        self._conn.commit()

    def cursor(self):
        return self._conn.cursor(cursor_factory=extras.RealDictCursor)

    def close(self):
        """Return connection to pool instead of actually closing it."""
        try:
            self._conn.rollback()
        except Exception:
            pass
        db_pool.putconn(self._conn)


def get_db():
    conn = db_pool.getconn()
    conn.autocommit = False
    return DBConnection(conn)


def release_db(conn):
    """Alternative to conn.close() — returns connection to pool."""
    conn.close()


# ─────────────────────────────────────────
# AUTH HELPERS
# ─────────────────────────────────────────
def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    conn = get_db()
    user = conn.execute(
        "SELECT u.*, d.name AS department_name FROM users u LEFT JOIN departments d ON u.department_id = d.id WHERE u.id = %s",
        (user_id,),
    ).fetchone()
    conn.close()
    if user is None:
        raise credentials_exception
    return dict(user)


def require_role(*roles):
    def checker(current_user: dict = Depends(get_current_user)):
        if current_user["role"] not in roles:
            raise HTTPException(
                status_code=403, detail=f"Access denied. Required roles: {roles}"
            )
        if current_user["status"] != "approved":
            raise HTTPException(status_code=403, detail="Account pending approval")
        return current_user

    return checker


# ─────────────────────────────────────────
# BLE TOKEN HELPERS
# ─────────────────────────────────────────
def generate_ble_token(slot_id: str) -> str:
    window = int(time.time() // BLE_TOKEN_WINDOW)
    message = f"{slot_id}:{window}".encode()
    return (
        "ATT:" + hmac.new(SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()[:12]
    )


def validate_ble_token(token: str, slot_id: str) -> bool:
    for offset in [0, -1]:
        window = int(time.time() // BLE_TOKEN_WINDOW) + offset
        message = f"{slot_id}:{window}".encode()
        expected = (
            "ATT:"
            + hmac.new(SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()[:12]
        )
        if token == expected:
            return True
    return False
