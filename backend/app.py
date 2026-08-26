import json
import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from database import init_db, seed_demo_data, get_db_connection, DB_NAME

app = Flask(__name__)
# Enable CORS for all routes and origins (critical for Flutter Web & Mobile)
CORS(app)

@app.after_request
def add_cors_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept"
    return response

@app.before_request
def handle_options_preflight():
    if request.method == "OPTIONS":
        response = app.make_default_options_response()
        response.headers["Access-Control-Allow-Origin"] = "*"
        response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With, Accept"
        return response

def json_response(data, status=200):
    return jsonify(data), status

def error_response(message, status=400):
    return jsonify({"error": message}), status

def row_to_recipe_dict(row):
    """Safely format database row into a structured Recipe JSON dictionary."""
    try:
        ingredients = json.loads(row["ingredients"]) if isinstance(row["ingredients"], str) else (row["ingredients"] or [])
    except Exception:
        ingredients = []

    try:
        steps = json.loads(row["steps"]) if isinstance(row["steps"], str) else (row["steps"] or [])
    except Exception:
        steps = []

    try:
        nutrition = json.loads(row["nutrition"]) if isinstance(row["nutrition"], str) else (row["nutrition"] or {})
    except Exception:
        nutrition = {}

    return {
        "id": row["id"],
        "user_id": row["user_id"],
        "title": row["title"],
        "description": row["description"] or "",
        "ingredients": ingredients,
        "steps": steps,
        "cooking_time_minutes": row["cooking_time_minutes"],
        "servings": row["servings"],
        "spice_level": row["spice_level"],
        "cuisine": row["cuisine"],
        "diet_type": row["diet_type"],
        "match_type": row["match_type"],
        "match_percentage": row["match_percentage"],
        "image_emoji": row["image_emoji"],
        "nutrition": nutrition,
        "is_favorite": bool(row["is_favorite"]),
        "created_at": str(row["created_at"]),
    }

# ─────────────────────────────────────────────────────────────
# Root & Health Check
# ─────────────────────────────────────────────────────────────

@app.route("/", methods=["GET"])
@app.route("/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "online",
        "service": "CookSmart Backend API (MySQL)",
        "version": "1.0.0"
    }), 200

# ─────────────────────────────────────────────────────────────
# AUTH ENDPOINTS
# ─────────────────────────────────────────────────────────────

@app.route("/signup", methods=["POST"])
def signup():
    data = request.get_json(silent=True) or {}
    name = data.get("name", "").strip()
    email = data.get("email", "").strip().lower()
    password = data.get("password", "")

    if not name or not email or not password:
        return error_response("Name, email, and password are required.", 400)

    conn = get_db_connection()
    with conn.cursor() as cursor:
        # Check if user already exists
        cursor.execute("SELECT id FROM users WHERE LOWER(email) = %s", (email,))
        if cursor.fetchone():
            conn.close()
            return error_response("An account with this email already exists.", 409)

        password_hash = generate_password_hash(password)
        cursor.execute(
            "INSERT INTO users (name, email, password_hash) VALUES (%s, %s, %s)",
            (name, email, password_hash)
        )
        user_id = cursor.lastrowid
    conn.close()

    return jsonify({
        "message": "User created successfully",
        "user": {
            "id": user_id,
            "name": name,
            "email": email
        }
    }), 201

@app.route("/login", methods=["POST"])
def login():
    data = request.get_json(silent=True) or {}
    email = data.get("email", "").strip().lower()
    password = data.get("password", "")

    if not email or not password:
        return error_response("Email and password are required.", 400)

    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("SELECT id, name, email, password_hash FROM users WHERE LOWER(email) = %s", (email,))
        user = cursor.fetchone()
    conn.close()

    if not user or not check_password_hash(user["password_hash"], password):
        return error_response("Invalid email or password.", 401)

    return jsonify({
        "message": "Login successful",
        "user": {
            "id": user["id"],
            "name": user["name"],
            "email": user["email"]
        }
    }), 200

@app.route("/logout", methods=["POST"])
def logout():
    return jsonify({"message": "Logged out successfully"}), 200

