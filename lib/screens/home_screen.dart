import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe_model.dart';
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
  bool _isLoadingData = true;

  final TextEditingController _quickSearchController = TextEditingController();
  final RecipeService _recipeService = RecipeService();

  // Smart pantry items with expiry tracking
  final List<Map<String, dynamic>> _expiringItems = [
    {
      'name': 'Tomato',
      'quantity': '4 pcs',
      'daysLeft': 1,
      'status': 'Expires tomorrow',
      'recipeCount': 3,
    },
    {
      'name': 'Spinach',
      'quantity': '1 bunch',
      'daysLeft': 2,
      'status': 'Expires in 2 days',
      'recipeCount': 2,
    },
    {
      'name': 'Milk',
      'quantity': '500 ml',
      'daysLeft': 3,
      'status': 'Expires in 3 days',
      'recipeCount': 4,
    },
  ];

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

  Future<void> _loadKitchenData() async {
    setState(() => _isLoadingData = true);
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId') ?? 0;
    _userName = prefs.getString('userName') ?? 'Chef';
    _pantryItems = prefs.getStringList('pantry_ingredients') ?? ['Tomato', 'Potato', 'Onion', 'Rice', 'Eggs'];

    // Generate dynamic recipe recommendations based on pantry
    try {
      final recipesMap = await _recipeService.getRecipes(
        ingredients: _pantryItems.isNotEmpty ? _pantryItems : ['Tomato', 'Potato', 'Onion'],
        servings: 2,
        spiceLevel: 'Medium',
      );
      final list = <Recipe>[];
      if (recipesMap['fullMatch'] != null) list.addAll(recipesMap['fullMatch']!);
      if (recipesMap['partialMatch'] != null) list.addAll(recipesMap['partialMatch']!);
      if (recipesMap['alternative'] != null) list.addAll(recipesMap['alternative']!);

      _recommendedRecipes = list.take(4).toList();
    } catch (_) {}

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

  void _findRecipesForIngredient(String ing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeResultsScreen(
          ingredients: [ing, ..._pantryItems.where((p) => p.toLowerCase() != ing.toLowerCase())],
          servings: 2,
          spiceLevel: 'Medium',
        ),
      ),
    );
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
          // Sticky Top Navigation Bar
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
        return const PantryScreen();
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
  // TOP NAVIGATION BAR (Sticky, Modern, Responsive)
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
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Brand Logo & Name
              GestureDetector(
                onTap: () => setState(() => _activeNavIndex = 0),
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

              // Right Actions: Search, Notifications, Profile
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: Color(0xFF4B5563), size: 20),
                    tooltip: 'Search Recipes',
                    onPressed: () => setState(() => _activeNavIndex = 3),
                  ),
                  IconButton(
                    icon: const Icon(Icons.bookmark_outline_rounded, color: Color(0xFF4B5563), size: 20),
                    tooltip: 'Saved Recipes',
                    onPressed: () => setState(() => _activeNavIndex = 6),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _activeNavIndex = 7),
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
        ),
      ),
    );
  }

  Widget _navItem(int index, String title, IconData icon) {
    final isActive = _activeNavIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton.icon(
        onPressed: () => setState(() => _activeNavIndex = index),
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
  // HOME PAGE CONTENT (SaaS Food-Tech Web Architecture)
  // -------------------------------------------------------------
  Widget _buildHomePage(bool isDesktop, bool isTablet) {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Two-Column Hero Section
              _buildHeroSection(isDesktop, isTablet),
              const SizedBox(height: 36),

              // 2. Kitchen Overview (4 Compact Stat Cards in 1 Row)
              _buildKitchenOverviewSection(isDesktop, isTablet),
              const SizedBox(height: 36),

              // 3. Recommended for You (Dynamic Recipe Cards Grid)
              _buildRecommendedRecipesSection(isDesktop, isTablet),
              const SizedBox(height: 36),

              // 4. Use Soon Smart Pantry Section
              _buildUseSoonSection(isDesktop, isTablet),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // HERO SECTION (Modern Two-Column Layout)
  // -------------------------------------------------------------
  Widget _buildHeroSection(bool isDesktop, bool isTablet) {
    final isTwoColumn = isDesktop || isTablet;

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
      child: isTwoColumn
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: _buildHeroLeftContent()),
                const SizedBox(width: 32),
                Expanded(flex: 5, child: _buildHeroRightVisual()),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroLeftContent(),
                const SizedBox(height: 24),
                _buildHeroRightVisual(),
              ],
            ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildHeroLeftContent() {
    return Column(
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
        const SizedBox(height: 14),

        // Main Heading
        Text(
          'Cook more with what you already have.',
          style: GoogleFonts.playfairDisplay(
            fontSize: 32,
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

        // Compact Quick Search Box
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: _quickSearchController,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF111827)),
                  decoration: const InputDecoration(
                    hintText: 'Enter ingredients (e.g. Tomato, Rice, Egg)...',
                    hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _onQuickSearchSubmit(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ElevatedButton(
                  onPressed: _onQuickSearchSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Find Recipes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Two Primary CTA Buttons
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              onPressed: () => setState(() => _activeNavIndex = 1),
              icon: const Icon(Icons.photo_camera_outlined, size: 16),
              label: const Text('Scan Ingredients'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _activeNavIndex = 3),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Ingredients'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111827),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroRightVisual() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF16A34A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Live Pantry Match',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  '${_pantryItems.length} items in pantry',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF4B5563)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recipe Preview Spotlight Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x05000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Center(
                    child: Icon(Icons.soup_kitchen_outlined, color: AppTheme.primary, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _recommendedRecipes.isNotEmpty
                            ? _recommendedRecipes.first.title
                            : 'Tomato Egg Curry',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: const Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Text(
                            _recommendedRecipes.isNotEmpty
                                ? '${_recommendedRecipes.first.cookingTimeMinutes} min'
                                : '25 min',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280)),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF16A34A)),
                          const SizedBox(width: 4),
                          Text('4 / 5 Ingredients Available', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF16A34A), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '80% Match',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Instant Action Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Available: Tomato, Potato, Onion, Rice',
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280)),
              ),
              TextButton(
                onPressed: () => setState(() => _activeNavIndex = 2),
                child: Text(
                  'Manage Pantry →',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
              onPressed: () => setState(() => _activeNavIndex = 2),
              child: Text(
                'View All Details →',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4 Stat Cards Grid
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
                      subtitle: 'Active ingredients',
                      icon: Icons.inventory_2_outlined,
                      onTap: () => setState(() => _activeNavIndex = 2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _statCard(
                      title: 'Expiring Soon',
                      value: '${_expiringItems.length}',
                      subtitle: 'Need attention',
                      icon: Icons.access_time_rounded,
                      isWarning: _expiringItems.isNotEmpty,
                      onTap: () => setState(() => _activeNavIndex = 2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _statCard(
                      title: 'Saved Recipes',
                      value: '$_savedRecipesCount',
                      subtitle: 'Favorite dishes',
                      icon: Icons.bookmark_outline_rounded,
                      onTap: () => setState(() => _activeNavIndex = 6),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _statCard(
                      title: 'Meals This Week',
                      value: '$_plannedMealsCount',
                      subtitle: 'Scheduled plans',
                      icon: Icons.calendar_today_outlined,
                      onTap: () => setState(() => _activeNavIndex = 4),
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
                          subtitle: 'Active items',
                          icon: Icons.inventory_2_outlined,
                          onTap: () => setState(() => _activeNavIndex = 2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          title: 'Expiring Soon',
                          value: '${_expiringItems.length}',
                          subtitle: 'Need attention',
                          icon: Icons.access_time_rounded,
                          isWarning: _expiringItems.isNotEmpty,
                          onTap: () => setState(() => _activeNavIndex = 2),
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
                          subtitle: 'Favorite dishes',
                          icon: Icons.bookmark_outline_rounded,
                          onTap: () => setState(() => _activeNavIndex = 6),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          title: 'Meals Planned',
                          value: '$_plannedMealsCount',
                          subtitle: 'Scheduled plans',
                          icon: Icons.calendar_today_outlined,
                          onTap: () => setState(() => _activeNavIndex = 4),
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
    bool isWarning = false,
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
                color: isWarning ? const Color(0xFFFEF3C7) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isWarning ? const Color(0xFFD97706) : AppTheme.primary,
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
  // RECOMMENDED RECIPES SECTION (Dynamic Grid)
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
                  'Personalized dishes matched with your available pantry items',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _activeNavIndex = 3),
              child: Text(
                'Explore All Recipes →',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Grid of 4 Recipe Cards
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
                          mainAxisExtent: 260,
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
    // Count how many ingredients are in pantry
    final inPantryCount = recipe.ingredients.where((i) => _isInPantry(i)).length;
    final totalCount = recipe.ingredients.length;
    final matchPct = totalCount > 0 ? ((inPantryCount / totalCount) * 100).toInt() : 100;

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
            const SizedBox(height: 12),

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
            const SizedBox(height: 6),

            // Match Indicator
            Text(
              '$inPantryCount / $totalCount Ingredients Available',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: inPantryCount == totalCount ? const Color(0xFF16A34A) : const Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 6),

            // Match Percentage Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: inPantryCount == totalCount
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$matchPct% Match • Easy',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: inPantryCount == totalCount ? const Color(0xFF166534) : const Color(0xFF92400E),
                ),
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

  bool _isInPantry(String ing) {
    final lowerIng = ing.toLowerCase();
    return _pantryItems.any((p) {
      final lowerP = p.trim().toLowerCase();
      if (lowerP.isEmpty) return false;
      return lowerIng.contains(lowerP) || lowerP.contains(lowerIng);
    });
  }

  Widget _buildEmptyRecipesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.restaurant_menu_outlined, size: 36, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(
            'No matching recipes yet',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          Text(
            'Add more ingredients to your pantry or scan a photo to get personalized recipes.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // USE SOON SMART PANTRY SECTION (Expiry Tracking & Action)
  // -------------------------------------------------------------
  Widget _buildUseSoonSection(bool isDesktop, bool isTablet) {
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
                  'Use These Ingredients Soon',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Reduce food waste by cooking with items approaching expiry',
                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _activeNavIndex = 2),
              child: Text(
                'Manage Expiry Dates →',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_expiringItems.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All pantry ingredients are fresh',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF111827)),
                      ),
                      Text(
                        'No ingredients are expiring in the next 3 days.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isRow = constraints.maxWidth >= 768;
              if (isRow) {
                return Row(
                  children: _expiringItems.map((item) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _buildExpiringItemCard(item),
                      ),
                    );
                  }).toList(),
                );
              } else {
                return Column(
                  children: _expiringItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildExpiringItemCard(item),
                    );
                  }).toList(),
                );
              }
            },
          ),
      ],
    );
  }

  Widget _buildExpiringItemCard(Map<String, dynamic> item) {
    final name = item['name'] as String;
    final qty = item['quantity'] as String;
    final status = item['status'] as String;
    final recipeCount = item['recipeCount'] as int;
    final isUrgent = (item['daysLeft'] as int) <= 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUrgent ? const Color(0xFFFCA5A5) : const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF111827),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isUrgent ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isUrgent ? const Color(0xFFB91C1C) : const Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$qty in pantry • $recipeCount recipes available',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _findRecipesForIngredient(name),
              icon: const Icon(Icons.restaurant_rounded, size: 14),
              label: const Text('Find Recipes', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                elevation: 0,
              ),
            ),
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
        onTap: (i) => setState(() => _activeNavIndex = i),
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
