import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../pantry/pantry_screen.dart';
import '../recipes/recipe_results_screen.dart';

class EnterIngredientsScreen extends StatefulWidget {
  const EnterIngredientsScreen({super.key});

  @override
  State<EnterIngredientsScreen> createState() => _EnterIngredientsScreenState();
}

class _EnterIngredientsScreenState extends State<EnterIngredientsScreen> {
  final _controller = TextEditingController();
  final List<String> _ingredients = ['Broccoli', 'Carrot', 'Bell Pepper', 'Tomato'];
  final Set<String> _selectedIngredients = {'Broccoli', 'Carrot', 'Bell Pepper', 'Tomato'};
  int _servings = 2;
  String _spiceLevel = 'Medium';
  String _dietType = 'None';

  final List<String> _spiceLevels = ['Mild', 'Medium', 'Spicy', 'Extra Spicy'];

  final List<Map<String, String>> _dietOptions = [
    {'name': 'None', 'label': 'None', 'emoji': ''},
    {'name': 'Vegetarian', 'label': 'Vegetarian', 'emoji': '🥦 '},
    {'name': 'Vegan', 'label': 'Vegan', 'emoji': '🌱 '},
    {'name': 'High-Protein', 'label': 'High-Protein', 'emoji': '💪 '},
    {'name': 'Diabetic-Friendly', 'label': 'Diabetic-Friendly', 'emoji': '🩺 '},
    {'name': 'Weight-Loss', 'label': 'Weight-Loss', 'emoji': '⚖️ '},
  ];

  static const List<String> _commonIngredients = [
    'Onion', 'Tomato', 'Garlic', 'Potato', 'Rice', 'Eggs',
    'Chicken', 'Milk', 'Butter', 'Spinach', 'Paneer', 'Pasta',
    'Cheese', 'Carrot', 'Bell Pepper', 'Broccoli', 'Cucumber', 'Cauliflower',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addIngredient(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return;

    final formatted = name.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    if (!_ingredients.any((i) => i.toLowerCase() == formatted.toLowerCase())) {
      setState(() {
        _ingredients.add(formatted);
        _selectedIngredients.add(formatted);
      });
      _controller.clear();
    }
  }

  void _removeIngredient(String name) {
    setState(() {
      _ingredients.remove(name);
      _selectedIngredients.remove(name);
    });
  }

  void _toggleIngredient(String name) {
    setState(() {
      if (_selectedIngredients.contains(name)) {
        _selectedIngredients.remove(name);
      } else {
        _selectedIngredients.add(name);
      }
    });
  }

  Future<void> _addToPantry() async {
    final itemsToAdd = _selectedIngredients.isNotEmpty ? _selectedIngredients.toList() : _ingredients;
    if (itemsToAdd.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList('pantry_ingredients') ?? [];
    int addedCount = 0;

    for (final item in itemsToAdd) {
      if (!existing.any((e) => e.toLowerCase() == item.toLowerCase())) {
        existing.insert(0, item);
        addedCount++;
      }
    }

    await prefs.setStringList('pantry_ingredients', existing);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          addedCount > 0
              ? 'Added $addedCount item${addedCount != 1 ? 's' : ''} to My Pantry'
              : 'Selected items are already in your Pantry',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'View Pantry',
          textColor: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PantryScreen()),
            );
          },
        ),
      ),
    );
  }

  void _findRecipes() {
    final active = _selectedIngredients.isNotEmpty ? _selectedIngredients.toList() : _ingredients;
    if (active.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one ingredient.'),
          backgroundColor: AppTheme.textPrimary,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeResultsScreen(
          ingredients: List.from(active),
          servings: _servings,
          spiceLevel: _spiceLevel,
          dietType: _dietType == 'None' ? null : _dietType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Enter Ingredients'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Detected Ingredients Section
                Text(
                  'Detected Ingredients',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),

                // Ingredients List Card with Green Checkboxes
                if (_ingredients.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: _ingredients.asMap().entries.map((entry) {
                        final index = entry.key;
                        final ing = entry.value;
                        final isChecked = _selectedIngredients.contains(ing);
                        final isLast = index == _ingredients.length - 1;

                        return Column(
                          children: [
                            ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                              leading: Checkbox(
                                value: isChecked,
                                activeColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                onChanged: (_) => _toggleIngredient(ing),
                              ),
                              title: Text(
                                ing,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isChecked ? const Color(0xFF111827) : const Color(0xFF6B7280),
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF9CA3AF)),
                                tooltip: 'Remove',
                                onPressed: () => _removeIngredient(ing),
                              ),
                              onTap: () => _toggleIngredient(ing),
                            ),
                            if (!isLast) const Divider(height: 1, color: Color(0xFFF3F4F6)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Add Another Ingredient Input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 14, right: 8),
                        child: Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 20),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF111827)),
                          decoration: const InputDecoration(
                            hintText: 'Add another ingredient...',
                            hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: _addIngredient,
                        ),
                      ),
                      TextButton(
                        onPressed: () => _addIngredient(_controller.text),
                        child: Text(
                          'Add',
                          style: GoogleFonts.inter(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Suggested Common Ingredients (Quick Add)
                Text(
                  'Suggested Common Ingredients',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF4B5563)),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _commonIngredients.map((staple) {
                      final isAdded = _ingredients.any((i) => i.toLowerCase() == staple.toLowerCase());
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(staple),
                          backgroundColor: isAdded ? AppTheme.primary.withValues(alpha: 0.1) : const Color(0xFFF9FAFB),
                          side: BorderSide(
                            color: isAdded ? AppTheme.primary : const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: isAdded ? FontWeight.w600 : FontWeight.w400,
                            color: isAdded ? AppTheme.primary : const Color(0xFF374151),
                          ),
                          onPressed: () {
                            if (isAdded) {
                              _removeIngredient(staple);
                            } else {
                              _addIngredient(staple);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Recipe Preferences Subheading
                Text(
                  'Recipe Preferences',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),

                // Preferences Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Servings
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Servings',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151)),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: AppTheme.primary),
                                onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                              ),
                              Text(
                                '$_servings',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF111827)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppTheme.primary),
                                onPressed: _servings < 10 ? () => setState(() => _servings++) : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: Color(0xFFF3F4F6)),

                      // Spice Level
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Spice Level',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151)),
                          ),
                          DropdownButton<String>(
                            value: _spiceLevel,
                            underline: const SizedBox(),
                            style: GoogleFonts.inter(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            items: _spiceLevels.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (v) => setState(() => _spiceLevel = v!),
                          ),
                        ],
                      ),
                      const Divider(height: 16, color: Color(0xFFF3F4F6)),

                      // Diet Goal
                      Text(
                        'Diet Goal',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF374151)),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _dietOptions.map((opt) {
                            final isSel = _dietType == opt['name'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                avatar: isSel && opt['name'] == 'None'
                                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                    : null,
                                label: Text('${opt['emoji']}${opt['label']}'),
                                selected: isSel,
                                selectedColor: AppTheme.primary,
                                backgroundColor: const Color(0xFFF9FAFB),
                                side: BorderSide(
                                  color: isSel ? AppTheme.primary : const Color(0xFFE5E7EB),
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                labelStyle: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                                  color: isSel ? Colors.white : const Color(0xFF374151),
                                ),
                                onSelected: (_) => setState(() => _dietType = opt['name']!),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Dual Action Buttons ([ Add to Pantry ] & [ Find Recipes ])
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _addToPantry,
                        icon: const Icon(Icons.inventory_2_outlined, size: 16),
                        label: const Text('Add to Pantry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _findRecipes,
                        icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
                        label: const Text('Find Recipes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
