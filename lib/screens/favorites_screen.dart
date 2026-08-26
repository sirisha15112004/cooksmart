import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_model.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'recipes/recipe_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Recipe> _favorites = [];
  bool _isLoading = true;
  int _userId = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload every time this screen becomes active
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('userId') ?? 0;

      if (_userId == 0) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final data = await ApiService.getRecipes(_userId, favoritesOnly: true);
      final mapped = <Recipe>[];
      for (final r in data) {
        try {
          mapped.add(_mapToRecipe(r as Map<String, dynamic>));
        } catch (e) {
          debugPrint('Error mapping recipe: $e — data: $r');
        }
      }
      if (mounted) {
        setState(() {
          _favorites = mapped;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Recipe _mapToRecipe(Map<String, dynamic> r) {
    final n = (r['nutrition'] as Map<String, dynamic>?) ?? {};

    // Backend returns ingredients/steps already parsed as List
    // but guard against them being a JSON string just in case
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    return Recipe(
      id:                   r['id']?.toString() ?? '0',
      title:                r['title']?.toString() ?? '',
      description:          r['description']?.toString() ?? '',
      ingredients:          parseList(r['ingredients']),
      steps:                parseList(r['steps']),
      cookingTimeMinutes:   (r['cooking_time_minutes'] ?? 30).toInt(),
      servings:             (r['servings'] ?? 2).toInt(),
      spiceLevel:           r['spice_level']?.toString() ?? 'Medium',
      cuisine:              r['cuisine']?.toString() ?? 'International',
      dietType:             r['diet_type']?.toString(),
      matchType:            r['match_type']?.toString() ?? 'full',
      matchPercentage:      (r['match_percentage'] ?? 100).toInt(),
      imageEmoji:           r['image_emoji']?.toString(),
      nutrition: NutritionInfo(
        calories: (n['calories'] ?? 0).toInt(),
        protein:  (n['protein']  ?? 0).toDouble(),
        carbs:    (n['carbs']    ?? 0).toDouble(),
        fat:      (n['fat']      ?? 0).toDouble(),
        fiber:    (n['fiber']    ?? 0).toDouble(),
      ),
      isFavorite: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : _favorites.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💔', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 16),
                      Text('No favorites yet',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text('Save recipes you love here',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  color: AppTheme.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _favorites.length,
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) =>
                                RecipeDetailScreen(recipe: _favorites[i]),
                          ),
                        );
                        _loadFavorites();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                    _favorites[i].imageEmoji ?? '🍲',
                                    style: const TextStyle(fontSize: 28)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_favorites[i].title,
                                      style: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${_favorites[i].cookingTimeMinutes} min • ${_favorites[i].cuisine}',
                                      style: GoogleFonts.dmSans(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${_favorites[i].nutrition.calories} kcal • ${_favorites[i].servings} servings',
                                      style: GoogleFonts.dmSans(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.favorite_rounded,
                                color: Colors.red, size: 20),
                          ],
                        ),
                      ).animate().fadeIn(delay: (i * 80).ms),
                    ),
                  ),
                ),
    );
  }
}
