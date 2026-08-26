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

  final List<Map<String, String>> _dietOptions = [
    {'label': 'None', 'emoji': '🍽️'},
    {'label': 'Vegetarian', 'emoji': '🥦'},
    {'label': 'Vegan', 'emoji': '🌱'},
    {'label': 'High-Protein', 'emoji': '💪'},
    {'label': 'Diabetic-Friendly', 'emoji': '🩺'},
    {'label': 'Weight-Loss', 'emoji': '⚖️'},
  ];

  final List<String> _commonIngredients = [
    'Onion', 'Tomato', 'Garlic', 'Ginger', 'Potato', 'Rice',
    'Chicken', 'Eggs', 'Milk', 'Butter', 'Flour', 'Salt',
    'Cumin', 'Coriander', 'Turmeric', 'Chili', 'Paneer', 'Dal',
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
            backgroundColor: AppTheme.primary),
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
                  const SizedBox(height: 24),
                  if (_ingredients.isNotEmpty) ...[
                    Row(
                      children: [
                        Text('Added (${_ingredients.length})',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _ingredients.clear()),
                          child: Text('Clear all',
                              style: GoogleFonts.dmSans(
                                color: AppTheme.errorColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildIngredientChips(),
                    const SizedBox(height: 24),
                  ],
                  Text('Quick Add',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Type ingredient name...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppTheme.primary),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                hintStyle:
                    GoogleFonts.dmSans(color: AppTheme.textSecondary),
              ),
              onSubmitted: _addIngredient,
              textInputAction: TextInputAction.done,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ElevatedButton(
              onPressed: () => _addIngredient(_controller.text),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
      children: _ingredients
          .map((ing) => Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(ing,
                        style: GoogleFonts.dmSans(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _removeIngredient(ing),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppTheme.primary),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCommonIngredients() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _commonIngredients.map((ing) {
        final isAdded = _ingredients.contains(ing);
        return GestureDetector(
          onTap: () =>
              isAdded ? _removeIngredient(ing) : _addIngredient(ing),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isAdded ? AppTheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color:
                    isAdded ? AppTheme.primary : AppTheme.divider,
              ),
            ),
            child: Text(ing,
                style: GoogleFonts.dmSans(
                  color: isAdded
                      ? Colors.white
                      : AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Preferences',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            children: [
              // Servings
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Text('👥', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Text('Servings',
                        style: Theme.of(context).textTheme.titleLarge),
                  ]),
                  Row(
                    children: [
                      _CountButton(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          if (_servings > 1) {
                            setState(() => _servings--);
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        child: Text('$_servings',
                            style: GoogleFonts.dmSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            )),
                      ),
                      _CountButton(
                        icon: Icons.add_rounded,
                        onTap: () {
                          if (_servings < 10) {
                            setState(() => _servings++);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 28),
              // Spice Level
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    const Text('🌶️', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Text('Spice Level',
                        style: Theme.of(context).textTheme.titleLarge),
                  ]),
                  DropdownButton<String>(
                    value: _spiceLevel,
                    underline: const SizedBox(),
                    style: GoogleFonts.dmSans(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    items: _spiceLevels
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _spiceLevel = v!),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Diet Type Section
        Text('Diet Type',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Filter recipes based on your dietary needs',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        _buildDietSelector(),
      ],
    );
  }

  Widget _buildDietSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _dietOptions.map((diet) {
        final isSelected = _dietType == diet['label'];
        return GestureDetector(
          onTap: () => setState(() => _dietType = diet['label']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.divider,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(diet['emoji']!,
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(diet['label']!,
                    style: GoogleFonts.dmSans(
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomButton() {
    final dietLabel = _dietType != 'None' ? ' • $_dietType' : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _findRecipes,
          child: Text(
              'Find Recipes${_ingredients.isNotEmpty ? ' (${_ingredients.length})' : ''}$dietLabel'),
        ),
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CountButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppTheme.primary),
      ),
    );
  }
}
