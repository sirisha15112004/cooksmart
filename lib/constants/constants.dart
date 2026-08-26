import 'package:flutter/foundation.dart';

class AppUrl {
  // ─── Mobile device backend host (Laptop/Hotspot IP) ────────────────────────
  static const String _mobileHost = '192.168.137.1:5000';

  static String get baseUrl =>
      kIsWeb ? 'http://localhost:5000' : 'http://$_mobileHost';
  // ───────────────────────────────────────────────────────────────────────────

  // AUTH
  static String get signup        => '$baseUrl/signup';
  static String get login         => '$baseUrl/login';
  static String get logout        => '$baseUrl/logout';
  static String get getCurrentUser => '$baseUrl/get_current_user';

  // RECIPES
  static String recipes(int userId)           => '$baseUrl/recipes/$userId';
  static String recipeFavorite(int recipeId)  => '$baseUrl/recipes/$recipeId/favorite';
  static String deleteRecipe(int recipeId)    => '$baseUrl/recipes/$recipeId';

  // MEAL PLANNER
  static String mealPlan(int userId)          => '$baseUrl/meal_plan/$userId';
  static String mealPlanRange(int userId)     => '$baseUrl/meal_plan/range/$userId';
  static String deleteMealPlan(int entryId)   => '$baseUrl/meal_plan/$entryId';
  static String get saveMealPlan              => '$baseUrl/meal_plan';

  // SCAN HISTORY
  static String scanHistory(int userId)       => '$baseUrl/scan_history/$userId';
  static String deleteScan(int scanId)        => '$baseUrl/scan_history/$scanId';
  static String get saveScan                  => '$baseUrl/scan_history';

  // FEEDBACK
  static String get submitFeedback            => '$baseUrl/feedback';
  static String getFeedback(int userId)       => '$baseUrl/feedback/$userId';

  // PROFILE
  static String profile(int userId)           => '$baseUrl/profile/$userId';

  // DASHBOARD
  static String dashboard(int userId)         => '$baseUrl/dashboard/$userId';
}
