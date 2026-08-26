import unittest
import json
import os
import database
from app import app

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

    def test_2_auth_flow(self):
        # 1. Signup
        signup_res = self.client.post("/signup", json={
            "name": "Alex Chef",
            "email": "alex_mysql@test.com",
            "password": "mypassword123",
            "confirm_password": "mypassword123"
        })
        self.assertIn(signup_res.status_code, (201, 409))
        
        # 2. Login
        login_res = self.client.post("/login", json={
            "email": "alex_mysql@test.com",
            "password": "mypassword123"
        })
        self.assertEqual(login_res.status_code, 200)
        user_id = login_res.get_json()["user"]["id"]

        # 3. Logout
        logout_res = self.client.post("/logout", json={"email": "alex_mysql@test.com"})
        self.assertEqual(logout_res.status_code, 200)

        # 4. Save Recipe
        save_res = self.client.post("/recipes", json={
            "user_id": user_id,
            "title": "Avocado Toast",
            "description": "Crispy toast with creamy avocado",
            "ingredients": ["2 slices sourdough bread", "1 ripe avocado", "Chili flakes"],
            "steps": ["Toast the bread", "Mash avocado and spread on toast", "Sprinkle chili flakes"],
            "cooking_time_minutes": 10,
            "servings": 1,
            "spice_level": "Mild",
            "cuisine": "American",
            "diet_type": "Vegan",
            "match_type": "full",
            "match_percentage": 100,
            "image_emoji": "🥑",
            "nutrition": {"calories": 280, "protein": 6.0, "carbs": 30.0, "fat": 15.0, "fiber": 7.0},
            "is_favorite": True
        })
        self.assertEqual(save_res.status_code, 201)
        recipe_id = save_res.get_json()["id"]

        # 5. Fetch Favorites
        favs_res = self.client.get(f"/recipes/{user_id}?favorite=true")
        self.assertEqual(favs_res.status_code, 200)
        favs = favs_res.get_json()
        self.assertTrue(len(favs) >= 1)

        # 6. Toggle Favorite
        toggle_res = self.client.post(f"/recipes/{recipe_id}/favorite")
        self.assertEqual(toggle_res.status_code, 200)
        self.assertFalse(toggle_res.get_json()["is_favorite"])

        # 7. Meal Planner
        save_meal = self.client.post("/meal_plan", json={
            "user_id": user_id,
            "plan_date": "2026-08-26",
            "meal_type": "lunch",
            "meal_name": "Quinoa Salad"
        })
        self.assertEqual(save_meal.status_code, 201)

        get_meal = self.client.get(f"/meal_plan/{user_id}?date=2026-08-26")
        self.assertEqual(get_meal.status_code, 200)
        self.assertIn("lunch", get_meal.get_json())

        # 8. Feedback
        fb_res = self.client.post("/feedback", json={
            "user_id": user_id,
            "rating": 5,
            "category": "General",
            "message": "Awesome application!"
        })
        self.assertEqual(fb_res.status_code, 201)

        # 9. Profile
        prof_res = self.client.get(f"/profile/{user_id}")
        self.assertEqual(prof_res.status_code, 200)
        self.assertIn("stats", prof_res.get_json())

if __name__ == "__main__":
    unittest.main()
