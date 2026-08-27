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

  final List<Map<String, String>> _dietOptions = [
    {'label': 'None', 'emoji': '🍽️'},
    {'label': 'Vegetarian', 'emoji': '🥦'},
    {'label': 'Vegan', 'emoji': '🌱'},
    {'label': 'High-Protein', 'emoji': '💪'},
    {'label': 'Diabetic-Friendly', 'emoji': '🩺'},
    {'label': 'Weight-Loss', 'emoji': '⚖️'},
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

        // Save scan to backend if user is logged in
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
              ? 'Added $addedCount ingredient${addedCount != 1 ? 's' : ''} to Home Pantry! 🥫'
              : 'Selected ingredients are already in your Pantry!',
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('Scan Ingredients'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // If no image is selected, show prominent "Upload an Image" button
            if (_imageBytes == null) ...[
              _buildUploadPlaceholder(),
            ] else ...[
              // Uploaded Image Preview & Control buttons
              _buildImagePreviewCard(),
            ],

            // Detecting progress state
            if (_isDetecting) ...[
              const SizedBox(height: 18),
              _buildDetectingCard(),
            ],

            // Detection Results
            if (_hasAnalyzed) ...[
              const SizedBox(height: 20),
              _buildDetectionResults(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.cloud_upload_outlined, color: AppTheme.primary, size: 36),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Upload Ingredients Image',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Select a JPG, JPEG, or PNG photo of your ingredients from your computer.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploadImage,
              icon: const Icon(Icons.upload_file_rounded, size: 20),
              label: const Text(
                'Upload an Image',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Uploaded Image Preview',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _removeImage,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                  label: const Text(
                    'Remove Image',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 200, maxHeight: 380),
            color: const Color(0xFF1E293B),
            child: Image.memory(
              _imageBytes!,
              fit: BoxFit.contain,
              width: double.infinity,
              alignment: Alignment.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _uploadImage,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Upload Another Image',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          const LinearProgressIndicator(
            backgroundColor: Color(0xFFE8F5E9),
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Detecting ingredients...',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.search_off_rounded, color: Colors.orange, size: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No ingredients detected',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No ingredients detected. Please try another image.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _uploadImage,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Upload Another Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ).animate().fadeIn();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Detected Summary Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_detectedIngredients.length} Ingredient${_detectedIngredients.length != 1 ? 's' : ''} Detected',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text('Detected Ingredients', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        // Interactive Checklist of Detected Ingredients
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            children: _detectedIngredients.map((ing) {
              final isChecked = _selectedIngredients.contains(ing);
              return ListTile(
                dense: true,
                leading: Checkbox(
                  value: isChecked,
                  activeColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (_) => _toggleIngredient(ing),
                ),
                title: Text(
                  ing,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isChecked ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  tooltip: 'Remove',
                  onPressed: () => _removeIngredient(ing),
                ),
                onTap: () => _toggleIngredient(ing),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Manual Add Field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 20),
              ),
              Expanded(
                child: TextField(
                  controller: _manualAddController,
                  style: GoogleFonts.dmSans(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Add another ingredient...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => _manualAdd(),
                ),
              ),
              TextButton(
                onPressed: _manualAdd,
                child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Recipe Preferences & Options
        Text('Recipe Preferences', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _buildPreferencesCard(),
        const SizedBox(height: 24),

        // Action Buttons: [ Add to Pantry ] and [ Find Recipes ]
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addToPantry,
                icon: const Icon(Icons.kitchen_rounded, size: 20),
                label: const Text('Add to Pantry', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _findRecipes,
                icon: const Icon(Icons.restaurant_menu_rounded, size: 20),
                label: const Text('Find Recipes', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildPreferencesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Servings', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: AppTheme.primary, size: 22),
                    onPressed: _servings > 1 ? () => setState(() => _servings--) : null,
                  ),
                  Text('$_servings', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 15)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary, size: 22),
                    onPressed: _servings < 10 ? () => setState(() => _servings++) : null,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text('Diet Goal', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _dietOptions.map((opt) {
                final isSel = _dietType == opt['label'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('${opt['emoji']} ${opt['label']}'),
                    selected: isSel,
                    selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      color: isSel ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                    onSelected: (_) => setState(() => _dietType = opt['label']!),
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
