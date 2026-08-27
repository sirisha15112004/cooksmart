import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import 'ingredients/enter_ingredients_screen.dart';
import 'ingredients/scan_ingredients_screen.dart';
import 'meal_planner/meal_planner_screen.dart';
import 'favorites_screen.dart';
import 'profile_screen.dart';
import 'pantry/pantry_screen.dart';
import 'shopping/shopping_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _userName = 'Chef';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'Chef';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildHeader(),
            const SizedBox(height: 32),
            _buildBanner(),
            const SizedBox(height: 32),
            Text("What's in your kitchen?",
                    style: Theme.of(context).textTheme.headlineMedium)
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 6),
            Text('Add ingredients and we\'ll suggest recipes',
                    style: Theme.of(context).textTheme.bodyMedium)
                .animate()
                .fadeIn(delay: 300.ms),
            const SizedBox(height: 20),
            _buildIngredientOptions(),
            const SizedBox(height: 32),
            _buildQuickStats(),
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
            Text('Good ${_getGreeting()}! 👋',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 2),
            Text(_userName.split(' ').first,
                style: Theme.of(context).textTheme.displayMedium),
          ],
        ),
        GestureDetector(
          onTap: () => setState(() => _currentIndex = 3),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(
                _userName.isNotEmpty ? _userName[0].toUpperCase() : 'C',
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KitchenMate\nRecipe Finder',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    )),
                const SizedBox(height: 8),
                Text('Scan or type ingredients\nto discover amazing recipes',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.8),
                    )),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EnterIngredientsScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Get Started →',
                        style: GoogleFonts.dmSans(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        )),
                  ),
                ),
              ],
            ),
          ),
          const Text('🍽️', style: TextStyle(fontSize: 72)),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2);
  }

  Widget _buildIngredientOptions() {
    return Row(
      children: [
        Expanded(
          child: _OptionCard(
            emoji: '✏️',
            title: 'Enter\nIngredients',
            subtitle: 'Type manually',
            color: const Color(0xFFE8F5E9),
            borderColor: AppTheme.primary.withValues(alpha: 0.3),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const EnterIngredientsScreen())),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _OptionCard(
            emoji: '📷',
            title: 'Scan\nIngredients',
            subtitle: 'Upload photo',
            color: const Color(0xFFFFF3E0),
            borderColor: AppTheme.accent.withValues(alpha: 0.4),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ScanIngredientsScreen())),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 350.ms);
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Access', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        // Row 1: Pantry & Shopping List
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PantryScreen()),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Text('🥫', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pantry',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Items at home',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShoppingListScreen()),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('📝', style: TextStyle(fontSize: 24)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Shopping List',
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Items to buy',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row 2: Favorites, Meal Plan, Profile
        Row(
          children: [
            _StatCard(
              icon: Icons.favorite_rounded,
              label: 'Favorites',
              color: const Color(0xFFFFEBEE),
              iconColor: const Color(0xFFEF5350),
              onTap: () => setState(() => _currentIndex = 1),
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.calendar_month_rounded,
              label: 'Meal Plan',
              color: const Color(0xFFE3F2FD),
              iconColor: const Color(0xFF1E88E5),
              onTap: () => setState(() => _currentIndex = 2),
            ),
            const SizedBox(width: 12),
            _StatCard(
              icon: Icons.person_rounded,
              label: 'Profile',
              color: const Color(0xFFF3E5F5),
              iconColor: const Color(0xFF8E24AA),
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 450.ms);
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: AppTheme.textSecondary,
        selectedLabelStyle:
            GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 11),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_rounded), label: 'Favorites'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_rounded), label: 'Planner'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), label: 'Profile'),
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
  final Color color, borderColor;
  final VoidCallback onTap;

  const _OptionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 10),
            Text(title,
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.3,
                )),
            const SizedBox(height: 4),
            Text(subtitle,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, iconColor;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(height: 6),
              Text(label,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
