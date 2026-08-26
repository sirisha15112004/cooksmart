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
  String _name  = '';
  String _email = '';
  int _favCount      = 0;
  int _recipesCount  = 0;
  int _plannedDays   = 0;
  int _userId        = 0;
  bool _isLoading    = true;

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
      _name   = prefs.getString('userName')  ?? 'Chef';
      _email  = prefs.getString('userEmail') ?? '';

      // Fetch fresh stats from backend
      final profile = await ApiService.getProfile(_userId);
      if (profile != null && mounted) {
        final stats = profile['stats'] ?? {};
        setState(() {
          _name         = profile['name'] ?? _name;
          _email        = profile['email'] ?? _email;
          _favCount     = stats['favorites'] ?? 0;
          _recipesCount = stats['recipes_saved'] ?? 0;
          _plannedDays  = stats['planned_days'] ?? 0;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Log Out?',
            style: Theme.of(context).textTheme.titleLarge),
        content: Text('Are you sure you want to sign out?',
            style: Theme.of(context).textTheme.bodyMedium),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style:
                      GoogleFonts.dmSans(color: AppTheme.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor),
            child: const Text('Log Out'),
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
    final categories = [
      'General', 'Recipes', 'UI/Design', 'Performance', 'Bug Report'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                            child: Text('💬',
                                style: TextStyle(fontSize: 20))),
                      ),
                      const SizedBox(width: 12),
                      Text('Send Feedback',
                          style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close_rounded,
                            color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text('How would you rate CookSmart?',
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final filled = i < selectedRating;
                        return GestureDetector(
                          onTap: () => setModalState(
                              () => selectedRating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4),
                            child: Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: filled
                                  ? const Color(0xFFF59E0B)
                                  : AppTheme.textSecondary,
                              size: 32,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  if (selectedRating > 0) ...[
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        ['', 'Poor 😞', 'Fair 😐', 'Good 🙂',
                            'Great 😊', 'Excellent 🤩'][selectedRating],
                        style: GoogleFonts.dmSans(
                          color: const Color(0xFFF59E0B),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Category',
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.divider,
                            ),
                          ),
                          child: Text(cat,
                              style: GoogleFonts.dmSans(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textPrimary,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text('Your Message',
                      style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: feedbackController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'Tell us what you think, report a bug...',
                      hintStyle: GoogleFonts.dmSans(
                          color: AppTheme.textSecondary, fontSize: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppTheme.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppTheme.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppTheme.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        // POST to backend
                        await ApiService.submitFeedback(
                          userId:   _userId,
                          rating:   selectedRating,
                          category: selectedCategory,
                          message:  feedbackController.text.trim(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(children: [
                                const Text('🎉',
                                    style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Text('Thanks for your feedback!',
                                    style: GoogleFonts.dmSans(
                                        fontWeight:
                                            FontWeight.w600)),
                              ]),
                              backgroundColor: AppTheme.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
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
        'subtitle': 'Get notified at meal times',
        'color': const Color(0xFF1565C0),
        'onTap': () {},
      },
      {
        'icon': Icons.feedback_outlined,
        'label': 'Send Feedback',
        'subtitle': 'Rate us or report an issue',
        'color': const Color(0xFFF59E0B),
        'onTap': _showFeedbackDialog,
      },
      {
        'icon': Icons.info_outline_rounded,
        'label': 'About CookSmart',
        'subtitle': 'Version 1.0.0',
        'color': const Color(0xFF6A1B9A),
        'onTap': () {},
      },
    ];

    return Column(
      children: items.asMap().entries.map((e) {
        final item = e.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: ListTile(
            leading: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: (item['color'] as Color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(item['icon'] as IconData,
                  color: item['color'] as Color, size: 20),
            ),
            title: Text(item['label'] as String,
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: Text(item['subtitle'] as String,
                style: GoogleFonts.dmSans(
                    color: AppTheme.textSecondary, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.textSecondary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onTap: item['onTap'] as VoidCallback,
          ),
        ).animate().fadeIn(delay: (e.key * 80 + 250).ms);
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildAvatar().animate().fadeIn().scale(),
                  const SizedBox(height: 28),
                  _buildStatsCard().animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 20),
                  _buildMenuItems(),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded,
                          color: AppTheme.errorColor),
                      label: Text('Log Out',
                          style: GoogleFonts.dmSans(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: AppTheme.errorColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 16),
                  Text('CookSmart v1.0.0',
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textSecondary, fontSize: 12))
                      .animate().fadeIn(delay: 500.ms),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    return Column(
      children: [
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.3), width: 3),
          ),
          child: Center(
            child: Text(
              _name.isNotEmpty ? _name[0].toUpperCase() : 'C',
              style: GoogleFonts.playfairDisplay(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(_name, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(_email, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(child: _StatItem(
              emoji: '❤️', label: 'Favorites', value: '$_favCount')),
          Container(width: 1, height: 48, color: AppTheme.divider),
          Expanded(child: _StatItem(
              emoji: '📅', label: 'Planned', value: '$_plannedDays')),
          Container(width: 1, height: 48, color: AppTheme.divider),
          Expanded(child: _StatItem(
              emoji: '🍳', label: 'Saved', value: '$_recipesCount')),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String emoji, label, value;
  const _StatItem(
      {required this.emoji, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(value,
            style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppTheme.textPrimary)),
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}
