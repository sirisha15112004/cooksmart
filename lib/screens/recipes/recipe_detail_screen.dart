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
  int? _dbRecipeId;
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
      _showSnack('All ingredients are already in your Pantry', AppTheme.primary);
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
            'Added $addedCount missing item${addedCount != 1 ? 's' : ''} to Shopping List',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white),
          ),
          backgroundColor: AppTheme.textPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
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
      _showSnack('Missing ingredients are already in your Shopping List', AppTheme.textSecondary);
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      if (_dbRecipeId == null) {
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
          setState(() {
            _dbRecipeId = newId;
            _isFavorite = true;
          });
          _showSnack('Saved to favorites', AppTheme.primary);
        } else {
          _showSnack('Failed to save recipe', AppTheme.errorColor);
        }
        return;
      }

      final newState = await ApiService.toggleFavorite(_dbRecipeId!);
      setState(() => _isFavorite = newState);
      _showSnack(
        newState ? 'Saved to favorites' : 'Removed from favorites',
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
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppTheme.surface,
            scrolledUnderElevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 18),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: _toggleFavorite,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Icon(
                      _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                      color: _isFavorite ? AppTheme.primary : AppTheme.textSecondary,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppTheme.surface,
                child: Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.divider),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: const Center(
                      child: Icon(Icons.restaurant_menu_rounded, color: AppTheme.primary, size: 32),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _recipe.title,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Text(
                          _recipe.cuisine,
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _recipe.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _MetaPill(icon: Icons.schedule_rounded, text: '${_recipe.cookingTimeMinutes} min'),
                        const SizedBox(width: 8),
                        _MetaPill(icon: Icons.people_outline_rounded, text: '${_recipe.servings} servings'),
                        const SizedBox(width: 8),
                        _MetaPill(icon: Icons.local_fire_department_outlined, text: _recipe.spiceLevel),
                        const SizedBox(width: 8),
                        _MetaPill(icon: Icons.whatshot_outlined, text: '${_recipe.nutrition.calories} kcal'),
                        if (_recipe.dietType != null) ...[
                          const SizedBox(width: 8),
                          _MetaPill(icon: Icons.eco_outlined, text: _recipe.dietType!),
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
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
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
    final inPantryCount = _recipe.ingredients.where((i) => _isInPantry(i)).length;
    final missingCount = _recipe.ingredients.length - inPantryCount;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Pantry comparison & Shopping List integration card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: AppTheme.radius,
            border: Border.all(color: AppTheme.divider),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    missingCount == 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: missingCount == 0 ? AppTheme.primary : AppTheme.textSecondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      missingCount == 0
                          ? 'All ingredients in your Pantry'
                          : '$missingCount missing ingredient${missingCount != 1 ? 's' : ''} for this recipe',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$inPantryCount of ${_recipe.ingredients.length} items available in your Home Pantry.',
                style: GoogleFonts.inter(
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
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                    label: const Text('Add Missing to Shopping List'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ).animate().fadeIn(duration: 200.ms),
        const SizedBox(height: 16),
        // Clean list of ingredients
        ..._recipe.ingredients.asMap().entries.map((entry) {
          final i = entry.key;
          final ing = entry.value;
          final hasInPantry = _isInPantry(ing);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: AppTheme.radius,
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: hasInPantry ? AppTheme.primary : AppTheme.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    ing,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Text(
                    hasInPantry ? 'In Pantry' : 'Need to Buy',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: hasInPantry ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: (i * 20).ms);
        }),
      ],
    );
  }

  Widget _buildSteps() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _recipe.steps.length,
      itemBuilder: (ctx, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: AppTheme.radius,
          border: Border.all(color: AppTheme.divider),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: GoogleFonts.inter(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _recipe.steps[i],
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: (i * 30).ms),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: AppTheme.radius,
              border: Border.all(color: AppTheme.divider),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                Text(
                  '${n.calories}',
                  style: GoogleFonts.inter(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  'Calories per serving',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _NutritionCard(label: 'Protein', value: '${n.protein}g')),
              const SizedBox(width: 12),
              Expanded(child: _NutritionCard(label: 'Carbs', value: '${n.carbs}g')),
            ],
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _NutritionCard(label: 'Fat', value: '${n.fat}g')),
              const SizedBox(width: 12),
              Expanded(child: _NutritionCard(label: 'Fiber', value: '${n.fiber}g')),
            ],
          ).animate().fadeIn(delay: 150.ms),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final String label, value;
  const _NutritionCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
