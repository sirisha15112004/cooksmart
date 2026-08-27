import unittest
import json
import os
import uuid
import random
from datetime import datetime, date, timedelta
import database
from app import app

def generate_dynamic_user():
    uid = uuid.uuid4().hex[:8]
    first_names = ["Alex", "Jordan", "Taylor", "Morgan", "Sam", "Chris", "Pat", "Riley"]
    last_names = ["Chef", "Gourmet", "Baker", "Cook", "Foodie", "Miller", "Smith"]
    name = f"{random.choice(first_names)} {random.choice(last_names)}"
    email = f"user_{uid}_{int(datetime.now().timestamp())}@cooksmart-test.io"
    password = f"Pass_{uid}!{random.randint(100, 999)}"
    return {"name": name, "email": email, "password": password}

def generate_dynamic_recipe(user_id):
    cuisines = ["Italian", "Mexican", "Indian", "Japanese", "Mediterranean", "Thai", "American"]
    diets = ["Vegan", "Vegetarian", "Keto", "Gluten-Free", "Low-Carb", "None"]
    spices = ["Mild", "Medium", "Hot", "Extra Hot"]
    emojis = ["🥑", "🥗", "🍲", "🍕", "🌮", "🍛", "🍜", "🥘"]
    
    unique_id = uuid.uuid4().hex[:6]
    selected_cuisine = random.choice(cuisines)
    title = f"Dynamic {selected_cuisine} Dish {unique_id}"
    
    ingredients_pool = [
        "2 cups fresh spinach", "1 tbsp olive oil", "2 cloves garlic",
        "100g diced tofu", "1 cup cherry tomatoes", "1/2 cup almond milk",
        "1 cup jasmine rice", "1 tsp turmeric powder", "1 pinch sea salt"
    ]
    ingredients = random.sample(ingredients_pool, k=random.randint(3, 5))
    
    steps = [
        f"Prep ingredients and wash thoroughly.",
        f"Heat cooking pan over medium flame and combine ingredients.",
        f"Simmer for {random.randint(5, 15)} minutes until aromatic.",
        f"Serve fresh and garnish to taste."
    ]
    
    return {
        "user_id": user_id,
        "title": title,
        "description": f"Delicious chef-crafted {selected_cuisine} recipe generated dynamically.",
        "ingredients": ingredients,
        "steps": steps,
        "cooking_time_minutes": random.randint(10, 60),
        "servings": random.randint(1, 6),
        "spice_level": random.choice(spices),
        "cuisine": selected_cuisine,
        "diet_type": random.choice(diets),
        "match_type": random.choice(["full", "partial"]),
        "match_percentage": random.randint(70, 100),
        "image_emoji": random.choice(emojis),
        "nutrition": {
            "calories": random.randint(150, 750),
            "protein": round(random.uniform(5.0, 45.0), 1),
            "carbs": round(random.uniform(10.0, 80.0), 1),
            "fat": round(random.uniform(2.0, 35.0), 1),
            "fiber": round(random.uniform(1.0, 15.0), 1)
        },
        "is_favorite": True
    }

def generate_dynamic_meal_plan(user_id):
    meal_types = ["breakfast", "lunch", "dinner", "snack"]
    dishes = ["Avocado Toast", "Mediterranean Bowl", "Protein Smoothie", "Stir-fry Veggies", "Grilled Salmon"]
    random_days_ahead = random.randint(0, 14)
    target_date = (date.today() + timedelta(days=random_days_ahead)).isoformat()
    return {
        "user_id": user_id,
        "plan_date": target_date,
        "meal_type": random.choice(meal_types),
        "meal_name": f"{random.choice(dishes)} (Plan {uuid.uuid4().hex[:4]})"
    }

def generate_dynamic_feedback(user_id):
    categories = ["General", "Bug Report", "Feature Request", "UI/UX Feedback"]
    comments = [
        "Love the instant recipe suggestions!",
        "Dynamic scanning works seamlessly with my ingredients.",
        "Would love more international cuisine presets.",
        "Great application flow and snappy response."
    ]
    return {
        "user_id": user_id,
        "rating": random.randint(3, 5),
        "category": random.choice(categories),
        "message": f"{random.choice(comments)} [Ref: {uuid.uuid4().hex[:6]}]"
    }

