import sqlite3
from core.dbManager import get_db


def test_get_db():
    db = get_db()
    assert isinstance(db, sqlite3.Connection)
    db.close()


if __name__ == "__main__":
    test_get_db()
    print("test_get_db passed!")
