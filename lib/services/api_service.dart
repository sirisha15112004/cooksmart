import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/constants.dart';

class ApiService {
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // ─────────────────────────────────────────
  // AUTH
  // ─────────────────────────────────────────

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse(AppUrl.signup),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'confirm_password': password,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse(AppUrl.login),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return {'statusCode': res.statusCode, ...jsonDecode(res.body)};
  }

  static Future<void> logout(String email) async {
    await http.post(
      Uri.parse(AppUrl.logout),
      headers: _headers,
      body: jsonEncode({'email': email}),
    );
  }

  // ─────────────────────────────────────────
  // RECIPES
  // ─────────────────────────────────────────

  static Future<List<dynamic>> getRecipes(int userId,
      {bool favoritesOnly = false}) async {
    final uri = Uri.parse(AppUrl.recipes(userId))
        .replace(queryParameters: favoritesOnly ? {'favorite': 'true'} : null);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  static Future<int?> saveRecipe(Map<String, dynamic> recipeData) async {
    final res = await http.post(
      Uri.parse('${AppUrl.baseUrl}/recipes'),
      headers: _headers,
      body: jsonEncode(recipeData),
    );
    if (res.statusCode == 201) {
      final data = jsonDecode(res.body);
      return data['id'] as int?;
    }
    return null;
  }

  static Future<bool> toggleFavorite(int recipeId) async {
    final res = await http.post(
      Uri.parse(AppUrl.recipeFavorite(recipeId)),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['is_favorite'] ?? false;
    }
    return false;
  }

  static Future<bool> deleteRecipe(int recipeId) async {
    final res = await http.delete(
      Uri.parse(AppUrl.deleteRecipe(recipeId)),
      headers: _headers,
    );
    return res.statusCode == 200;
  }

  // ─────────────────────────────────────────
  // MEAL PLANNER
  // ─────────────────────────────────────────

  static Future<Map<String, dynamic>> getMealPlan(
      int userId, String date) async {
    final uri = Uri.parse(AppUrl.mealPlan(userId))
        .replace(queryParameters: {'date': date});
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {};
  }

  static Future<bool> saveMealPlan({
    required int userId,
    required String planDate,
    required String mealType,
    required String mealName,
    int? recipeId,
  }) async {
    final res = await http.post(
      Uri.parse(AppUrl.saveMealPlan),
      headers: _headers,
      body: jsonEncode({
        'user_id':   userId,
        'plan_date': planDate,
        'meal_type': mealType,
        'meal_name': mealName,
        if (recipeId != null) 'recipe_id': recipeId,
      }),
    );
    return res.statusCode == 201;
  }

  static Future<bool> deleteMealPlan(int entryId) async {
    final res = await http.delete(
      Uri.parse(AppUrl.deleteMealPlan(entryId)),
      headers: _headers,
    );
    return res.statusCode == 200;
  }

  // ─────────────────────────────────────────
  // SCAN HISTORY
  // ─────────────────────────────────────────

  static Future<bool> saveScan(int userId, List<String> ingredients) async {
    final res = await http.post(
      Uri.parse(AppUrl.saveScan),
      headers: _headers,
      body: jsonEncode({'user_id': userId, 'ingredients': ingredients}),
    );
    return res.statusCode == 201;
  }

  // ─────────────────────────────────────────
  // FEEDBACK
  // ─────────────────────────────────────────

  static Future<bool> submitFeedback({
    required int userId,
    required int rating,
    required String category,
    required String message,
  }) async {
    final res = await http.post(
      Uri.parse(AppUrl.submitFeedback),
      headers: _headers,
      body: jsonEncode({
        'user_id':  userId,
        'rating':   rating,
        'category': category,
        'message':  message,
      }),
    );
    return res.statusCode == 201;
  }

  // ─────────────────────────────────────────
  // PROFILE
  // ─────────────────────────────────────────

  static Future<Map<String, dynamic>?> getProfile(int userId) async {
    final res = await http.get(
      Uri.parse(AppUrl.profile(userId)),
      headers: _headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }

  // ─────────────────────────────────────────
  // DASHBOARD
  // ─────────────────────────────────────────

  static Future<Map<String, dynamic>?> getDashboard(int userId) async {
    final res = await http.get(
      Uri.parse(AppUrl.dashboard(userId)),
      headers: _headers,
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return null;
  }
}
