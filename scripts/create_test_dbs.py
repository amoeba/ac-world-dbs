# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///

"""Create two test world databases with sample data."""

import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DB_DIR = ROOT / "databases"


def create_fauna_db() -> Path:
    DB_DIR.mkdir(exist_ok=True)
    path = DB_DIR / "test_world_fauna.db"
    path.unlink(missing_ok=True)

    conn = sqlite3.connect(path)
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE creatures (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            species TEXT,
            level INTEGER,
            health INTEGER,
            habitat TEXT,
            is_hostile INTEGER DEFAULT 0
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE spawns (
            id INTEGER PRIMARY KEY,
            creature_id INTEGER NOT NULL,
            location_x REAL,
            location_y REAL,
            location_z REAL,
            respawn_time INTEGER,
            FOREIGN KEY (creature_id) REFERENCES creatures(id)
        )
        """
    )

    creatures = [
        (1, "Gromnie", "Drake", 5, 80, "Eastham", 1),
        (2, "Drudge Prowler", "Drudge", 3, 45, "Holtburg", 1),
        (3, "White Rabbit", "Rabbit", 1, 10, "Shoushi", 0),
        (4, "Lich Lord", "Undead", 80, 2500, "Tou-Tou", 1),
        (5, "Auroch", "Bovine", 4, 60, "Rithwic", 0),
    ]
    cur.executemany(
        "INSERT INTO creatures VALUES (?, ?, ?, ?, ?, ?, ?)", creatures
    )

    spawns = [
        (1, 1, 12.5, 34.2, 0.0, 120),
        (2, 1, 15.0, 36.0, 0.0, 120),
        (3, 2, -10.0, 5.5, 0.0, 90),
        (4, 3, 0.0, 0.0, 0.0, 60),
        (5, 4, 100.0, -50.0, 2.0, 300),
        (6, 5, 22.0, 18.0, 0.0, 90),
    ]
    cur.executemany("INSERT INTO spawns VALUES (?, ?, ?, ?, ?, ?)", spawns)

    conn.commit()
    conn.close()
    return path


def create_landmarks_db() -> Path:
    DB_DIR.mkdir(exist_ok=True)
    path = DB_DIR / "test_world_landmarks.db"
    path.unlink(missing_ok=True)

    conn = sqlite3.connect(path)
    cur = conn.cursor()

    cur.execute(
        """
        CREATE TABLE regions (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            climate TEXT,
            danger_level INTEGER,
            description TEXT
        )
        """
    )

    cur.execute(
        """
        CREATE TABLE landmarks (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT,
            location_x REAL,
            location_y REAL,
            location_z REAL,
            region_id INTEGER,
            description TEXT,
            FOREIGN KEY (region_id) REFERENCES regions(id)
        )
        """
    )

    regions = [
        (1, "Holtburg", "Temperate", 1, "A starter town in the Aluvian lands."),
        (2, "Eastham", "Coastal", 2, "A small coastal village."),
        (3, "Tou-Tou", "Swamp", 5, "A dangerous swamp town."),
    ]
    cur.executemany("INSERT INTO regions VALUES (?, ?, ?, ?, ?)", regions)

    landmarks = [
        (1, "Holtburg Fountain", "Fountain", 10.0, 10.0, 0.0, 1, "The central fountain of Holtburg."),
        (2, "Eastham Lighthouse", "Lighthouse", 50.0, 50.0, 5.0, 2, "Guides ships along the coast."),
        (3, "Tou-Tou Temple", "Temple", -30.0, -30.0, 0.0, 3, "An ancient temple hidden in the swamp."),
        (4, "Holtburg Lifestone", "Lifestone", 12.0, 8.0, 0.0, 1, "Bind here to return quickly."),
    ]
    cur.executemany(
        "INSERT INTO landmarks VALUES (?, ?, ?, ?, ?, ?, ?, ?)", landmarks
    )

    conn.commit()
    conn.close()
    return path


def main() -> None:
    fauna = create_fauna_db()
    landmarks = create_landmarks_db()
    print(f"Created {fauna}")
    print(f"Created {landmarks}")


if __name__ == "__main__":
    main()
