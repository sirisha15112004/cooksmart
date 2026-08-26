import os
import json
import pymysql
import pymysql.cursors
from pathlib import Path
from werkzeug.security import generate_password_hash

# Try loading .env if dotenv is installed
try:
    from dotenv import load_dotenv
    env_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".env")
    load_dotenv(env_path)
except ImportError:
    pass

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = int(os.environ.get("DB_PORT", 3306))
DB_USER = os.environ.get("DB_USER", "root")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "Sirishak@6302")
DB_NAME = os.environ.get("DB_NAME", "smartcook")

def get_db_connection(include_db=True):
    """Create and return a MySQL connection with DictCursor."""
    conn = pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME if include_db else None,
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True
    )
    return conn

def init_db():
    """Ensure database and all MySQL tables/indexes exist."""
    # 1. Ensure database exists
    conn = get_db_connection(include_db=False)
    with conn.cursor() as cursor:
        cursor.execute(f"CREATE DATABASE IF NOT EXISTS `{DB_NAME}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
    conn.close()

    # 2. Initialize tables
    conn = get_db_connection(include_db=True)
    with conn.cursor() as cursor:
        # Users Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                email VARCHAR(255) NOT NULL UNIQUE,
                password_hash VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)

        # Recipes Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS recipes (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                title VARCHAR(255) NOT NULL,
                description TEXT,
                ingredients LONGTEXT NOT NULL,
                steps LONGTEXT NOT NULL,
                cooking_time_minutes INT DEFAULT 30,
                servings INT DEFAULT 4,
                spice_level VARCHAR(50) DEFAULT 'Mild',
                cuisine VARCHAR(100) DEFAULT 'International',
                diet_type VARCHAR(100),
                match_type VARCHAR(50) DEFAULT 'full',
                match_percentage INT DEFAULT 100,
                image_emoji VARCHAR(50) DEFAULT '🍲',
                nutrition LONGTEXT NOT NULL,
                is_favorite BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_recipes_user (user_id),
                INDEX idx_recipes_fav (user_id, is_favorite)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)

        # Meal Plans Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS meal_plans (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                plan_date VARCHAR(50) NOT NULL,
                meal_type VARCHAR(50) NOT NULL,
                meal_name VARCHAR(255) NOT NULL,
                recipe_id INT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (recipe_id) REFERENCES recipes(id) ON DELETE SET NULL,
                UNIQUE KEY uq_user_date_meal (user_id, plan_date, meal_type),
                INDEX idx_meal_plans_user_date (user_id, plan_date)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)

        # Scan History Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS scan_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                ingredients LONGTEXT NOT NULL,
                image_path VARCHAR(500),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_scan_history_user (user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)

        # Feedback Table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS feedback (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                rating INT NOT NULL,
                category VARCHAR(100) NOT NULL,
                message TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)

    conn.close()

def seed_demo_data():
    """Seed sample demo chef account if not exists."""
    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("SELECT id FROM users WHERE email = %s", ("demo@cooksmart.com",))
        existing = cursor.fetchone()
        if not existing:
            demo_pwd_hash = generate_password_hash("password123")
            cursor.execute(
                "INSERT INTO users (name, email, password_hash) VALUES (%s, %s, %s)",
                ("Demo Chef", "demo@cooksmart.com", demo_pwd_hash)
            )
            user_id = cursor.lastrowid

            # Insert sample favorite recipe
            sample_ingredients = json.dumps(["2 eggs", "1 tomato chopped", "1 onion diced", "1 pinch salt", "1 tbsp olive oil"])
            sample_steps = json.dumps(["Heat oil in a pan.", "Sauté onions and tomatoes until soft.", "Beat eggs and pour into pan.", "Scramble and serve hot."])
            sample_nutrition = json.dumps({"calories": 250, "protein": 14.0, "carbs": 6.0, "fat": 18.0, "fiber": 2.0})

            cursor.execute("""
                INSERT INTO recipes (
                    user_id, title, description, ingredients, steps,
                    cooking_time_minutes, servings, spice_level, cuisine,
                    diet_type, match_type, match_percentage, image_emoji,
                    nutrition, is_favorite
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                user_id, "Classic Tomato Egg Scramble", "A quick and nutritious high-protein breakfast.",
                sample_ingredients, sample_steps, 15, 2, "Mild", "Mediterranean",
                "High-Protein", "full", 100, "🍳", sample_nutrition, 1
            ))

    conn.close()

if __name__ == "__main__":
    init_db()
    seed_demo_data()
    print(f"[OK] MySQL database '{DB_NAME}' connected and initialized successfully on {DB_HOST}:{DB_PORT}!")