class CookSmartBackendMySQLTestCase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        database.init_db()
        database.seed_demo_data()

    def setUp(self):
        self.client = app.test_client()

    def test_1_health(self):
        res = self.client.get("/health")
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertEqual(data["status"], "online")

    def test_2_dynamic_auth_and_lifecycle_flow(self):
        # 1. Dynamic User Generation
        dynamic_user = generate_dynamic_user()
        
        # Signup
        signup_res = self.client.post("/signup", json={
            "name": dynamic_user["name"],
            "email": dynamic_user["email"],
            "password": dynamic_user["password"],
            "confirm_password": dynamic_user["password"]
        })
        self.assertEqual(signup_res.status_code, 201, f"Signup failed: {signup_res.get_json()}")
        
        # 2. Login with dynamic user
        login_res = self.client.post("/login", json={
            "email": dynamic_user["email"],
            "password": dynamic_user["password"]
        })
        self.assertEqual(login_res.status_code, 200)
        user_info = login_res.get_json()["user"]
        user_id = user_info["id"]
        self.assertEqual(user_info["email"], dynamic_user["email"])

        # 3. Dynamic Logout
        logout_res = self.client.post("/logout", json={"email": dynamic_user["email"]})
        self.assertEqual(logout_res.status_code, 200)

        # 4. Save Dynamic Recipe
        dynamic_recipe = generate_dynamic_recipe(user_id)
        save_res = self.client.post("/recipes", json=dynamic_recipe)
        self.assertEqual(save_res.status_code, 201)
        recipe_id = save_res.get_json()["id"]

        # 5. Fetch Dynamic Favorites
        favs_res = self.client.get(f"/recipes/{user_id}?favorite=true")
        self.assertEqual(favs_res.status_code, 200)
        favs = favs_res.get_json()
        self.assertTrue(len(favs) >= 1)
        self.assertTrue(any(f["title"] == dynamic_recipe["title"] for f in favs))

        # 6. Toggle Favorite State Dynamically
        toggle_res = self.client.post(f"/recipes/{recipe_id}/favorite")
        self.assertEqual(toggle_res.status_code, 200)
        self.assertFalse(toggle_res.get_json()["is_favorite"])

        # 7. Dynamic Meal Planner
        meal_plan_data = generate_dynamic_meal_plan(user_id)
        save_meal = self.client.post("/meal_plan", json=meal_plan_data)
        self.assertEqual(save_meal.status_code, 201)

        get_meal = self.client.get(f"/meal_plan/{user_id}?date={meal_plan_data['plan_date']}")
        self.assertEqual(get_meal.status_code, 200)
        self.assertIn(meal_plan_data["meal_type"], get_meal.get_json())

        # 8. Dynamic Feedback
        feedback_data = generate_dynamic_feedback(user_id)
        fb_res = self.client.post("/feedback", json=feedback_data)
        self.assertEqual(fb_res.status_code, 201)

        # 9. Dynamic Profile Verification
        prof_res = self.client.get(f"/profile/{user_id}")
        self.assertEqual(prof_res.status_code, 200)
        profile_json = prof_res.get_json()
        self.assertEqual(profile_json["email"], dynamic_user["email"])
        self.assertIn("stats", profile_json)
        self.assertGreaterEqual(profile_json["stats"]["recipes_saved"], 1)

        # 10. Dynamic Dashboard & Scan History Verification
        dash_res = self.client.get(f"/dashboard/{user_id}")
        self.assertEqual(dash_res.status_code, 200)
        dash_json = dash_res.get_json()
        self.assertEqual(dash_json["user"]["email"], dynamic_user["email"])
        self.assertIn("stats", dash_json)
        self.assertIn("recent_scans", dash_json)

if __name__ == "__main__":
    unittest.main()
