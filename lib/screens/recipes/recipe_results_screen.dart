import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/recipe_model.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import 'recipe_detail_screen.dart';

class RecipeResultsScreen extends StatefulWidget {
  final List<String> ingredients;
  final int servings;
  final String spiceLevel;
  final String? dietType;

  const RecipeResultsScreen({
    super.key,
    required this.ingredients,
    required this.servings,
    required this.spiceLevel,
    this.dietType,
  });

  @override
  State<RecipeResultsScreen> createState() => _RecipeResultsScreenState();
}

class _RecipeResultsScreenState extends State<RecipeResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, List<Recipe>> _recipes = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecipes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecipes() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final results = await RecipeService().getRecipes(
        ingredients: widget.ingredients,
        servings: widget.servings,
        spiceLevel: widget.spiceLevel,
        dietType: widget.dietType,
      );
      if (mounted) setState(() { _recipes = results; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // Diet display helpers
  String get _dietEmoji {
    switch (widget.dietType) {
      case 'Vegetarian': return '🥦';
      case 'Vegan': return '🌱';
      case 'High-Protein': return '💪';
      case 'Diabetic-Friendly': return '🩺';
      case 'Weight-Loss': return '⚖️';
      default: return '';
    }
  }

  Color get _dietColor {
    switch (widget.dietType) {
      case 'Vegetarian': return const Color(0xFF2E7D32);
      case 'Vegan': return const Color(0xFF1B5E20);
      case 'High-Protein': return const Color(0xFFE65100);
      case 'Diabetic-Friendly': return const Color(0xFF0277BD);
      case 'Weight-Loss': return const Color(0xFF6A1B9A);
      default: return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Results'),
        bottom: _isLoading
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primary,
                  labelStyle: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700, fontSize: 12),
                  tabs: [
                    Tab(text: '✅ Full (${_recipes['fullMatch']?.length ?? 0})'),
                    Tab(text: '🔶 Partial (${_recipes['partialMatch']?.length ?? 0})'),
                    Tab(text: '💡 Alt (${_recipes['alternative']?.length ?? 0})'),
                  ],
                ),
              ),
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    if (widget.dietType != null) _buildDietBanner(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRecipeList(_recipes['fullMatch'] ?? []),
                          _buildRecipeList(_recipes['partialMatch'] ?? []),
                          _buildRecipeList(_recipes['alternative'] ?? []),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDietBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _dietColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _dietColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(_dietEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            '${widget.dietType} recipes',
            style: GoogleFonts.dmSans(
              color: _dietColor,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            'AI filtered',
            style: GoogleFonts.dmSans(
              color: _dietColor.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
              color: AppTheme.primary, strokeWidth: 3),
          const SizedBox(height: 20),
          Text('Finding the perfect recipes...',
              style: GoogleFonts.dmSans(
                  fontSize: 16, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Text(
            widget.dietType != null
                ? '$_dietEmoji ${widget.dietType} • ${widget.ingredients.length} ingredients'
                : 'Using ${widget.ingredients.length} ingredients',
            style: GoogleFonts.dmSans(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😕', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Failed to load recipes',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(_error ?? '',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: _loadRecipes, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeList(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('No recipes in this category',
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: recipes.length,
      itemBuilder: (context, i) => _RecipeCard(
        recipe: recipes[i],
        dietColor: widget.dietType != null ? _dietColor : null,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: recipes[i])),
        ),
      ).animate().fadeIn(delay: (i * 100).ms).slideY(begin: 0.2),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final Color? dietColor;
  final VoidCallback onTap;

  const _RecipeCard(
      {required this.recipe, this.dietColor, required this.onTap});

  Color get _matchColor {
    switch (recipe.matchType) {
      case 'full': return AppTheme.successColor;
      case 'partial': return AppTheme.accent;
      default: return Colors.blue;
    }
  }

  String get _dietEmoji {
    switch (recipe.dietType) {
      case 'Vegetarian': return '🥦';
      case 'Vegan': return '🌱';
      case 'High-Protein': return '💪';
      case 'Diabetic-Friendly': return '🩺';
      case 'Weight-Loss': return '⚖️';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                  child: Text(recipe.imageEmoji ?? '🍲',
                      style: const TextStyle(fontSize: 36))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(recipe.title,
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _matchColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text('${recipe.matchPercentage}%',
                            style: GoogleFonts.dmSans(
                              color: _matchColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(recipe.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoPill(
                          icon: Icons.timer_outlined,
                          text: '${recipe.cookingTimeMinutes}m'),
                      const SizedBox(width: 8),
                      _InfoPill(
                          icon: Icons.people_outline_rounded,
                          text: '${recipe.servings}'),
                      const SizedBox(width: 8),
                      _InfoPill(
                          icon: Icons.local_fire_department_outlined,
                          text: '${recipe.nutrition.calories} kcal'),
                      if (_dietEmoji.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(_dietEmoji,
                            style: const TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppTheme.textSecondary),
        const SizedBox(width: 3),
        Text(text,
            style: GoogleFonts.dmSans(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
