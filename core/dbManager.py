import os
import sqlite3
from pathlib import Path

DB_URL=os.path.join(Path.home(),'/.kvStudio/','studio.sqlite')
print(DB_URL)
TABLES_SCRIPTS=[
    {
        'name':'history',
        'script':"""
            CREATE TABLE IF NOT EXISTS "history" (
                "id"	INTEGER,
                "link"	TEXT,
                PRIMARY KEY("id" AUTOINCREMENT)
            )
        """
    },
    {
        'name':'currentproject',
        'script':"""
            CREATE TABLE IF NOT EXISTS "currentproject" (
                "id"	INTEGER NOT NULL UNIQUE,
                "url"	TEXT NOT NULL UNIQUE,
                PRIMARY KEY("id" AUTOINCREMENT)
            )
        """
    },
]

def connect_db():
    # RETURN A DB OBJECT
    return sqlite3.connect(DB_URL)

def create_db():
    # CREATE ALL DB TABLES

    db=connect_db()
    curs=db.cursor()
    created=False
    error=None

    try:
        for table in TABLES_SCRIPTS:
            curs.execute(table['script'])
        created=True
    except Exception as e:
        error=str(e)
    
    return created,error

def get_db():
    create_db()
    return connect_db()