import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_model.dart';
import '../models/shopping_item.dart';
import '../services/api_service.dart';
import '../services/recipe_service.dart';
import '../theme/app_theme.dart';
import 'favorites_screen.dart';
import 'ingredients/enter_ingredients_screen.dart';
import 'ingredients/scan_ingredients_screen.dart';
import 'meal_planner/meal_planner_screen.dart';
import 'pantry/pantry_screen.dart';
import 'profile_screen.dart';
import 'recipes/recipe_detail_screen.dart';
import 'recipes/recipe_results_screen.dart';
import 'shopping/shopping_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Navigation State: 0: Home, 1: Scan, 2: Pantry, 3: Recipes, 4: Planner, 5: Shopping, 6: Favorites, 7: Profile
  int _activeNavIndex = 0;

  String _userName = 'Chef';
  int _userId = 0;
  List<String> _pantryItems = [];
  List<Recipe> _recommendedRecipes = [];
  int _savedRecipesCount = 0;
  int _plannedMealsCount = 0;
  int _shoppingItemsCount = 0;
  bool _isLoadingData = true;

  final TextEditingController _quickSearchController = TextEditingController();
  final RecipeService _recipeService = RecipeService();

  @override
  void initState() {
    super.initState();
    _loadKitchenData();
  }

  @override
  void dispose() {
    _quickSearchController.dispose();
    super.dispose();
  }

  /// Automatically updates and reloads pantry ingredients and strictly matched recipes
  Future<void> _loadKitchenData() async {
    setState(() => _isLoadingData = true);
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId') ?? 0;
    _userName = prefs.getString('userName') ?? 'Chef';
    final savedPantry = prefs.getStringList('pantry_ingredients');
    _pantryItems = savedPantry ?? ['Tomato', 'Potato', 'Onion', 'Rice'];

    // Load shopping list count
    final rawShopping = prefs.getString('shopping_list_items');
    if (rawShopping != null && rawShopping.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(rawShopping);
        final items = decoded.map((m) => ShoppingItem.fromJson(m)).toList();
        _shoppingItemsCount = items.where((i) => !i.isCompleted).length;
      } catch (_) {}
    }

    // STRICT PANTRY MATCHING:
    // A recipe appears ONLY if ALL required ingredients are present in My Pantry
    try {
      final strictList = await _recipeService.getPantryStrictRecipes(
        pantryIngredients: _pantryItems,
        servings: 2,
        spiceLevel: 'Medium',
      );
      _recommendedRecipes = strictList.take(4).toList();
    } catch (_) {
      _recommendedRecipes = [];
    }

    // Fetch stats from backend if user is logged in
    if (_userId > 0) {
      try {
        final profile = await ApiService.getProfile(_userId);
        if (profile != null) {
          final stats = profile['stats'] ?? {};
          _savedRecipesCount = stats['favorites'] ?? 0;
          _plannedMealsCount = stats['planned_days'] ?? 0;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isLoadingData = false);
    }
  }

  void _onNavTabChanged(int index) {
    setState(() => _activeNavIndex = index);
    // Whenever user navigates to Home, automatically reload the latest My Pantry items
    if (index == 0) {
      _loadKitchenData();
    }
  }

  void _onQuickSearchSubmit() {
    final text = _quickSearchController.text.trim();
    if (text.isEmpty) return;

    final ingredients = text
        .split(RegExp(r'[,+]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (ingredients.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeResultsScreen(
            ingredients: ingredients,
            servings: 2,
            spiceLevel: 'Medium',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    final isTablet = screenWidth >= 650 && screenWidth < 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: Column(
        children: [
          // Sticky Top Navigation Bar (Full Width)
          _buildTopNavigationBar(isDesktop, isTablet),

          // Main View Content
          Expanded(
            child: _buildCurrentView(isDesktop, isTablet),
          ),
        ],
      ),
      // Bottom navigation only on mobile screens (< 650px)
      bottomNavigationBar: !isDesktop && !isTablet ? _buildMobileBottomNav() : null,
    );
  }

  Widget _buildCurrentView(bool isDesktop, bool isTablet) {
    switch (_activeNavIndex) {
      case 1:
        return const ScanIngredientsScreen();
      case 2:
        return PantryScreen(onPantryChanged: () => _loadKitchenData());
      case 3:
        return const EnterIngredientsScreen();
      case 4:
        return const MealPlannerScreen();
      case 5:
        return const ShoppingListScreen();
      case 6:
        return const FavoritesScreen();
      case 7:
        return const ProfileScreen();
      case 0:
      default:
        return _buildHomePage(isDesktop, isTablet);
    }
  }

  // -------------------------------------------------------------
  // TOP NAVIGATION BAR (Full Width, Sticky, Responsive)
  // -------------------------------------------------------------
  Widget _buildTopNavigationBar(bool isDesktop, bool isTablet) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          // Brand Logo & Name
          GestureDetector(
            onTap: () => _onNavTabChanged(0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'KitchenMate',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 32),

          // Center Navigation Links (Desktop & Tablet)
          if (isDesktop || isTablet)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _navItem(0, 'Home', Icons.home_outlined),
                    _navItem(1, 'Scan Ingredients', Icons.photo_camera_outlined),
                    _navItem(2, 'My Pantry', Icons.inventory_2_outlined),
                    _navItem(3, 'Recipes', Icons.menu_book_outlined),
                    _navItem(4, 'Meal Planner', Icons.calendar_today_outlined),
                    _navItem(5, 'Shopping List', Icons.checklist_rounded),
                  ],
                ),
              ),
            )
          else
            const Spacer(),

          // Right Actions: Search, Saved Recipes, Profile
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.search_rounded, color: Color(0xFF4B5563), size: 20),
                tooltip: 'Search Recipes',
                onPressed: () => _onNavTabChanged(3),
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_outline_rounded, color: Color(0xFF4B5563), size: 20),
                tooltip: 'Saved Recipes',
                onPressed: () => _onNavTabChanged(6),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _onNavTabChanged(7),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _activeNavIndex == 7 ? AppTheme.primary : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Center(
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : 'C',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _activeNavIndex == 7 ? Colors.white : AppTheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, String title, IconData icon) {
    final isActive = _activeNavIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton.icon(
        onPressed: () => _onNavTabChanged(index),
        icon: Icon(
          icon,
          size: 16,
          color: isActive ? AppTheme.primary : const Color(0xFF4B5563),
        ),
        label: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppTheme.primary : const Color(0xFF4B5563),
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? AppTheme.primary.withValues(alpha: 0.08) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // HOME PAGE CONTENT (Full Width Layout)
  // -------------------------------------------------------------
  Widget _buildHomePage(bool isDesktop, bool isTablet) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Full-Width Hero Section
          _buildHeroSection(isDesktop, isTablet),
          const SizedBox(height: 32),

          // 2. Kitchen Overview (4 Compact Stat Cards in 1 Row)
          _buildKitchenOverviewSection(isDesktop, isTablet),
          const SizedBox(height: 32),

          // 3. Recommended for You (100% Pantry-Matched Recipes)
          _buildRecommendedRecipesSection(isDesktop, isTablet),
          const SizedBox(height: 32),

          // 4. Quick Action Pantry Banner
          _buildQuickPantryBanner(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // HERO SECTION (Full-Width, Clean, Modern Layout)
  // -------------------------------------------------------------
  Widget _buildHeroSection(bool isDesktop, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 36 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'SMART COOKING MADE SIMPLE',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Main Heading
          Text(
            'Cook more with what you already have.',
            style: GoogleFonts.playfairDisplay(
              fontSize: isDesktop ? 34 : 26,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF111827),
              letterSpacing: -0.6,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            'Upload a photo or enter your available ingredients and discover recipes personalized for your kitchen.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF4B5563),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Full-Width Quick Search Box
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 14, right: 8),
                  child: Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 20),
                ),
                Expanded(
                  child: TextField(
                    controller: _quickSearchController,
                    style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF111827)),
                    decoration: const InputDecoration(
                      hintText: 'Enter ingredients (e.g. Tomato, Rice, Egg)...',
                      hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onSubmitted: (_) => _onQuickSearchSubmit(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ElevatedButton(
                    onPressed: _onQuickSearchSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Find Recipes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Action Buttons
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => _onNavTabChanged(2),
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: const Text('Manage My Pantry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _onNavTabChanged(3),
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text('Explore Recipes'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF111827),
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // -------------------------------------------------------------
  // KITCHEN OVERVIEW (4 Compact Stat Cards in One Row on Desktop)
  // -------------------------------------------------------------
  Widget _buildKitchenOverviewSection(bool isDesktop, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Kitchen at a Glance',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
                letterSpacing: -0.2,
              ),
            ),
            TextButton(
              onPressed: () => _onNavTabChanged(2),
              child: Text(
                'View Pantry →',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4 Stat Cards Grid Full Width
        LayoutBuilder(
          builder: (context, constraints) {
            final isRow = constraints.maxWidth >= 768;
            if (isRow) {
              return Row(
                children: [
                  Expanded(
                    child: _statCard(
                      title: 'Pantry Items',
                      value: '${_pantryItems.length}',
                      subtitle: 'In stock at home',
                      icon: Icons.inventory_2_outlined,
                      onTap: () => _onNavTabChanged(2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _statCard(
                      title: 'Recipes Ready',
                      value: '${_recommendedRecipes.length}',
                      subtitle: 'Ready to cook now',
                      icon: Icons.restaurant_menu_outlined,
                      onTap: () => _onNavTabChanged(3),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _statCard(
                      title: 'Saved Recipes',
                      value: '$_savedRecipesCount',
                      subtitle: 'Favorite dishes',
                      icon: Icons.bookmark_outline_rounded,
                      onTap: () => _onNavTabChanged(6),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _statCard(
                      title: 'Shopping Items',
                      value: '$_shoppingItemsCount',
                      subtitle: 'Items to buy',
                      icon: Icons.checklist_rounded,
                      onTap: () => _onNavTabChanged(5),
                    ),
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          title: 'Pantry Items',
                          value: '${_pantryItems.length}',
                          subtitle: 'In stock',
                          icon: Icons.inventory_2_outlined,
                          onTap: () => _onNavTabChanged(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          title: 'Recipes Ready',
                          value: '${_recommendedRecipes.length}',
                          subtitle: 'Ready now',
                          icon: Icons.restaurant_menu_outlined,
                          onTap: () => _onNavTabChanged(3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          title: 'Saved Recipes',
                          value: '$_savedRecipesCount',
                          subtitle: 'Favorites',
                          icon: Icons.bookmark_outline_rounded,
                          onTap: () => _onNavTabChanged(6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          title: 'Shopping Items',
                          value: '$_shoppingItemsCount',
                          subtitle: 'To buy',
                          icon: Icons.checklist_rounded,
                          onTap: () => _onNavTabChanged(5),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x04000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // RECOMMENDED FOR YOU (100% Strictly Matched to My Pantry)
  // -------------------------------------------------------------
  Widget _buildRecommendedRecipesSection(bool isDesktop, bool isTablet) {
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
                  'Recommended for You',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Recipes matching all available ingredients in My Pantry',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                ),
              ],
            ),
            TextButton(
              onPressed: () => _onNavTabChanged(2),
              child: Text(
                'Update Pantry →',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Grid of 100% Matched Recipes (Full Width)
        _isLoadingData
            ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.primary)))
            : _recommendedRecipes.isEmpty
                ? _buildEmptyRecipesState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int crossAxisCount = 4;
                      if (width < 600) {
                        crossAxisCount = 1;
                      } else if (width < 960) {
                        crossAxisCount = 2;
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 220,
                        ),
                        itemCount: _recommendedRecipes.length,
                        itemBuilder: (context, index) {
                          return _buildRecipeCard(_recommendedRecipes[index]);
                        },
                      );
                    },
                  ),
      ],
    );
  }

  Widget _buildRecipeCard(Recipe recipe) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge and Cooking Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    recipe.cuisine,
                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF4B5563)),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF6B7280)),
                    const SizedBox(width: 4),
                    Text('${recipe.cookingTimeMinutes}m', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Recipe Name
            Text(
              recipe.title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF111827),
                letterSpacing: -0.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Clean 100% Pantry Match Badge (No match % or missing count)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF166534)),
                  const SizedBox(width: 4),
                  Text(
                    'Ready to Cook',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF166534),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),

            // View Recipe CTA
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: Text(
                  'View Recipe',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecipesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 36, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 14),
          Text(
            'No recipes available with your current pantry ingredients.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add more ingredients to My Pantry to discover recipes you can make.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => _onNavTabChanged(2),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Add to My Pantry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // QUICK PANTRY & MEAL PLANNER ACTION BANNER (Full Width)
  // -------------------------------------------------------------
  Widget _buildQuickPantryBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(Icons.auto_stories_outlined, color: AppTheme.primary, size: 24),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plan Your Weekly Meals',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Organize breakfast, lunch, and dinner with automatic shopping list generation.',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () => _onNavTabChanged(4),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Open Meal Planner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MOBILE BOTTOM NAVIGATION (Only for narrow mobile screens)
  // -------------------------------------------------------------
  Widget _buildMobileBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _activeNavIndex > 5 ? 0 : _activeNavIndex,
        onTap: (i) => _onNavTabChanged(i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: const Color(0xFF9CA3AF),
        selectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 10),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 10),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, size: 20),
            activeIcon: Icon(Icons.home_rounded, size: 20),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_camera_outlined, size: 20),
            activeIcon: Icon(Icons.photo_camera_rounded, size: 20),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined, size: 20),
            activeIcon: Icon(Icons.inventory_2_rounded, size: 20),
            label: 'Pantry',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined, size: 20),
            activeIcon: Icon(Icons.menu_book_rounded, size: 20),
            label: 'Recipes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined, size: 20),
            activeIcon: Icon(Icons.calendar_today_rounded, size: 20),
            label: 'Planner',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_rounded, size: 20),
            activeIcon: Icon(Icons.checklist_rounded, size: 20),
            label: 'Shopping',
          ),
        ],
      ),
    );
  }
}
