import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../recipes/recipe_results_screen.dart';

class EnterIngredientsScreen extends StatefulWidget {
  const EnterIngredientsScreen({super.key});

  @override
  State<EnterIngredientsScreen> createState() =>
      _EnterIngredientsScreenState();
}

class _EnterIngredientsScreenState extends State<EnterIngredientsScreen> {
  final _controller = TextEditingController();
  final List<String> _ingredients = [];
  int _servings = 2;
  String _spiceLevel = 'Medium';
  String _dietType = 'None';

  final List<String> _spiceLevels = ['Mild', 'Medium', 'Spicy', 'Extra Spicy'];

  final List<String> _dietOptions = [
    'None',
    'Vegetarian',
    'Vegan',
    'High-Protein',
    'Diabetic-Friendly',
    'Weight-Loss',
  ];

  final List<String> _commonIngredients = [
    'Onion', 'Tomato', 'Garlic', 'Ginger', 'Potato', 'Rice',
    'Chicken', 'Eggs', 'Milk', 'Butter', 'Flour', 'Salt',
    'Cumin', 'Coriander', 'Turmeric', 'Chili', 'Paneer', 'Spinach',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addIngredient(String ing) {
    final trimmed = ing.trim();
    if (trimmed.isNotEmpty && !_ingredients.contains(trimmed)) {
      setState(() => _ingredients.add(trimmed));
      _controller.clear();
    }
  }

  void _removeIngredient(String ing) {
    setState(() => _ingredients.remove(ing));
  }

  void _findRecipes() {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one ingredient'),
          backgroundColor: AppTheme.textPrimary,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeResultsScreen(
          ingredients: _ingredients,
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
      backgroundColor: AppTheme.surface,
      appBar: AppBar(title: const Text('Enter Ingredients')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  if (_ingredients.isNotEmpty) ...[
                    Row(
                      children: [
                        Text(
                          'Added Ingredients (${_ingredients.length})',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _ingredients.clear()),
                          child: Text(
                            'Clear all',
                            style: GoogleFonts.inter(
                              color: AppTheme.errorColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildIngredientChips(),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    'Quick Add Staples',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildCommonIngredients(),
                  const SizedBox(height: 28),
                  _buildSettings(),
                ],
              ),
            ),
          ),
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
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
            child: Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Type ingredient name (e.g. Potato)...',
                hintStyle: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 13),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onSubmitted: _addIngredient,
              textInputAction: TextInputAction.done,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ElevatedButton(
              onPressed: () => _addIngredient(_controller.text),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _ingredients.map((ing) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ing,
                style: GoogleFonts.inter(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _removeIngredient(ing),
                child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.primary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCommonIngredients() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _commonIngredients.map((ing) {
        final isAdded = _ingredients.contains(ing);
        return ActionChip(
          label: Text(ing),
          backgroundColor: isAdded ? AppTheme.primary : AppTheme.cardBg,
          side: BorderSide(
            color: isAdded ? AppTheme.primary : AppTheme.divider,
            width: 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isAdded ? FontWeight.w600 : FontWeight.w400,
            color: isAdded ? Colors.white : AppTheme.textPrimary,
          ),
          onPressed: () => isAdded ? _removeIngredient(ing) : _addIngredient(ing),
        );
      }).toList(),
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferences',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: AppTheme.radius,
            border: Border.all(color: AppTheme.divider),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              // Servings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text('Servings', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.textSecondary, size: 20),
                        onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                      ),
                      Text('$_servings', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.textSecondary, size: 20),
                        onPressed: _servings < 10 ? () => setState(() => _servings++) : null,
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 20),
              // Spice Level
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_outlined, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text('Spice Level', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                    ],
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
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Diet Type Section
        Text('Dietary Goal', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 8),
        _buildDietSelector(),
      ],
    );
  }

  Widget _buildDietSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _dietOptions.map((diet) {
          final isSelected = _dietType == diet;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(diet),
              selected: isSelected,
              selectedColor: AppTheme.primary.withValues(alpha: 0.1),
              checkmarkColor: AppTheme.primary,
              side: BorderSide(
                color: isSelected ? AppTheme.primary : AppTheme.divider,
                width: 1,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              labelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
              ),
              onSelected: (_) => setState(() => _dietType = diet),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomButton() {
    final dietLabel = _dietType != 'None' ? ' • $_dietType' : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _findRecipes,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
          ),
          child: Text(
            'Find Recipes${_ingredients.isNotEmpty ? ' (${_ingredients.length})' : ''}$dietLabel',
          ),
        ),
      ),
    );
  }
}
