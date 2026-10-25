import os, sqlite3
from pathlib import Path
from dotenv import load_dotenv
load_dotenv()
DB_PATH = os.getenv("DATABASE_PATH", "driveplus.db")

def connect():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA foreign_keys=ON")
    return con

def init_db():
    with connect() as c:
        c.executescript("""
        CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT,email TEXT UNIQUE NOT NULL,password_hash TEXT NOT NULL,full_name TEXT DEFAULT '',created_at TEXT DEFAULT CURRENT_TIMESTAMP);
        CREATE TABLE IF NOT EXISTS vehicles(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,brand TEXT NOT NULL,model TEXT NOT NULL,year INTEGER,registration_number TEXT NOT NULL,tank_capacity REAL,photo_uri TEXT DEFAULT '',created_at TEXT DEFAULT CURRENT_TIMESTAMP);
        CREATE TABLE IF NOT EXISTS reminders(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,vehicle_id INTEGER REFERENCES vehicles(id) ON DELETE CASCADE,title TEXT NOT NULL,due_date TEXT NOT NULL,category TEXT DEFAULT 'service',notes TEXT DEFAULT '',completed INTEGER DEFAULT 0);
        CREATE TABLE IF NOT EXISTS trips(id INTEGER PRIMARY KEY AUTOINCREMENT,user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,origin TEXT NOT NULL,destination TEXT NOT NULL,distance_km REAL NOT NULL,fuel_efficiency REAL NOT NULL,fuel_price REAL NOT NULL,estimated_cost REAL NOT NULL,created_at TEXT DEFAULT CURRENT_TIMESTAMP);
        """)
