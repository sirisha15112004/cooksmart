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
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Saved Recipes'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: _favorites.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.divider),
                                ),
                                child: const Center(
                                  child: Icon(Icons.bookmark_outline_rounded, color: AppTheme.textSecondary, size: 26),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Saved Recipes',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap the bookmark icon on any recipe detail to save your favorite dishes here.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadFavorites,
                        color: AppTheme.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                          itemCount: _favorites.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => RecipeDetailScreen(recipe: _favorites[i]),
                          ),
                        );
                        _loadFavorites();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: AppTheme.radius,
                          border: Border.all(color: AppTheme.divider),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: const Center(
                                child: Icon(Icons.restaurant_menu_rounded, color: AppTheme.primary, size: 20),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _favorites[i].title,
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_favorites[i].cookingTimeMinutes} min • ${_favorites[i].cuisine} • ${_favorites[i].nutrition.calories} kcal',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.bookmark_rounded, color: AppTheme.primary, size: 20),
                          ],
                        ),
                      ).animate().fadeIn(delay: (i * 30).ms),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
