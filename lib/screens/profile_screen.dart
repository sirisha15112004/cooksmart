import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _email = '';
  int _favCount = 0;
  int _recipesCount = 0;
  int _plannedDays = 0;
  int _userId = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('userId') ?? 0;
      _name = prefs.getString('userName') ?? 'Chef';
      _email = prefs.getString('userEmail') ?? '';

      final profile = await ApiService.getProfile(_userId);
      if (profile != null && mounted) {
        final stats = profile['stats'] ?? {};
        setState(() {
          _name = profile['name'] ?? _name;
          _email = profile['email'] ?? _email;
          _favCount = stats['favorites'] ?? 0;
          _recipesCount = stats['recipes_saved'] ?? 0;
          _plannedDays = stats['planned_days'] ?? 0;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
        title: Text(
          'Log Out',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: Text(
          'Are you sure you want to sign out of KitchenMate?',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.logout(_email);
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    int selectedRating = 0;
    String selectedCategory = 'General';
    final categories = ['General', 'Recipes', 'UI/Design', 'Performance', 'Bug Report'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: const Center(
                          child: Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary, size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Send Feedback',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: AppTheme.textPrimary),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close_rounded, color: AppTheme.textTertiary, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Rate your experience',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final filled = i < selectedRating;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedRating = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            filled ? Icons.star_rounded : Icons.star_border_rounded,
                            color: filled ? const Color(0xFFEAB308) : AppTheme.textTertiary,
                            size: 28,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Category',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((cat) {
                        final isSel = selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSel,
                            selectedColor: AppTheme.primary.withValues(alpha: 0.1),
                            side: BorderSide(color: isSel ? AppTheme.primary : AppTheme.divider),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            labelStyle: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              color: isSel ? AppTheme.primary : AppTheme.textPrimary,
                            ),
                            onSelected: (_) => setModalState(() => selectedCategory = cat),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: feedbackController,
                    maxLines: 3,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Share your feedback or suggestions...',
                      hintStyle: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ApiService.submitFeedback(
                          userId: _userId,
                          rating: selectedRating,
                          category: selectedCategory,
                          message: feedbackController.text.trim(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Thank you for your feedback!',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                              ),
                              backgroundColor: AppTheme.textPrimary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
                      ),
                      child: const Text('Submit Feedback'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItems() {
    final items = [
      {
        'icon': Icons.notifications_outlined,
        'label': 'Meal Reminders',
        'subtitle': 'Schedule meal notifications',
        'onTap': () {},
      },
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'label': 'Send Feedback',
        'subtitle': 'Rate KitchenMate or report an issue',
        'onTap': _showFeedbackDialog,
      },
      {
        'icon': Icons.info_outline_rounded,
        'label': 'About KitchenMate',
        'subtitle': 'Version 1.0.0',
        'onTap': () {},
      },
    ];

    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: AppTheme.radius,
            border: Border.all(color: AppTheme.divider),
            boxShadow: AppTheme.cardShadow,
          ),
          child: ListTile(
            leading: Icon(item['icon'] as IconData, color: AppTheme.primary, size: 20),
            title: Text(
              item['label'] as String,
              style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14, color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              item['subtitle'] as String,
              style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 12),
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppTheme.textTertiary),
            onTap: item['onTap'] as VoidCallback,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildAvatar(),
                  const SizedBox(height: 24),
                  _buildStatsCard(),
                  const SizedBox(height: 20),
                  _buildMenuItems(),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 18),
                      label: Text(
                        'Log Out',
                        style: GoogleFonts.inter(
                          color: AppTheme.errorColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppTheme.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'KitchenMate v1.0.0',
                    style: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.divider, width: 2),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Center(
            child: Text(
              _name.isNotEmpty ? _name[0].toUpperCase() : 'C',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _name,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          _email,
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              icon: Icons.bookmark_outline_rounded,
              label: 'Favorites',
              value: '$_favCount',
            ),
          ),
          Container(width: 1, height: 36, color: AppTheme.divider),
          Expanded(
            child: _StatItem(
              icon: Icons.calendar_today_outlined,
              label: 'Planned',
              value: '$_plannedDays',
            ),
          ),
          Container(width: 1, height: 36, color: AppTheme.divider),
          Expanded(
            child: _StatItem(
              icon: Icons.restaurant_menu_rounded,
              label: 'Saved',
              value: '$_recipesCount',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _StatItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
