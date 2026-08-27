import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../recipes/recipe_results_screen.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final List<String> _pantryItems = [];
  final TextEditingController _addController = TextEditingController();
  bool _isLoading = true;

  static const List<String> _popularStaples = [
    'Rice',
    'Tomato',
    'Onion',
    'Potato',
    'Eggs',
    'Milk',
    'Chicken',
    'Garlic',
    'Butter',
    'Cheese',
    'Pasta',
    'Spinach',
  ];

  @override
  void initState() {
    super.initState();
    _loadPantry();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _loadPantry() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('pantry_ingredients');
    setState(() {
      _pantryItems.clear();
      if (saved != null && saved.isNotEmpty) {
        _pantryItems.addAll(saved);
      } else {
        _pantryItems.addAll(['Rice', 'Tomato', 'Onion', 'Potato', 'Eggs', 'Milk', 'Chicken']);
        _savePantry();
      }
      _isLoading = false;
    });
  }

  Future<void> _savePantry() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('pantry_ingredients', _pantryItems);
  }

  void _addIngredient(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return;

    final formatted = name.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    if (!_pantryItems.any((item) => item.toLowerCase() == formatted.toLowerCase())) {
      setState(() {
        _pantryItems.insert(0, formatted);
      });
      _savePantry();
      _addController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$formatted is already in your pantry'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _deleteIngredient(int index) {
    final removed = _pantryItems[index];
    setState(() {
      _pantryItems.removeAt(index);
    });
    _savePantry();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed $removed from pantry'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _pantryItems.insert(index, removed);
            });
            _savePantry();
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _findRecipesWithPantry() {
    if (_pantryItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some ingredients to your pantry first.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeResultsScreen(
          ingredients: List.from(_pantryItems),
          servings: 2,
          spiceLevel: 'Medium',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('My Pantry'),
        actions: [
          if (_pantryItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: _findRecipesWithPantry,
                icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                label: const Text('Find Recipes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                _buildHeaderCard(),
                _buildAddInput(),
                _buildPopularSuggestions(),
                Expanded(
                  child: _pantryItems.isEmpty ? _buildEmptyState() : _buildPantryList(),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: const Center(
              child: Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_pantryItems.length} Ingredients in Pantry',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Items you currently have in stock at home',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: AppTheme.radius,
          border: Border.all(color: AppTheme.divider),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(Icons.add_rounded, color: AppTheme.textSecondary, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: _addController,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Add an ingredient you have at home...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 13),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (val) => _addIngredient(val),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => _addIngredient(_addController.text),
                child: Text(
                  'Add',
                  style: GoogleFonts.inter(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularSuggestions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Add Staples',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _popularStaples.map((item) {
                final alreadyInPantry =
                    _pantryItems.any((p) => p.toLowerCase() == item.toLowerCase());
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(item),
                    backgroundColor: alreadyInPantry ? AppTheme.surface : AppTheme.cardBg,
                    side: BorderSide(
                      color: alreadyInPantry ? AppTheme.divider : AppTheme.divider,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: alreadyInPantry ? FontWeight.w400 : FontWeight.w500,
                      color: alreadyInPantry ? AppTheme.textTertiary : AppTheme.textPrimary,
                    ),
                    onPressed: alreadyInPantry ? null : () => _addIngredient(item),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPantryList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _pantryItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _pantryItems[index];
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: AppTheme.radius,
            border: Border.all(color: AppTheme.divider),
            boxShadow: AppTheme.cardShadow,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.divider),
              ),
              child: const Center(
                child: Icon(Icons.check_rounded, color: AppTheme.primary, size: 16),
              ),
            ),
            title: Text(
              item,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              'In stock at home',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.textTertiary),
              tooltip: 'Remove',
              onPressed: () => _deleteIngredient(index),
            ),
          ),
        ).animate().fadeIn(delay: (index * 20).ms);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
                child: Icon(Icons.inventory_2_outlined, color: AppTheme.textSecondary, size: 26),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Pantry is Empty',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add ingredients you have at home using the input above or quick-add chips.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
