# divisions_routes.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
import uuid
from database import get_db, get_current_user, require_role

router = APIRouter()


class DivisionCreate(BaseModel):
    number: int
    name: str
    department_id: str


class DivisionUpdate(BaseModel):
    number: Optional[int] = None
    name: Optional[str] = None


def init_divisions_db():
    conn = get_db()
    c = conn.cursor()

    c.execute("""
        CREATE TABLE IF NOT EXISTS divisions (
            id TEXT PRIMARY KEY,
            number INTEGER NOT NULL,
            name TEXT NOT NULL,
            department_id TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT NOW(),
            FOREIGN KEY (department_id) REFERENCES departments(id)
        )
    """)

    conn.commit()
    conn.close()


init_divisions_db()


@router.get("/divisions")
def get_divisions(
    department_id: Optional[str] = None, current_user: dict = Depends(get_current_user)
):
    conn = get_db()
    if department_id:
        divisions = conn.execute(
            """
            SELECT dv.*, d.name as department_name
            FROM divisions dv
            LEFT JOIN departments d ON dv.department_id = d.id
            WHERE dv.department_id = %s
            ORDER BY dv.number
        """,
            (department_id,),
        ).fetchall()
    else:
        divisions = conn.execute("""
            SELECT dv.*, d.name as department_name
            FROM divisions dv
            LEFT JOIN departments d ON dv.department_id = d.id
            ORDER BY dv.number
        """).fetchall()
    conn.close()
    return [dict(d) for d in divisions]


@router.post("/divisions")
def create_division(
    req: DivisionCreate, current_user: dict = Depends(require_role("admin"))
):
    conn = get_db()
    div_id = str(uuid.uuid4())
    try:
        conn.execute(
            """
            INSERT INTO divisions (id, number, name, department_id)
            VALUES (%s, %s, %s, %s)
        """,
            (div_id, req.number, req.name, req.department_id),
        )
        conn.commit()
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=400, detail=str(e))
    conn.close()
    return {"id": div_id, "message": "Division created"}


@router.put("/divisions/{div_id}")
def update_division(
    div_id: str,
    req: DivisionUpdate,
    current_user: dict = Depends(require_role("admin")),
):
    conn = get_db()
    division = conn.execute(
        "SELECT * FROM divisions WHERE id = %s", (div_id,)
    ).fetchone()
    if not division:
        conn.close()
        raise HTTPException(status_code=404, detail="Division not found")

    number = req.number if req.number is not None else division["number"]
    name = req.name if req.name is not None else division["name"]

    conn.execute(
        "UPDATE divisions SET number = %s, name = %s WHERE id = %s",
        (number, name, div_id),
    )
    conn.commit()
    conn.close()
    return {"message": "Division updated"}


@router.delete("/divisions/{div_id}")
def delete_division(div_id: str, current_user: dict = Depends(require_role("admin"))):
    conn = get_db()
    conn.execute("DELETE FROM divisions WHERE id = %s", (div_id,))
    conn.commit()
    conn.close()
    return {"message": "Division deleted"}
