import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_model.dart';
import '../services/api_service.dart';
import '../services/recipe_service.dart';
import '../theme/app_theme.dart';
import 'ingredients/enter_ingredients_screen.dart';
import 'ingredients/scan_ingredients_screen.dart';
import 'meal_planner/meal_planner_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'pantry/pantry_screen.dart';
import 'recipes/recipe_detail_screen.dart';
import 'shopping/shopping_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _userName = 'Chef';
  int _userId = 0;

  List<String> _pantryItems = [];
  List<Recipe> _recommendedRecipes = [];
  final Set<String> _favoriteRecipeIds = {};
  bool _isLoadingRecommendations = true;

  final RecipeService _recipeService = RecipeService();

  @override
  void initState() {
    super.initState();
    _loadUserAndPantry();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPantryRecommendations();
  }

  Future<void> _loadUserAndPantry() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'Chef';
      _userId = prefs.getInt('userId') ?? 0;
    });
    await _loadPantryRecommendations();
  }

  Future<void> _loadPantryRecommendations() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPantry = prefs.getStringList('pantry_ingredients') ?? [];
    final favList = prefs.getStringList('favorite_recipes') ?? [];

    setState(() {
      _pantryItems = savedPantry;
      _favoriteRecipeIds.clear();
      _favoriteRecipeIds.addAll(favList);
      _isLoadingRecommendations = true;
    });

    if (savedPantry.isEmpty) {
      if (mounted) {
        setState(() {
          _recommendedRecipes = [];
          _isLoadingRecommendations = false;
        });
      }
      return;
    }

    try {
      final resultMap = await _recipeService.getRecipes(
        ingredients: savedPantry,
        servings: 2,
        spiceLevel: 'Medium',
      );

      final List<Recipe> combined = [
        ...resultMap['fullMatch'] ?? [],
        ...resultMap['partialMatch'] ?? [],
        ...resultMap['alternatives'] ?? [],
      ];

      // Prioritize recipes with the highest number of matching pantry ingredients
      combined.sort((a, b) {
        final aMatches = _getMatchingPantryIngredients(a).length;
        final bMatches = _getMatchingPantryIngredients(b).length;
        return bMatches.compareTo(aMatches);
      });

      if (mounted) {
        setState(() {
          _recommendedRecipes = combined.take(4).toList();
          _isLoadingRecommendations = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _recommendedRecipes = [];
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  bool _isInPantry(String recipeIngredient) {
    final lowerRec = recipeIngredient.toLowerCase();
    return _pantryItems.any((p) {
      final lowerP = p.trim().toLowerCase();
      if (lowerP.isEmpty) return false;
      return lowerRec.contains(lowerP) || lowerP.contains(lowerRec);
    });
  }

  List<String> _getMatchingPantryIngredients(Recipe recipe) {
    return recipe.ingredients.where((ing) => _isInPantry(ing)).toList();
  }

  List<String> _getMissingIngredients(Recipe recipe) {
    return recipe.ingredients.where((ing) => !_isInPantry(ing)).toList();
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final prefs = await SharedPreferences.getInstance();
    final recipeKey = recipe.id.isNotEmpty ? recipe.id : recipe.title;

    setState(() {
      if (_favoriteRecipeIds.contains(recipeKey)) {
        _favoriteRecipeIds.remove(recipeKey);
      } else {
        _favoriteRecipeIds.add(recipeKey);
      }
    });

    await prefs.setStringList('favorite_recipes', _favoriteRecipeIds.toList());

    if (int.tryParse(recipe.id) != null) {
      try {
        await ApiService.toggleFavorite(int.parse(recipe.id));
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: _currentIndex == 0
          ? _buildHomePage()
          : _currentIndex == 1
              ? const FavoritesScreen()
              : _currentIndex == 2
                  ? const MealPlannerScreen()
                  : const ProfileScreen(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomePage() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildHeroBanner(),
            const SizedBox(height: 28),
            Text(
              "What's in your kitchen?",
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.3,
              ),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 4),
            Text(
              'Add ingredients and we\'ll suggest personalized recipes',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 16),
            _buildIngredientOptions(),
            const SizedBox(height: 28),

            // ONLY NEW SECTION: Recommended Recipes
            _buildRecommendedRecipesSection(),
            const SizedBox(height: 28),

            _buildQuickAccessSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good ${_getGreeting()}! 👋',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _userName.split(' ').first,
              style: GoogleFonts.playfairDisplay(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => setState(() => _currentIndex = 3),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: AppTheme.radius,
              border: Border.all(color: AppTheme.divider),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'C',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: AppTheme.radius,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'KitchenMate',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Smart Recipe Finder',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan or enter ingredients to discover delicious recipes',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EnterIngredientsScreen()),
                  ).then((_) => _loadPantryRecommendations()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Get Started →',
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text('🍽️', style: TextStyle(fontSize: 54)),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildIngredientOptions() {
    return Row(
      children: [
        Expanded(
          child: _OptionCard(
            emoji: '✏️',
            title: 'Enter\nIngredients',
            subtitle: 'Type manually',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EnterIngredientsScreen()),
            ).then((_) => _loadPantryRecommendations()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _OptionCard(
            emoji: '📷',
            title: 'Scan\nIngredients',
            subtitle: 'Upload photo',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanIngredientsScreen()),
            ).then((_) => _loadPantryRecommendations()),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 250.ms);
  }

  // -------------------------------------------------------------
  // RECOMMENDED RECIPES SECTION (Based on available Pantry items)
  // -------------------------------------------------------------
  Widget _buildRecommendedRecipesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recommended Recipes',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Personalized using items currently in your pantry',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if (_pantryItems.isNotEmpty)
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PantryScreen()),
                ).then((_) => _loadPantryRecommendations()),
                child: Text(
                  'My Pantry →',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        if (_pantryItems.isEmpty)
          _buildEmptyPantryCard()
        else if (_isLoadingRecommendations)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: AppTheme.radius,
              border: Border.all(color: AppTheme.divider),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              ),
            ),
          )
        else if (_recommendedRecipes.isEmpty)
          _buildNoRecipesCard()
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _recommendedRecipes.map((recipe) {
                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: SizedBox(
                    width: 320,
                    child: _buildRecipeCard(recipe),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildEmptyPantryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          const Text('🫙', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text(
            'Your pantry is empty',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add ingredients to your Pantry to get personalized recipe recommendations.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PantryScreen()),
            ).then((_) => _loadPantryRecommendations()),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add Ingredients'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRecipesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          const Text('🍲', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            'No matching recipes found',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add more items to your Pantry to discover dishes you can cook.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    final matched = _getMatchingPantryIngredients(recipe);
    final missing = _getMissingIngredients(recipe);
    final recipeKey = recipe.id.isNotEmpty ? recipe.id : recipe.title;
    final isFav = _favoriteRecipeIds.contains(recipeKey);

    return Container(
      height: 250,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Recipe Photo, Title & Favorite Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Accurate Recipe Photo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: const Color(0xFFF3F4F6),
                      child: Image.network(
                        _getRecipeImageUrl(recipe),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            _getCuisineEmoji(recipe.cuisine),
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 48,
                            height: 48,
                            color: const Color(0xFFF3F4F6),
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Title and Description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.title,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          recipe.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Favorite Button
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? AppTheme.errorColor : AppTheme.textTertiary,
                      size: 20,
                    ),
                    onPressed: () => _toggleFavorite(recipe),
                    tooltip: isFav ? 'Remove from favorites' : 'Save to favorites',
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Matching Pantry Ingredients Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Uses ${matched.length} pantry ingredients',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF166534),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      matched.isNotEmpty
                          ? matched.map((m) => '✓ $m').join('  ')
                          : 'No pantry ingredients matched',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF374151),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      missing.isNotEmpty
                          ? 'Missing: ${missing.join(', ')}'
                          : 'All ingredients ready in pantry!',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Pinned Bottom Row: Calories, cooking time, View Recipe Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_outlined, size: 15, color: Color(0xFFEA580C)),
                  const SizedBox(width: 3),
                  Text(
                    '${recipe.nutrition.calories} kcal',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('•', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                  const SizedBox(width: 6),
                  const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.textSecondary),
                  const SizedBox(width: 3),
                  Text(
                    '${recipe.cookingTimeMinutes}m',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
                  ).then((_) => _loadPantryRecommendations());
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: const Text('View Recipe', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRecipeImageUrl(Recipe recipe) {
    final title = recipe.title.toLowerCase();
    if (title.contains('aloo gobi') || (title.contains('gobi') && title.contains('potato'))) {
      return 'https://images.unsplash.com/photo-1589301760014-d929f3979dbc?w=300&auto=format&fit=crop&q=80';
    }
    if (title.contains('masala') && (title.contains('potato') || title.contains('roasted'))) {
      return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?w=300&auto=format&fit=crop&q=80';
    }
    if (title.contains('herb') || (title.contains('garlic') && title.contains('potato')) || title.contains('sautéed') || title.contains('sauteed')) {
      return 'https://images.unsplash.com/photo-1596797038530-2c107229654b?w=300&auto=format&fit=crop&q=80';
    }
    if (title.contains('omelette') || title.contains('egg')) {
      return 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=300&auto=format&fit=crop&q=80';
    }
    if (title.contains('potato') || title.contains('aloo')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=300&auto=format&fit=crop&q=80';
    }
    if (title.contains('curry') || title.contains('tikka') || title.contains('paneer')) {
      return 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=300&auto=format&fit=crop&q=80';
    }
    if (title.contains('rice') || title.contains('biryani') || title.contains('pulao')) {
      return 'https://images.unsplash.com/photo-1512058564366-18510be2db19?w=300&auto=format&fit=crop&q=80';
    }
    if (title.contains('pasta') || title.contains('spaghetti')) {
      return 'https://images.unsplash.com/photo-1621996346565-e3d5d6281084?w=300&auto=format&fit=crop&q=80';
    }
    if (title.contains('salad')) {
      return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=300&auto=format&fit=crop&q=80';
    }
    if (title.contains('soup')) {
      return 'https://images.unsplash.com/photo-1547592166-23ac45744acd?w=300&auto=format&fit=crop&q=80';
    }
    return 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=300&auto=format&fit=crop&q=80';
  }

  String _getCuisineEmoji(String cuisine) {
    final lower = cuisine.toLowerCase();
    if (lower.contains('indian')) return '🍛';
    if (lower.contains('italian')) return '🍝';
    if (lower.contains('mexican')) return '🌮';
    if (lower.contains('asian') || lower.contains('chinese')) return '🍜';
    if (lower.contains('salad') || lower.contains('healthy')) return '🥗';
    if (lower.contains('soup')) return '🍲';
    return '🍽️';
  }

  Widget _buildQuickAccessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        // Row 1: Pantry (🫙) & Shopping List (📝) in clean white cards
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                emoji: '🫙',
                title: 'Pantry',
                subtitle: 'Items at home',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PantryScreen()),
                ).then((_) => _loadPantryRecommendations()),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                emoji: '📝',
                title: 'Shopping List',
                subtitle: 'Items to buy',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Favorites (❤️), Meal Plan (📅), Profile (👤) in matching white cards
        Row(
          children: [
            Expanded(
              child: _QuickActionCard(
                emoji: '❤️',
                title: 'Favorites',
                subtitle: 'Saved dishes',
                onTap: () => setState(() => _currentIndex = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                emoji: '📅',
                title: 'Meal Plan',
                subtitle: 'Weekly schedule',
                onTap: () => setState(() => _currentIndex = 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickActionCard(
                emoji: '👤',
                title: 'Profile',
                subtitle: 'Account info',
                onTap: () => setState(() => _currentIndex = 3),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 350.ms);
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.cardBg,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textTertiary,
        selectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Icon(Icons.home_outlined, size: 22),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Icon(Icons.home_rounded, size: 22),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Icon(Icons.bookmark_outline_rounded, size: 22),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Icon(Icons.bookmark_rounded, size: 22),
            ),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Icon(Icons.calendar_today_outlined, size: 20),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Icon(Icons.calendar_today_rounded, size: 20),
            ),
            label: 'Planner',
          ),
          BottomNavigationBarItem(
            icon: Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Icon(Icons.person_outline_rounded, size: 22),
            ),
            activeIcon: Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Icon(Icons.person_rounded, size: 22),
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _OptionCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                height: 1.25,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: AppTheme.radius,
          border: Border.all(color: AppTheme.divider),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
                letterSpacing: -0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
