import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/recipe_model.dart';
import '../../models/shopping_item.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../shopping/shopping_list_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  late Recipe _recipe;
  bool _isFavorite = false;
  int _userId = 0;
  int? _dbRecipeId; // ID after saving to backend
  List<String> _pantryIngredients = [];

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _isFavorite = widget.recipe.isFavorite;
    _tabs = TabController(length: 3, vsync: this);
    _loadUserId();
    _loadPantry();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getInt('userId') ?? 0;
      final parsedId = int.tryParse(_recipe.id);
      if (_recipe.isFavorite && parsedId != null && parsedId > 0) {
        _dbRecipeId = parsedId;
      }
    });
  }

  Future<void> _loadPantry() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('pantry_ingredients') ?? [];
    if (mounted) {
      setState(() {
        _pantryIngredients = saved;
      });
    }
  }

  bool _isInPantry(String recipeIngredient) {
    final lowerRec = recipeIngredient.toLowerCase();
    return _pantryIngredients.any((p) {
      final lowerP = p.trim().toLowerCase();
      if (lowerP.isEmpty) return false;
      return lowerRec.contains(lowerP) || lowerP.contains(lowerRec);
    });
  }

  String _cleanIngredientName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return raw;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  Future<void> _addMissingIngredientsToShoppingList() async {
    final missing = _recipe.ingredients.where((ing) => !_isInPantry(ing)).toList();

    if (missing.isEmpty) {
      _showSnack('All ingredients are already in your Pantry! 🎉', AppTheme.successColor);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('shopping_list_items');
    List<ShoppingItem> currentItems = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        currentItems = decoded.map((m) => ShoppingItem.fromJson(m)).toList();
      } catch (_) {}
    }

    int addedCount = 0;
    for (final ing in missing) {
      final cleanName = _cleanIngredientName(ing);
      final alreadyInList = currentItems.any((item) =>
          item.name.toLowerCase() == cleanName.toLowerCase() ||
          item.name.toLowerCase() == ing.toLowerCase());

      if (!alreadyInList) {
        currentItems.insert(
          0,
          ShoppingItem(
            id: '${DateTime.now().millisecondsSinceEpoch}_$addedCount',
            name: cleanName,
            isCompleted: false,
          ),
        );
        addedCount++;
      }
    }

    if (addedCount > 0) {
      final updatedRaw = jsonEncode(currentItems.map((i) => i.toJson()).toList());
      await prefs.setString('shopping_list_items', updatedRaw);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $addedCount missing ingredient${addedCount != 1 ? 's' : ''} to Shopping List! 🛒',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          backgroundColor: const Color(0xFFE65100),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'View List',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
              );
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      _showSnack('All missing ingredients are already in your Shopping List!', Colors.orange);
    }
  }

  /// Save recipe to backend (first time), then toggle favorite
  Future<void> _toggleFavorite() async {
    try {
      if (_dbRecipeId == null) {
        // Recipe not in DB yet — save it with is_favorite = true
        final newId = await ApiService.saveRecipe({
          'user_id':              _userId,
          'title':                _recipe.title,
          'description':          _recipe.description,
          'ingredients':          _recipe.ingredients,
          'steps':                _recipe.steps,
          'cooking_time_minutes': _recipe.cookingTimeMinutes,
          'servings':             _recipe.servings,
          'spice_level':          _recipe.spiceLevel,
          'cuisine':              _recipe.cuisine,
          'diet_type':            _recipe.dietType,
          'match_type':           _recipe.matchType,
          'match_percentage':     _recipe.matchPercentage,
          'image_emoji':          _recipe.imageEmoji,
          'nutrition': {
            'calories': _recipe.nutrition.calories,
            'protein':  _recipe.nutrition.protein,
            'carbs':    _recipe.nutrition.carbs,
            'fat':      _recipe.nutrition.fat,
            'fiber':    _recipe.nutrition.fiber,
          },
          'is_favorite': true,
        });

        if (newId != null) {
          // Store the real DB id so future taps just toggle
          setState(() {
            _dbRecipeId = newId;
            _isFavorite = true;
          });
          _showSnack('❤️ Added to favorites', AppTheme.primary);
        } else {
          _showSnack('Failed to save recipe', AppTheme.errorColor);
        }
        return;
      }

      // Already in DB — just toggle favorite flag
      final newState = await ApiService.toggleFavorite(_dbRecipeId!);
      setState(() => _isFavorite = newState);
      _showSnack(
        newState ? '❤️ Added to favorites' : 'Removed from favorites',
        newState ? AppTheme.primary : AppTheme.textSecondary,
      );
    } catch (e) {
      _showSnack('Error: ${e.toString()}', AppTheme.errorColor);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppTheme.textPrimary, size: 20),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: _toggleFavorite,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: _isFavorite ? Colors.red : AppTheme.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.15),
                      AppTheme.primaryLight.withValues(alpha: 0.2)
                    ],
                  ),
                ),
                child: Center(
                  child: Text(_recipe.imageEmoji ?? '🍲',
                      style: const TextStyle(fontSize: 100)),
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: Text(_recipe.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(_recipe.cuisine,
                            style: GoogleFonts.dmSans(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(_recipe.description,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MetaPill(icon: '⏱️',
                            text: '${_recipe.cookingTimeMinutes} min'),
                        const SizedBox(width: 8),
                        _MetaPill(icon: '👥',
                            text: '${_recipe.servings} servings'),
                        const SizedBox(width: 8),
                        _MetaPill(icon: '🌶️', text: _recipe.spiceLevel),
                        const SizedBox(width: 8),
                        _MetaPill(icon: '🔥',
                            text: '${_recipe.nutrition.calories} kcal'),
                        if (_recipe.dietType != null) ...[
                          const SizedBox(width: 8),
                          _MetaPill(icon: '🥗', text: _recipe.dietType!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabs,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primary,
                    labelStyle: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    tabs: const [
                      Tab(text: 'Ingredients'),
                      Tab(text: 'Steps'),
                      Tab(text: 'Nutrition'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildIngredients(),
                  _buildSteps(),
                  _buildNutrition(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredients() {
    final inPantryCount =
        _recipe.ingredients.where((i) => _isInPantry(i)).length;
    final missingCount = _recipe.ingredients.length - inPantryCount;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Pantry comparison & Shopping List integration card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: missingCount == 0
                ? const Color(0xFFE8F5E9)
                : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: missingCount == 0
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    missingCount == 0
                        ? Icons.check_circle_rounded
                        : Icons.shopping_basket_rounded,
                    color: missingCount == 0
                        ? AppTheme.primary
                        : const Color(0xFFE65100),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      missingCount == 0
                          ? 'All ingredients in your Pantry! 🎉'
                          : '$missingCount missing ingredient${missingCount != 1 ? 's' : ''} for this recipe',
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: missingCount == 0
                            ? AppTheme.primary
                            : const Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$inPantryCount of ${_recipe.ingredients.length} items available in your Home Pantry.',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (missingCount > 0) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _addMissingIngredientsToShoppingList,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: const Text(
                      'Add Missing Ingredients to Shopping List',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 16),
        // Ingredients list with In Pantry / Need to Buy badges
        ..._recipe.ingredients.asMap().entries.map((entry) {
          final i = entry.key;
          final ing = entry.value;
          final hasInPantry = _isInPantry(ing);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: hasInPantry
                        ? AppTheme.primary
                        : Colors.orange.shade700,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ing,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasInPantry
                        ? AppTheme.primary.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasInPantry
                            ? Icons.check_circle_outline_rounded
                            : Icons.shopping_cart_outlined,
                        size: 13,
                        color: hasInPantry
                            ? AppTheme.primary
                            : const Color(0xFFE65100),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasInPantry ? 'In Pantry' : 'Need to Buy',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasInPantry
                              ? AppTheme.primary
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (i * 30).ms);
        }),
      ],
    );
  }

  Widget _buildSteps() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _recipe.steps.length,
      itemBuilder: (ctx, i) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                  color: AppTheme.primary, shape: BoxShape.circle),
              child: Center(
                child: Text('${i + 1}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Text(_recipe.steps[i],
                    style: Theme.of(ctx).textTheme.bodyLarge),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: (i * 60).ms),
    );
  }

  Widget _buildNutrition() {
    final n = _recipe.nutrition;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text('${n.calories}',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                Text('Calories per serving',
                    style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
              ],
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _NutritionCard(
                  label: 'Protein', value: '${n.protein}g',
                  color: const Color(0xFFE3F2FD))),
              const SizedBox(width: 12),
              Expanded(child: _NutritionCard(
                  label: 'Carbs', value: '${n.carbs}g',
                  color: const Color(0xFFFFF3E0))),
            ],
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _NutritionCard(
                  label: 'Fat', value: '${n.fat}g',
                  color: const Color(0xFFFCE4EC))),
              const SizedBox(width: 12),
              Expanded(child: _NutritionCard(
                  label: 'Fiber', value: '${n.fiber}g',
                  color: const Color(0xFFE8F5E9))),
            ],
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String icon, text;
  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Text('$icon $text',
          style: GoogleFonts.dmSans(
              fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _NutritionCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
