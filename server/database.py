# database.py
# Shared database and auth functions used by all route files

import sqlite3
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

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

# ─────────────────────────────────────────
# DATABASE
# ─────────────────────────────────────────
def get_db():
    conn = sqlite3.connect("attendance.db", check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

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
    user = conn.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    if user is None:
        raise credentials_exception
    return dict(user)

def require_role(*roles):
    def checker(current_user: dict = Depends(get_current_user)):
        if current_user["role"] not in roles:
            raise HTTPException(
                status_code=403,
                detail=f"Access denied. Required roles: {roles}"
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
    return "ATT:" + hmac.new(SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()[:12]

def validate_ble_token(token: str, slot_id: str) -> bool:
    for offset in [0, -1]:
        window = int(time.time() // BLE_TOKEN_WINDOW) + offset
        message = f"{slot_id}:{window}".encode()
        expected = "ATT:" + hmac.new(SECRET_KEY.encode(), message, hashlib.sha256).hexdigest()[:12]
        if token == expected:
            return True
    return False
