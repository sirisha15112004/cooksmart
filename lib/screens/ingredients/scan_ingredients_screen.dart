import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/camera_feed/camera_feed.dart';
import '../../services/recipe_service.dart';
import '../../theme/app_theme.dart';
import '../pantry/pantry_screen.dart';
import '../recipes/recipe_results_screen.dart';

class ScanIngredientsScreen extends StatefulWidget {
  final bool autoOpenCamera;
  const ScanIngredientsScreen({super.key, this.autoOpenCamera = false});

  @override
  State<ScanIngredientsScreen> createState() => _ScanIngredientsScreenState();
}

class _ScanIngredientsScreenState extends State<ScanIngredientsScreen> {
  // Live Camera
  late final LiveCameraFeed _cameraFeed;
  bool _isCameraActive = false;
  bool _isCameraStarting = false;

  // Image Upload / Gallery
  Uint8List? _uploadedImageBytes;
  String? _uploadedImageName;

  // Detection State
  List<String> _detectedIngredients = [];
  final Set<String> _selectedIngredients = {};
  bool _isAnalyzing = false;
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
  void initState() {
    super.initState();
    _cameraFeed = getLiveCameraFeed();
    if (widget.autoOpenCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startLiveCamera();
      });
    }
  }

  @override
  void dispose() {
    _cameraFeed.stopCamera();
    _manualAddController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // REAL-TIME CAMERA WORKFLOW
  // ─────────────────────────────────────────

  Future<void> _startLiveCamera() async {
    if (_isCameraActive || _isCameraStarting) return;

    setState(() {
      _isCameraStarting = true;
      _uploadedImageBytes = null;
      _uploadedImageName = null;
      _hasAnalyzed = false;
    });

    final success = await _cameraFeed.startCamera(
      onFrameCaptured: _processLiveFrame,
    );

    if (mounted) {
      setState(() {
        _isCameraStarting = false;
        _isCameraActive = success;
      });

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access camera. Please check camera permissions.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _stopLiveCamera() {
    _cameraFeed.stopCamera();
    if (mounted) {
      setState(() {
        _isCameraActive = false;
      });
    }
  }

  Future<void> _processLiveFrame(Uint8List frameBytes) async {
    if (_isAnalyzing || !_isCameraActive) return;
    _isAnalyzing = true;

    try {
      final results = await _recipeService.scanIngredientsFromImageBytes(
        frameBytes,
        'live_camera_frame.jpg',
      );

      if (mounted && _isCameraActive && results.isNotEmpty) {
        setState(() {
          for (final item in results) {
            if (!_detectedIngredients.contains(item)) {
              _detectedIngredients.add(item);
              _selectedIngredients.add(item);
            }
          }
          _hasAnalyzed = true;
        });
      }
    } catch (_) {
    } finally {
      _isAnalyzing = false;
    }
  }

  // ─────────────────────────────────────────
  // GALLERY / IMAGE UPLOAD WORKFLOW
  // ─────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    _stopLiveCamera();

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
        _uploadedImageBytes = bytes;
        _uploadedImageName = picked.name;
        _isCameraActive = false;
        _detectedIngredients = [];
        _selectedIngredients.clear();
        _hasAnalyzed = false;
        _isAnalyzing = true;
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
          _isAnalyzing = false;
        });

        // Save scan to backend if logged in
        final prefs = await SharedPreferences.getInstance();
        final uid = prefs.getInt('userId') ?? 0;
        if (uid > 0 && results.isNotEmpty) {
          ApiService.saveScan(uid, results);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load image: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ─────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────

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

    if (itemsToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ingredients to add to pantry.')),
      );
      return;
    }

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
            // Top action buttons: [ Gallery ] and [ Scan with Ingredients ]
            _buildTopActionBar(),
            const SizedBox(height: 16),

            // Live Camera Viewfinder or Image Upload View
            if (_isCameraActive || _isCameraStarting)
              _buildLiveCameraView()
            else if (_uploadedImageBytes != null)
              _buildUploadedImageView(),

            // Detection Progress Indicator
            if (_isAnalyzing && !_isCameraActive) ...[
              const SizedBox(height: 16),
              _buildAnalyzingCard(),
            ],

            // Scan Results & Detected Items
            if (_hasAnalyzed || _detectedIngredients.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildDetectedResults(),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // UI COMPONENTS
  // ─────────────────────────────────────────

  Widget _buildTopActionBar() {
    return Row(
      children: [
        // Gallery Button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library_rounded, size: 20),
            label: const Text('Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Scan with Ingredients (Live Camera) Button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isCameraActive ? _stopLiveCamera : _startLiveCamera,
            icon: Icon(
              _isCameraActive ? Icons.stop_circle_rounded : Icons.camera_alt_rounded,
              size: 20,
            ),
            label: Text(
              _isCameraActive ? 'Stop Camera' : 'Scan with Ingredients',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _isCameraActive ? Colors.redAccent : AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveCameraView() {
    return Container(
      width: double.infinity,
      height: 360,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Live WebRTC HTML Video / Camera Preview
            if (_isCameraActive)
              Positioned.fill(child: _cameraFeed.buildPreview())
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Live Camera Top Indicator
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE CAMERA',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Live Bounding Box Overlay for Detected Ingredients
            if (_detectedIngredients.isNotEmpty)
              Positioned(
                bottom: 20,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.greenAccent, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Detected: ${_detectedIngredients.join(', ')}',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),
              ),

            // Center Viewfinder Target Grid
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Point at ingredients',
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildUploadedImageView() {
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
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.memory(
              _uploadedImageBytes!,
              fit: BoxFit.contain,
              width: double.infinity,
              alignment: Alignment.center,
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => setState(() {
                _uploadedImageBytes = null;
                _detectedIngredients = [];
                _selectedIngredients.clear();
                _hasAnalyzed = false;
              }),
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

  Widget _buildAnalyzingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 12),
          Text(
            'Analyzing visible ingredients...',
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedResults() {
    if (_detectedIngredients.isEmpty && _hasAnalyzed) {
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
              'Try scanning again with the ingredients clearly visible.',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _startLiveCamera,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('Scan with Camera'),
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
