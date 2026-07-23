"""
Frontend Flask application - Login page with task retrieval.
Connects to PostgreSQL for auth and Redis for session caching.
"""
import os
import json
import logging

from flask import Flask, request, jsonify, render_template, session
import psycopg2
import redis

# Configure structured logging for CloudWatch
logging.basicConfig(
    level=logging.INFO,
    format='{"timestamp":"%(asctime)s","level":"%(levelname)s","logger":"%(name)s","message":"%(message)s"}'
)
logger = logging.getLogger("frontend")

app = Flask(__name__)
app.secret_key = os.environ.get("SECRET_KEY", "dev-secret-key")

# Database configuration
DB_CONFIG = {
    "host": os.environ.get("POSTGRES_HOST", "postgres"),
    "port": int(os.environ.get("POSTGRES_PORT", 5432)),
    "dbname": os.environ.get("POSTGRES_DB", "aiops"),
    "user": os.environ.get("POSTGRES_USER", "aiops_user"),
    "password": os.environ.get("POSTGRES_PASSWORD", "aiops_pass_dev"),
}

# Redis configuration
REDIS_HOST = os.environ.get("REDIS_HOST", "redis")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))
redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, decode_responses=True)


def get_db_connection():
    """Create a new database connection."""
    return psycopg2.connect(**DB_CONFIG)


@app.route("/health")
def health():
    """Health check endpoint for Kubernetes probes."""
    try:
        conn = get_db_connection()
        conn.close()
        redis_client.ping()
        return jsonify({"status": "healthy", "db": "connected", "redis": "connected"})
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({"status": "unhealthy", "error": str(e)}), 503


@app.route("/")
def index():
    """Render login page."""
    return render_template("login.html")


@app.route("/login", methods=["POST"])
def login():
    """Authenticate user and return tasks."""
    username = request.form.get("username")
    password = request.form.get("password")

    if not username or not password:
        logger.warning(f"Login attempt with missing credentials")
        return jsonify({"success": False, "error": "Username and password required"}), 400

    try:
        # Check Redis cache for session
        cached = redis_client.get(f"session:{username}")
        if cached:
            logger.info(f"Cache hit for user: {username}")
            return jsonify(json.loads(cached))

        # Authenticate against database
        conn = get_db_connection()
        cur = conn.cursor()

        cur.execute(
            "SELECT id, username FROM users WHERE username = %s AND password_hash = crypt(%s, password_hash)",
            (username, password),
        )
        user = cur.fetchone()

        if not user:
            logger.warning(f"Failed login attempt for user: {username}")
            cur.close()
            conn.close()
            return jsonify({"success": False, "error": "Invalid credentials"}), 401

        user_id, user_name = user

        # Fetch tasks for user
        cur.execute(
            """
            SELECT id, title, description, status, priority, due_date
            FROM tasks
            WHERE assigned_to = %s
            ORDER BY priority DESC, due_date ASC
            """,
            (user_id,),
        )
        tasks = [
            {
                "id": row[0],
                "title": row[1],
                "description": row[2],
                "status": row[3],
                "priority": row[4],
                "due_date": str(row[5]) if row[5] else None,
            }
            for row in cur.fetchall()
        ]

        cur.close()
        conn.close()

        response = {
            "success": True,
            "user": user_name,
            "tasks": tasks,
            "task_count": len(tasks),
        }

        # Cache in Redis (5 min TTL)
        redis_client.setex(f"session:{username}", 300, json.dumps(response))
        logger.info(f"Successful login for user: {username}, tasks: {len(tasks)}")

        return jsonify(response)

    except Exception as e:
        logger.error(f"Login error for user {username}: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@app.route("/tasks/<int:user_id>")
def get_tasks(user_id):
    """Get tasks for a specific user."""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            """
            SELECT id, title, description, status, priority, due_date
            FROM tasks
            WHERE assigned_to = %s
            ORDER BY priority DESC, due_date ASC
            """,
            (user_id,),
        )
        tasks = [
            {
                "id": row[0],
                "title": row[1],
                "description": row[2],
                "status": row[3],
                "priority": row[4],
                "due_date": str(row[5]) if row[5] else None,
            }
            for row in cur.fetchall()
        ]
        cur.close()
        conn.close()

        logger.info(f"Retrieved {len(tasks)} tasks for user_id: {user_id}")
        return jsonify({"tasks": tasks, "count": len(tasks)})

    except Exception as e:
        logger.error(f"Error fetching tasks for user_id {user_id}: {e}")
        return jsonify({"error": "Internal server error"}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
