import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../recipes/recipe_results_screen.dart';

class ScanIngredientsScreen extends StatefulWidget {
  const ScanIngredientsScreen({super.key});

  @override
  State<ScanIngredientsScreen> createState() =>
      _ScanIngredientsScreenState();
}

class _ScanIngredientsScreenState extends State<ScanIngredientsScreen> {
  File? _imageFile;
  List<String> _scannedIngredients = [];
  bool _isScanning = false;
  bool _isScanned = false;
  int _servings = 2;
  String _spiceLevel = 'Medium';
  String _dietType = 'None';
  final _service = RecipeService();

  final List<Map<String, String>> _dietOptions = [
    {'label': 'None', 'emoji': '🍽️'},
    {'label': 'Vegetarian', 'emoji': '🥦'},
    {'label': 'Vegan', 'emoji': '🌱'},
    {'label': 'High-Protein', 'emoji': '💪'},
    {'label': 'Diabetic-Friendly', 'emoji': '🩺'},
    {'label': 'Weight-Loss', 'emoji': '⚖️'},
  ];

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, imageQuality: 80, maxWidth: 1200);
    if (picked == null) return;

    setState(() {
      _imageFile = File(picked.path);
      _isScanned = false;
      _scannedIngredients = [];
    });
    await _scanImage();
  }

  Future<void> _scanImage() async {
    if (_imageFile == null) return;
    setState(() => _isScanning = true);
    try {
      final ingredients =
          await _service.scanIngredientsFromImage(_imageFile!);
      setState(() {
        _scannedIngredients = ingredients;
        _isScanned = true;
      });
      // Save scan to backend
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getInt('userId') ?? 0;
      if (uid > 0) ApiService.saveScan(uid, ingredients);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Scan failed: $e'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _removeIngredient(String ing) {
    setState(() => _scannedIngredients.remove(ing));
  }

  void _findRecipes() {
    if (_scannedIngredients.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeResultsScreen(
          ingredients: _scannedIngredients,
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
      appBar: AppBar(title: const Text('Scan Ingredients')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImageSection(),
                  const SizedBox(height: 24),
                  if (_isScanning) _buildScanningState(),
                  if (_isScanned && !_isScanning) _buildResults(),
                ],
              ),
            ),
          ),
          if (_isScanned && _scannedIngredients.isNotEmpty)
            _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      children: [
        if (_imageFile == null)
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.divider, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      size: 36, color: AppTheme.primary),
                ),
                const SizedBox(height: 16),
                Text('Take a photo of your ingredients',
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: AppTheme.textPrimary,
                    )),
                const SizedBox(height: 6),
                Text('AI will detect ingredients automatically',
                    style: GoogleFonts.dmSans(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ).animate().fadeIn()
        else
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.file(_imageFile!,
                    width: double.infinity,
                    height: 220,
                    fit: BoxFit.cover),
              ),
              Positioned(
                top: 12, right: 12,
                child: GestureDetector(
                  onTap: () => setState(() {
                    _imageFile = null;
                    _isScanned = false;
                    _scannedIngredients = [];
                  }),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Camera'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScanningState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(
              color: AppTheme.primary, strokeWidth: 3),
          const SizedBox(height: 16),
          Text('Analyzing your ingredients...',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppTheme.textPrimary,
              )),
          const SizedBox(height: 6),
          Text('AI is identifying items in the image',
              style: GoogleFonts.dmSans(
                  color: AppTheme.textSecondary, fontSize: 13)),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Found badge
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppTheme.successColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.successColor, size: 20),
              const SizedBox(width: 8),
              Text(
                  'Found ${_scannedIngredients.length} ingredient${_scannedIngredients.length != 1 ? 's' : ''}',
                  style: GoogleFonts.dmSans(
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  )),
              const Spacer(),
              GestureDetector(
                onTap: _scanImage,
                child: Text('Rescan',
                    style: GoogleFonts.dmSans(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _scannedIngredients
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
        ),
        const SizedBox(height: 24),
        // Preferences card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            children: [
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
                      _ScanCountBtn(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          if (_servings > 1) {
                            setState(() => _servings--);
                          }
                        },
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('$_servings',
                            style: GoogleFonts.dmSans(
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                      ),
                      _ScanCountBtn(
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
                        fontSize: 14),
                    items: ['Mild', 'Medium', 'Spicy', 'Extra Spicy']
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
        // Diet type
        Text('Diet Type',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('Filter recipes based on your dietary needs',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 14),
        _buildDietSelector(),
      ],
    ).animate().fadeIn().slideY(begin: 0.2);
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
              color: isSelected ? AppTheme.primary : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.primary : AppTheme.divider,
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
          child: Text('Find Recipes →$dietLabel'),
        ),
      ),
    );
  }
}

class _ScanCountBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ScanCountBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppTheme.primary),
      ),
    );
  }
}
