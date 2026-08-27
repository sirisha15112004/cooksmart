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
  State<ScanIngredientsScreen> createState() =>
      _ScanIngredientsScreenState();
}

class _ScanIngredientsScreenState extends State<ScanIngredientsScreen> {
  Uint8List? _imageBytes;
  String? _imageName;
  List<String> _scannedIngredients = [];
  final Set<String> _selectedIngredients = {};
  bool _isScanning = false;
  bool _isScanned = false;
  int _servings = 2;
  String _spiceLevel = 'Medium';
  String _dietType = 'None';
  final _manualAddController = TextEditingController();
  final _service = RecipeService();

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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _isScanned = false;
        _scannedIngredients = [];
        _selectedIngredients.clear();
      });
      await _scanImage();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to access camera/image: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _scanImage() async {
    if (_imageBytes == null) return;
    setState(() => _isScanning = true);
    try {
      final ingredients = await _service.scanIngredientsFromImageBytes(
        _imageBytes!,
        _imageName,
      );
      setState(() {
        _scannedIngredients = ingredients;
        _selectedIngredients.addAll(ingredients);
        _isScanned = true;
      });
      // Save scan to backend if user is logged in
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('userId') ?? 0;
      if (uid > 0 && ingredients.isNotEmpty) {
        ApiService.saveScan(uid, ingredients);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scan note: $e'),
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
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
      _scannedIngredients.remove(ing);
      _selectedIngredients.remove(ing);
    });
  }

  void _manualAdd() {
    final text = _manualAddController.text.trim();
    if (text.isEmpty) return;
    final formatted = text[0].toUpperCase() + text.substring(1);
    if (!_scannedIngredients.contains(formatted)) {
      setState(() {
        _scannedIngredients.add(formatted);
        _selectedIngredients.add(formatted);
      });
    }
    _manualAddController.clear();
  }

  Future<void> _addToPantry() async {
    final itemsToAdd = _selectedIngredients.isNotEmpty
        ? _selectedIngredients.toList()
        : _scannedIngredients;

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
        : _scannedIngredients;

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

  void _resetScan() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _scannedIngredients = [];
      _selectedIngredients.clear();
      _isScanned = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('Scan Ingredients'),
        actions: [
          if (_imageBytes != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Scan Again',
              onPressed: _resetScan,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageCard(),
            const SizedBox(height: 16),
            _buildCaptureButtons(),
            const SizedBox(height: 20),
            if (_isScanning) _buildScanningProgress(),
            if (_isScanned) _buildScanResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 220, maxHeight: 380),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.memory(
                _imageBytes!,
                fit: BoxFit.contain,
                width: double.infinity,
                alignment: Alignment.center,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Point Camera or Upload Photo',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Point your device camera at ingredients or upload an image to scan instantly.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          if (_imageBytes != null)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: _resetScan,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCaptureButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded, size: 20),
            label: const Text('Upload Image', style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded, size: 20),
            label: const Text('Scan with Camera', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScanningProgress() {
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
          Text(
            'Analyzing visible food items...',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanResults() {
    if (_scannedIngredients.isEmpty) {
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
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.search_off_rounded, color: Colors.orange, size: 30),
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
              'Try scanning again with the ingredients clearly visible.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Scan Again'),
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
        // Detected header
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
                  '${_scannedIngredients.length} Ingredient${_scannedIngredients.length != 1 ? 's' : ''} Detected',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _pickImage(ImageSource.camera),
                child: const Text('Rescan', style: TextStyle(fontWeight: FontWeight.bold)),
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
            children: _scannedIngredients.map((ing) {
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
        // Action Buttons: Add to Pantry and Find Recipes
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
