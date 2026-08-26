# CookSmart Backend API 🍳

Lightweight, high-performance REST API built with **Python**, **Flask**, and **SQLite** for the CookSmart Flutter application.

---

## Features
- **Authentication**: User Signup, Login, Password Hashing with Werkzeug, Logout, User Info.
- **Recipes**: Save recipes, Fetch user recipes & favorite filters, Toggle favorites, Delete recipes.
- **Meal Planner**: Save/Upsert daily meal plans (Breakfast, Lunch, Dinner, Snacks), Fetch day/range plans, Delete meal plans.
- **Scan History**: Save camera ingredient detections, Fetch scan history, Delete scans.
- **Feedback**: Submit rating, category & feedback messages.
- **Profile & Dashboard**: Aggregate user statistics (Favorites count, Saved recipes, Planned days, Recent scans).
- **CORS Enabled**: Works seamlessly across Flutter Web, Desktop, Android, and iOS.

---

## Quick Start

### 1. Install Dependencies
```bash
pip install -r requirements.txt
```

### 2. Run the Server
```bash
python app.py
```
*(Or double-click `run_backend.bat`)*

The server will start on `http://0.0.0.0:5000` (accessible via `http://localhost:5000` or `http://127.0.0.1:5000`).

---

## Running Unit Tests
```bash
python test_backend.py
```

---

## API Endpoints Reference

### 🔐 Authentication
- `POST /signup` - Register a new user (`name`, `email`, `password`)
- `POST /login` - Login (`email`, `password`)
- `POST /logout` - Logout (`email`)
- `GET /get_current_user?user_id=1` - Get user details

### 🍲 Recipes
- `GET /recipes/<user_id>?favorite=true` - Fetch user saved recipes
- `POST /recipes` - Save recipe with ingredients, steps, nutrition, servings
- `POST /recipes/<recipe_id>/favorite` - Toggle favorite status
- `DELETE /recipes/<recipe_id>` - Delete recipe

### 📅 Meal Planner
- `GET /meal_plan/<user_id>?date=YYYY-MM-DD` - Get meal plan for date
- `GET /meal_plan/range/<user_id>?start_date=...&end_date=...` - Get date range meal plan
- `POST /meal_plan` - Save/Update meal slot (`user_id`, `plan_date`, `meal_type`, `meal_name`)
- `DELETE /meal_plan/<entry_id>` - Remove meal entry

### 📷 Scan History
- `GET /scan_history/<user_id>` - Fetch scan history
- `POST /scan_history` - Save scan ingredients list
- `DELETE /scan_history/<scan_id>` - Delete scan record

### 💬 Feedback
- `POST /feedback` - Submit feedback (`user_id`, `rating`, `category`, `message`)
- `GET /feedback/<user_id>` - Fetch feedback history

### 👤 Profile & Dashboard
- `GET /profile/<user_id>` - User profile and stats summary
- `PUT /profile/<user_id>` - Update profile name
- `GET /dashboard/<user_id>` - Comprehensive dashboard payload
