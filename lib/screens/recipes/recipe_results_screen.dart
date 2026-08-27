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
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await RecipeService().getRecipes(
        ingredients: widget.ingredients,
        servings: widget.servings,
        spiceLevel: widget.spiceLevel,
        dietType: widget.dietType,
      );
      if (mounted) {
        setState(() {
          _recipes = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Recipe Results'),
        bottom: _isLoading
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.divider)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
                    unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w400, fontSize: 13),
                    tabs: [
                      Tab(text: 'Full Match (${_recipes['fullMatch']?.length ?? 0})'),
                      Tab(text: 'Partial (${_recipes['partialMatch']?.length ?? 0})'),
                      Tab(text: 'Alternatives (${_recipes['alternative']?.length ?? 0})'),
                    ],
                  ),
                ),
              ),
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
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
                  ),
                ),
    );
  }

  Widget _buildDietBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.eco_outlined, color: AppTheme.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            '${widget.dietType} Filter Applied',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            '${widget.ingredients.length} ingredients',
            style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
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
          const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2.5),
          const SizedBox(height: 18),
          Text(
            'Finding balanced recipes...',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Matching with ${widget.ingredients.length} ingredients',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
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
            const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              'Failed to load recipes',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(_error ?? '', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _loadRecipes, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeList(List<Recipe> recipes) {
    if (recipes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: const Center(
                  child: Icon(Icons.restaurant_menu_rounded, color: AppTheme.textSecondary, size: 22),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No recipes in this category',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      itemCount: recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _RecipeCard(
        recipe: recipes[i],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipes[i])),
        ),
      ).animate().fadeIn(delay: (i * 40).ms),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const _RecipeCard({required this.recipe, required this.onTap});

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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.divider),
              ),
              child: const Center(
                child: Icon(Icons.restaurant_rounded, color: AppTheme.primary, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.title,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Text(
                          '${recipe.matchPercentage}% match',
                          style: GoogleFonts.inter(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recipe.description,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _InfoPill(icon: Icons.schedule_rounded, text: '${recipe.cookingTimeMinutes}m'),
                      const SizedBox(width: 12),
                      _InfoPill(icon: Icons.people_outline_rounded, text: '${recipe.servings}'),
                      const SizedBox(width: 12),
                      _InfoPill(icon: Icons.whatshot_outlined, text: '${recipe.nutrition.calories} kcal'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textTertiary),
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
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}
