import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../pantry/pantry_screen.dart';
import '../recipes/recipe_results_screen.dart';

class ScanIngredientsScreen extends StatefulWidget {
  const ScanIngredientsScreen({super.key});

  @override
  State<ScanIngredientsScreen> createState() => _ScanIngredientsScreenState();
}

class _ScanIngredientsScreenState extends State<ScanIngredientsScreen> {
  Uint8List? _imageBytes;
  String? _imageName;

  List<String> _detectedIngredients = [];
  final Set<String> _selectedIngredients = {};
  bool _isDetecting = false;
  bool _hasAnalyzed = false;

  int _servings = 2;
  String _spiceLevel = 'Medium';
  String _dietType = 'None';
  final _manualAddController = TextEditingController();
  final _recipeService = RecipeService();

  final List<String> _spiceLevels = ['Mild', 'Medium', 'Spicy', 'Extra Spicy'];

  final List<String> _dietOptions = [
    'None',
    'Vegetarian',
    'Vegan',
    'High-Protein',
    'Diabetic-Friendly',
    'Weight-Loss',
  ];

  @override
  void dispose() {
    _manualAddController.dispose();
    super.dispose();
  }

  Future<void> _uploadImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _detectedIngredients = [];
        _selectedIngredients.clear();
        _hasAnalyzed = false;
        _isDetecting = true;
      });

      final results = await _recipeService.scanIngredientsFromImageBytes(
        bytes,
        picked.name,
      );

      if (mounted) {
        setState(() {
          _detectedIngredients = results;
          _selectedIngredients.addAll(results);
          _hasAnalyzed = true;
          _isDetecting = false;
        });

        final prefs = await SharedPreferences.getInstance();
        final uid = prefs.getInt('userId') ?? 0;
        if (uid > 0 && results.isNotEmpty) {
          ApiService.saveScan(uid, results);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load image: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _detectedIngredients = [];
      _selectedIngredients.clear();
      _hasAnalyzed = false;
      _isDetecting = false;
    });
  }

  void _toggleIngredient(String ing) {
    setState(() {
      if (_selectedIngredients.contains(ing)) {
        _selectedIngredients.remove(ing);
      } else {
        _selectedIngredients.add(ing);
      }
    });
  }

  void _removeIngredient(String ing) {
    setState(() {
      _detectedIngredients.remove(ing);
      _selectedIngredients.remove(ing);
    });
  }

  void _manualAdd() {
    final text = _manualAddController.text.trim();
    if (text.isEmpty) return;
    final formatted = text[0].toUpperCase() + text.substring(1);
    if (!_detectedIngredients.contains(formatted)) {
      setState(() {
        _detectedIngredients.add(formatted);
        _selectedIngredients.add(formatted);
      });
    }
    _manualAddController.clear();
  }

  Future<void> _addToPantry() async {
    final itemsToAdd = _selectedIngredients.isNotEmpty
        ? _selectedIngredients.toList()
        : _detectedIngredients;

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
              ? 'Added $addedCount item${addedCount != 1 ? 's' : ''} to Home Pantry'
              : 'Selected items are already in your Pantry',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500, color: Colors.white),
        ),
        backgroundColor: AppTheme.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _findRecipes() {
    final activeIngredients = _selectedIngredients.isNotEmpty
        ? _selectedIngredients.toList()
        : _detectedIngredients;

    if (activeIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one ingredient.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeResultsScreen(
          ingredients: activeIngredients,
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
        title: const Text('Scan Ingredients'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_imageBytes == null) ...[
                  _buildUploadPlaceholder(),
                ] else ...[
                  _buildImagePreviewCard(),
                ],
                if (_isDetecting) ...[
                  const SizedBox(height: 16),
                  _buildDetectingCard(),
                ],
                if (_hasAnalyzed) ...[
                  const SizedBox(height: 20),
                  _buildDetectionResults(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.divider),
            ),
            child: const Center(
              child: Icon(Icons.cloud_upload_outlined, color: AppTheme.primary, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Upload Ingredients Photo',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select a JPG, JPEG, or PNG photo of your vegetables or food items from your device.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploadImage,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Upload an Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreviewCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Uploaded Photo',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _removeImage,
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.errorColor),
                  label: Text(
                    'Remove',
                    style: GoogleFonts.inter(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 180, maxHeight: 340),
            color: const Color(0xFF18181B),
            child: Image.memory(
              _imageBytes!,
              fit: BoxFit.contain,
              width: double.infinity,
              alignment: Alignment.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _uploadImage,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Upload Another Photo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          const LinearProgressIndicator(
            backgroundColor: AppTheme.surface,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            minHeight: 3,
          ),
          const SizedBox(height: 12),
          Text(
            'Analyzing visible ingredients...',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionResults() {
    if (_detectedIngredients.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: AppTheme.radius,
          border: Border.all(color: AppTheme.divider),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: const Center(
                child: Icon(Icons.search_off_rounded, color: AppTheme.textSecondary, size: 24),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No ingredients detected',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please ensure the photo is clear and try another image.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _uploadImage,
              icon: const Icon(Icons.photo_library_outlined, size: 16),
              label: const Text('Try Another Photo'),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Detected Ingredients (${_detectedIngredients.length})',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Clean white list card with 1px dividers
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: AppTheme.radius,
            border: Border.all(color: AppTheme.divider),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: _detectedIngredients.asMap().entries.map((entry) {
              final i = entry.key;
              final ing = entry.value;
              final isChecked = _selectedIngredients.contains(ing);
              final isLast = i == _detectedIngredients.length - 1;

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
                        color: isChecked ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textTertiary),
                      tooltip: 'Remove',
                      onPressed: () => _removeIngredient(ing),
                    ),
                    onTap: () => _toggleIngredient(ing),
                  ),
                  if (!isLast) const Divider(height: 1, color: AppTheme.divider),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Clean Manual Add Input
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: AppTheme.radius,
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14, right: 8),
                child: Icon(Icons.add_rounded, color: AppTheme.textSecondary, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: _manualAddController,
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Add another ingredient...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _manualAdd(),
                ),
              ),
              TextButton(
                onPressed: _manualAdd,
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
        const SizedBox(height: 24),

        Text('Recipe Preferences', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 10),
        _buildPreferencesCard(),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addToPantry,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Add to Pantry'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _findRecipes,
                icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                label: const Text('Find Recipes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildPreferencesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Servings',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.textPrimary),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.textSecondary, size: 20),
                    onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                  ),
                  Text('$_servings', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.textSecondary, size: 20),
                    onPressed: _servings < 10 ? () => setState(() => _servings++) : null,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spice Level',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.textPrimary),
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
          const Divider(height: 1),
          const SizedBox(height: 12),
          Text(
            'Dietary Goal',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _dietOptions.map((opt) {
                final isSel = _dietType == opt;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(opt),
                    selected: isSel,
                    selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                    checkmarkColor: AppTheme.primary,
                    side: BorderSide(
                      color: isSel ? AppTheme.primary : AppTheme.divider,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                      color: isSel ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                    onSelected: (_) => setState(() => _dietType = opt),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