@app.route("/get_current_user", methods=["GET"])
def get_current_user():
    user_id = request.args.get("user_id", type=int)
    if not user_id:
        return error_response("user_id parameter is required.", 400)

    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("SELECT id, name, email, created_at FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
    conn.close()

    if not user:
        return error_response("User not found.", 404)

    return jsonify({
        "id": user["id"],
        "name": user["name"],
        "email": user["email"],
        "created_at": str(user["created_at"])
    }), 200

# ─────────────────────────────────────────────────────────────
# RECIPES ENDPOINTS
# ─────────────────────────────────────────────────────────────

@app.route("/recipes/<int:user_id>", methods=["GET"])
def get_recipes(user_id):
    favorites_only = request.args.get("favorite", "").lower() in ("true", "1")

    conn = get_db_connection()
    with conn.cursor() as cursor:
        if favorites_only:
            cursor.execute(
                "SELECT * FROM recipes WHERE user_id = %s AND is_favorite = 1 ORDER BY id DESC",
                (user_id,)
            )
        else:
            cursor.execute(
                "SELECT * FROM recipes WHERE user_id = %s ORDER BY id DESC",
                (user_id,)
            )
        rows = cursor.fetchall()
    conn.close()

    recipes = [row_to_recipe_dict(r) for r in rows]
    return jsonify(recipes), 200

@app.route("/recipes", methods=["POST"])
def save_recipe():
    data = request.get_json(silent=True) or {}
    user_id = data.get("user_id")
    title = data.get("title")

    if not user_id or not title:
        return error_response("user_id and title are required.", 400)

    ingredients = json.dumps(data.get("ingredients", []))
    steps = json.dumps(data.get("steps", []))
    nutrition = json.dumps(data.get("nutrition", {}))
    is_favorite = 1 if data.get("is_favorite", False) else 0

    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("""
            INSERT INTO recipes (
                user_id, title, description, ingredients, steps,
                cooking_time_minutes, servings, spice_level, cuisine,
                diet_type, match_type, match_percentage, image_emoji,
                nutrition, is_favorite
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            user_id,
            title,
            data.get("description", ""),
            ingredients,
            steps,
            data.get("cooking_time_minutes", 30),
            data.get("servings", 4),
            data.get("spice_level", "Mild"),
            data.get("cuisine", "International"),
            data.get("diet_type"),
            data.get("match_type", "full"),
            data.get("match_percentage", 100),
            data.get("image_emoji", "🍲"),
            nutrition,
            is_favorite
        ))
        recipe_id = cursor.lastrowid
    conn.close()

    return jsonify({"message": "Recipe saved successfully", "id": recipe_id}), 201

@app.route("/recipes/<int:recipe_id>/favorite", methods=["POST"])
def toggle_favorite(recipe_id):
    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("SELECT is_favorite FROM recipes WHERE id = %s", (recipe_id,))
        row = cursor.fetchone()

        if not row:
            conn.close()
            return error_response("Recipe not found.", 404)

        new_state = 0 if row["is_favorite"] else 1
        cursor.execute("UPDATE recipes SET is_favorite = %s WHERE id = %s", (new_state, recipe_id))
    conn.close()

    return jsonify({"message": "Favorite status updated", "is_favorite": bool(new_state)}), 200

@app.route("/recipes/<int:recipe_id>", methods=["DELETE"])
def delete_recipe(recipe_id):
    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("DELETE FROM recipes WHERE id = %s", (recipe_id,))
        deleted = cursor.rowcount > 0
    conn.close()

    if not deleted:
        return error_response("Recipe not found.", 404)
    return jsonify({"message": "Recipe deleted successfully"}), 200

# ─────────────────────────────────────────────────────────────
# MEAL PLANNER ENDPOINTS
# ─────────────────────────────────────────────────────────────

@app.route("/meal_plan/<int:user_id>", methods=["GET"])
def get_meal_plan(user_id):
    date = request.args.get("date")
    if not date:
        return error_response("Date parameter (YYYY-MM-DD) is required.", 400)

    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("""
            SELECT id, meal_type, meal_name, recipe_id
            FROM meal_plans
            WHERE user_id = %s AND plan_date = %s
        """, (user_id, date))
        rows = cursor.fetchall()
    conn.close()

    result = {}
    for r in rows:
        result[r["meal_type"]] = {
            "id": r["id"],
            "meal_name": r["meal_name"],
            "recipe_id": r["recipe_id"]
        }
    return jsonify(result), 200

@app.route("/meal_plan/range/<int:user_id>", methods=["GET"])
def get_meal_plan_range(user_id):
    start_date = request.args.get("start_date")
    end_date = request.args.get("end_date")

    conn = get_db_connection()
    with conn.cursor() as cursor:
        if start_date and end_date:
            cursor.execute("""
                SELECT id, plan_date, meal_type, meal_name, recipe_id
                FROM meal_plans
                WHERE user_id = %s AND plan_date BETWEEN %s AND %s
                ORDER BY plan_date ASC
            """, (user_id, start_date, end_date))
        else:
            cursor.execute("""
                SELECT id, plan_date, meal_type, meal_name, recipe_id
                FROM meal_plans
                WHERE user_id = %s
                ORDER BY plan_date ASC
            """, (user_id,))
        rows = cursor.fetchall()
    conn.close()

    plans = [{
        "id": r["id"],
        "plan_date": r["plan_date"],
        "meal_type": r["meal_type"],
        "meal_name": r["meal_name"],
        "recipe_id": r["recipe_id"]
    } for r in rows]

    return jsonify(plans), 200

@app.route("/meal_plan", methods=["POST"])
def save_meal_plan():
    data = request.get_json(silent=True) or {}
    user_id = data.get("user_id")
    plan_date = data.get("plan_date")
    meal_type = data.get("meal_type")
    meal_name = data.get("meal_name")
    recipe_id = data.get("recipe_id")

    if not user_id or not plan_date or not meal_type or not meal_name:
        return error_response("user_id, plan_date, meal_type, and meal_name are required.", 400)

    conn = get_db_connection()
    with conn.cursor() as cursor:
        # MySQL ON DUPLICATE KEY UPDATE
        cursor.execute("""
            INSERT INTO meal_plans (user_id, plan_date, meal_type, meal_name, recipe_id)
            VALUES (%s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE meal_name = VALUES(meal_name), recipe_id = VALUES(recipe_id)
        """, (user_id, plan_date, meal_type, meal_name, recipe_id))
        entry_id = cursor.lastrowid
    conn.close()

    return jsonify({"message": "Meal plan saved successfully", "id": entry_id}), 201

@app.route("/meal_plan/<int:entry_id>", methods=["DELETE"])
def delete_meal_plan(entry_id):
    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("DELETE FROM meal_plans WHERE id = %s", (entry_id,))
        deleted = cursor.rowcount > 0
    conn.close()

    if not deleted:
        return error_response("Meal plan entry not found.", 404)
    return jsonify({"message": "Meal plan entry deleted successfully"}), 200

# ─────────────────────────────────────────────────────────────
# SCAN HISTORY ENDPOINTS
# ─────────────────────────────────────────────────────────────

@app.route("/scan_history/<int:user_id>", methods=["GET"])
def get_scan_history(user_id):
    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("SELECT * FROM scan_history WHERE user_id = %s ORDER BY id DESC", (user_id,))
        rows = cursor.fetchall()
    conn.close()

    history = []
    for r in rows:
        try:
            ingr = json.loads(r["ingredients"]) if isinstance(r["ingredients"], str) else (r["ingredients"] or [])
        except Exception:
            ingr = []
        history.append({
            "id": r["id"],
            "user_id": r["user_id"],
            "ingredients": ingr,
            "image_path": r["image_path"],
            "created_at": str(r["created_at"])
        })

    return jsonify(history), 200

@app.route("/scan_history", methods=["POST"])
def save_scan_history():
    data = request.get_json(silent=True) or {}
    user_id = data.get("user_id")
    ingredients = data.get("ingredients", [])

    if not user_id or not ingredients:
        return error_response("user_id and ingredients list are required.", 400)

    ingr_json = json.dumps(ingredients)
    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute(
            "INSERT INTO scan_history (user_id, ingredients, image_path) VALUES (%s, %s, %s)",
            (user_id, ingr_json, data.get("image_path"))
        )
        scan_id = cursor.lastrowid
    conn.close()

    return jsonify({"message": "Scan history saved", "id": scan_id}), 201

@app.route("/scan_history/<int:scan_id>", methods=["DELETE"])
def delete_scan_history(scan_id):
    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("DELETE FROM scan_history WHERE id = %s", (scan_id,))
        deleted = cursor.rowcount > 0
    conn.close()

    if not deleted:
        return error_response("Scan record not found.", 404)
    return jsonify({"message": "Scan history deleted successfully"}), 200

# ─────────────────────────────────────────────────────────────
# FEEDBACK ENDPOINTS
# ─────────────────────────────────────────────────────────────

@app.route("/feedback", methods=["POST"])
def submit_feedback():
    data = request.get_json(silent=True) or {}
    user_id = data.get("user_id")
    rating = data.get("rating", 5)
    category = data.get("category", "General")
    message = data.get("message", "").strip()

    if not user_id or not message:
        return error_response("user_id and message are required.", 400)

    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute(
            "INSERT INTO feedback (user_id, rating, category, message) VALUES (%s, %s, %s, %s)",
            (user_id, rating, category, message)
        )
        feedback_id = cursor.lastrowid
    conn.close()

    return jsonify({"message": "Feedback submitted successfully", "id": feedback_id}), 201

@app.route("/feedback/<int:user_id>", methods=["GET"])
def get_feedback(user_id):
    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("SELECT * FROM feedback WHERE user_id = %s ORDER BY id DESC", (user_id,))
        rows = cursor.fetchall()
    conn.close()

    feedbacks = [{
        "id": r["id"],
        "user_id": r["user_id"],
        "rating": r["rating"],
        "category": r["category"],
        "message": r["message"],
        "created_at": str(r["created_at"])
    } for r in rows]

    return jsonify(feedbacks), 200

# ─────────────────────────────────────────────────────────────
# PROFILE & STATS ENDPOINTS
# ─────────────────────────────────────────────────────────────

@app.route("/profile/<int:user_id>", methods=["GET"])
def get_profile(user_id):
    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("SELECT id, name, email FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            conn.close()
            return error_response("User not found.", 404)

        # Favorite recipes count
        cursor.execute("SELECT COUNT(*) AS count FROM recipes WHERE user_id = %s AND is_favorite = 1", (user_id,))
        fav_count = cursor.fetchone()["count"]

        # Total saved recipes count
        cursor.execute("SELECT COUNT(*) AS count FROM recipes WHERE user_id = %s", (user_id,))
        recipes_count = cursor.fetchone()["count"]

        # Distinct planned days count
        cursor.execute("SELECT COUNT(DISTINCT plan_date) AS count FROM meal_plans WHERE user_id = %s", (user_id,))
        planned_days = cursor.fetchone()["count"]
    conn.close()

    return jsonify({
        "id": user["id"],
        "name": user["name"],
        "email": user["email"],
        "stats": {
            "favorites": fav_count,
            "recipes_saved": recipes_count,
            "planned_days": planned_days
        }
    }), 200

@app.route("/profile/<int:user_id>", methods=["PUT"])
def update_profile(user_id):
    data = request.get_json(silent=True) or {}
    name = data.get("name", "").strip()

    if not name:
        return error_response("Name cannot be empty.", 400)

    conn = get_db_connection()
    with conn.cursor() as cursor:
        cursor.execute("UPDATE users SET name = %s WHERE id = %s", (name, user_id))
    conn.close()

    return jsonify({"message": "Profile updated successfully"}), 200

# ─────────────────────────────────────────────────────────────
# DASHBOARD ENDPOINT
# ─────────────────────────────────────────────────────────────

@app.route("/dashboard/<int:user_id>", methods=["GET"])
def get_dashboard(user_id):
    conn = get_db_connection()
    with conn.cursor() as cursor:
        # User basic info
        cursor.execute("SELECT id, name, email FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            conn.close()
            return error_response("User not found.", 404)

        # Stats
        cursor.execute("SELECT COUNT(*) AS count FROM recipes WHERE user_id = %s AND is_favorite = 1", (user_id,))
        fav_count = cursor.fetchone()["count"]

        cursor.execute("SELECT COUNT(*) AS count FROM recipes WHERE user_id = %s", (user_id,))
        recipes_count = cursor.fetchone()["count"]

        cursor.execute("SELECT COUNT(DISTINCT plan_date) AS count FROM meal_plans WHERE user_id = %s", (user_id,))
        planned_days = cursor.fetchone()["count"]

        # Recent scans (limit 3)
        cursor.execute("SELECT * FROM scan_history WHERE user_id = %s ORDER BY id DESC LIMIT 3", (user_id,))
        recent_scans_raw = cursor.fetchall()
        recent_scans = []
        for r in recent_scans_raw:
            try:
                ingr = json.loads(r["ingredients"])
            except Exception:
                ingr = []
            recent_scans.append({"id": r["id"], "ingredients": ingr, "created_at": str(r["created_at"])})
    conn.close()

    return jsonify({
        "user": {"id": user["id"], "name": user["name"], "email": user["email"]},
        "stats": {
            "favorites": fav_count,
            "recipes_saved": recipes_count,
            "planned_days": planned_days
        },
        "recent_scans": recent_scans
    }), 200

# ─────────────────────────────────────────────────────────────
# Application Initialization
# ─────────────────────────────────────────────────────────────

if __name__ == "__main__":
    init_db()
    seed_demo_data()
    port = int(os.environ.get("PORT", 5000))
    print(f">> CookSmart Backend starting on http://0.0.0.0:{port} (Connected to MySQL: {DB_NAME})")
    app.run(host="0.0.0.0", port=port, debug=True)
