"""
Database Hydration Script
Populates the PostgreSQL database with users and tasks tables.
Run as a Kubernetes Job after PostgreSQL is ready.
"""
import os
import time
import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT

DB_CONFIG = {
    "host": os.environ.get("POSTGRES_HOST", "postgres"),
    "port": int(os.environ.get("POSTGRES_PORT", 5432)),
    "dbname": os.environ.get("POSTGRES_DB", "aiops"),
    "user": os.environ.get("POSTGRES_USER", "aiops_user"),
    "password": os.environ.get("POSTGRES_PASSWORD", "aiops_pass_dev"),
}

SCHEMA_SQL = """
-- Enable pgcrypto for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Tasks table
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    status VARCHAR(20) DEFAULT 'pending',
    priority INTEGER DEFAULT 3 CHECK (priority BETWEEN 1 AND 5),
    assigned_to INTEGER REFERENCES users(id),
    due_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Index for task lookups by user
CREATE INDEX IF NOT EXISTS idx_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status);
"""

SEED_USERS = [
    ("alice", "alice@example.com", "password123"),
    ("bob", "bob@example.com", "password123"),
    ("charlie", "charlie@example.com", "password123"),
    ("diana", "diana@example.com", "password123"),
    ("eve", "eve@example.com", "password123"),
]

SEED_TASKS = [
    # (title, description, status, priority, assigned_to_username, due_date)
    ("Deploy monitoring stack", "Set up Prometheus and Grafana for cluster observability", "in_progress", 5, "alice", "2025-02-15"),
    ("Fix login timeout", "Users report 504 errors on login after 30s", "pending", 5, "alice", "2025-02-10"),
    ("Update Redis config", "Increase max memory to 512MB", "completed", 3, "alice", "2025-02-05"),
    ("Write API documentation", "Document all REST endpoints for frontend", "in_progress", 4, "bob", "2025-02-20"),
    ("Database backup automation", "Set up daily pg_dump to S3", "pending", 4, "bob", "2025-02-18"),
    ("Load testing", "Run k6 load tests against staging", "pending", 3, "bob", "2025-02-25"),
    ("Security audit", "Review IAM roles and network policies", "pending", 5, "charlie", "2025-02-12"),
    ("Upgrade EKS version", "Plan and execute cluster upgrade to 1.30", "in_progress", 4, "charlie", "2025-03-01"),
    ("CI/CD pipeline fix", "Pipeline failing on integration tests", "pending", 5, "charlie", "2025-02-08"),
    ("Frontend redesign", "Implement new dashboard layout", "in_progress", 3, "diana", "2025-03-15"),
    ("Add user preferences", "Store theme and notification settings", "pending", 2, "diana", "2025-03-20"),
    ("Performance optimization", "Reduce page load time below 2s", "pending", 4, "diana", "2025-02-28"),
    ("Log aggregation setup", "Configure Fluent Bit for structured logging", "in_progress", 4, "eve", "2025-02-14"),
    ("Alert rules", "Define CloudWatch alarms for key metrics", "pending", 4, "eve", "2025-02-22"),
    ("Incident runbook", "Create runbook for common failure scenarios", "pending", 3, "eve", "2025-03-10"),
]


def wait_for_db(max_retries=30, delay=2):
    """Wait for PostgreSQL to become available."""
    for i in range(max_retries):
        try:
            conn = psycopg2.connect(**DB_CONFIG)
            conn.close()
            print(f"Database is ready (attempt {i + 1})")
            return True
        except psycopg2.OperationalError:
            print(f"Waiting for database... (attempt {i + 1}/{max_retries})")
            time.sleep(delay)
    raise Exception("Database not available after max retries")


def hydrate():
    """Create schema and seed data."""
    wait_for_db()

    conn = psycopg2.connect(**DB_CONFIG)
    conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    cur = conn.cursor()

    # Create schema
    print("Creating schema...")
    cur.execute(SCHEMA_SQL)

    # Seed users
    print("Seeding users...")
    for username, email, password in SEED_USERS:
        cur.execute(
            """
            INSERT INTO users (username, email, password_hash)
            VALUES (%s, %s, crypt(%s, gen_salt('bf')))
            ON CONFLICT (username) DO NOTHING
            """,
            (username, email, password),
        )

    # Get user ID mapping
    cur.execute("SELECT id, username FROM users")
    user_map = {row[1]: row[0] for row in cur.fetchall()}

    # Seed tasks
    print("Seeding tasks...")
    for title, desc, status, priority, assignee, due_date in SEED_TASKS:
        user_id = user_map.get(assignee)
        if user_id:
            cur.execute(
                """
                INSERT INTO tasks (title, description, status, priority, assigned_to, due_date)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT DO NOTHING
                """,
                (title, desc, status, priority, user_id, due_date),
            )

    cur.close()
    conn.close()
    print(f"Hydration complete: {len(SEED_USERS)} users, {len(SEED_TASKS)} tasks")


if __name__ == "__main__":
    hydrate()
