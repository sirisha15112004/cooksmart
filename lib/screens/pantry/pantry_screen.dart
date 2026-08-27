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

  static const List<Map<String, String>> _popularStaples = [
    {'name': 'Rice', 'emoji': '🍚'},
    {'name': 'Tomato', 'emoji': '🍅'},
    {'name': 'Onion', 'emoji': '🧅'},
    {'name': 'Potato', 'emoji': '🥔'},
    {'name': 'Eggs', 'emoji': '🥚'},
    {'name': 'Milk', 'emoji': '🥛'},
    {'name': 'Chicken', 'emoji': '🍗'},
    {'name': 'Garlic', 'emoji': '🧄'},
    {'name': 'Butter', 'emoji': '🧈'},
    {'name': 'Cheese', 'emoji': '🧀'},
    {'name': 'Pasta', 'emoji': '🍝'},
    {'name': 'Spinach', 'emoji': '🥬'},
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
        // Helpful initial pantry items
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

    // Capitalize first letter of each word nicely
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
          content: Text('$formatted is already in your pantry!'),
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

  String _getFoodEmoji(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('rice')) return '🍚';
    if (lower.contains('tomato')) return '🍅';
    if (lower.contains('onion')) return '🧅';
    if (lower.contains('potato')) return '🥔';
    if (lower.contains('egg')) return '🥚';
    if (lower.contains('milk')) return '🥛';
    if (lower.contains('chicken')) return '🍗';
    if (lower.contains('garlic')) return '🧄';
    if (lower.contains('butter')) return '🧈';
    if (lower.contains('cheese')) return '🧀';
    if (lower.contains('pasta') || lower.contains('noodle')) return '🍝';
    if (lower.contains('spinach') || lower.contains('leaf')) return '🥬';
    if (lower.contains('carrot')) return '🥕';
    if (lower.contains('pepper') || lower.contains('capsicum')) return '🫑';
    if (lower.contains('chili')) return '🌶️';
    if (lower.contains('fish') || lower.contains('seafood')) return '🐟';
    if (lower.contains('bread')) return '🍞';
    if (lower.contains('oil')) return '🫒';
    if (lower.contains('salt') || lower.contains('sugar')) return '🧂';
    return '🥫';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('My Pantry'),
        actions: [
          if (_pantryItems.isNotEmpty)
            TextButton.icon(
              onPressed: _findRecipesWithPantry,
              icon: const Icon(Icons.restaurant_menu_rounded, size: 18, color: Colors.white),
              label: const Text('Cook Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          const SizedBox(width: 12),
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
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('🥫', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingredients at Home',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_pantryItems.length} ingredient${_pantryItems.length != 1 ? 's' : ''} currently available in pantry',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _buildAddInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, right: 8),
              child: Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 22),
            ),
            Expanded(
              child: TextField(
                controller: _addController,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Add an ingredient (e.g. Rice, Tomato, Eggs)...',
                  hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: _addIngredient,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ElevatedButton(
                onPressed: () => _addIngredient(_addController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Add', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularSuggestions() {
    final unaddedStaples = _popularStaples
        .where((s) => !_pantryItems.any((item) => item.toLowerCase() == s['name']!.toLowerCase()))
        .toList();

    if (unaddedStaples.isEmpty) return const SizedBox(height: 8);

    return Container(
      height: 42,
      margin: const EdgeInsets.only(top: 10, bottom: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: unaddedStaples.length,
        itemBuilder: (context, index) {
          final staple = unaddedStaples[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Text(staple['emoji']!, style: const TextStyle(fontSize: 14)),
              label: Text(
                '+ ${staple['name']}',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
              backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              onPressed: () => _addIngredient(staple['name']!),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPantryList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: _pantryItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ingredient = _pantryItems[index];
        final emoji = _getFoodEmoji(ingredient);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            title: Text(
              ingredient,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            subtitle: Text(
              'In stock at home',
              style: GoogleFonts.dmSans(fontSize: 12, color: AppTheme.successColor),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
              tooltip: 'Remove from Pantry',
              onPressed: () => _deleteIngredient(index),
            ),
          ),
        ).animate().fadeIn(duration: 200.ms);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🥫', style: TextStyle(fontSize: 38)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your pantry is empty',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add the ingredients you currently have at home\nto get customized recipe recommendations.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
