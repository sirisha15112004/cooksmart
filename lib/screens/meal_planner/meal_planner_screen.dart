import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});

  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final Map<String, Map<String, Map<String, dynamic>>> _plans = {};
  bool _isLoading = false;
  int _userId = 0;

  final List<Map<String, dynamic>> _mealTypes = [
    {
      'key': 'breakfast',
      'label': 'Breakfast',
      'icon': Icons.wb_sunny_outlined,
      'time': '7:00 – 9:00 AM'
    },
    {
      'key': 'lunch',
      'label': 'Lunch',
      'icon': Icons.light_mode_outlined,
      'time': '12:00 – 2:00 PM'
    },
    {
      'key': 'dinner',
      'label': 'Dinner',
      'icon': Icons.nightlight_outlined,
      'time': '7:00 – 9:00 PM'
    },
    {
      'key': 'snacks',
      'label': 'Snacks',
      'icon': Icons.local_cafe_outlined,
      'time': 'Anytime'
    },
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getInt('userId') ?? 0;
    await _loadDay(_selectedDay);
  }

  String _dateKey(DateTime d) => d.toIso8601String().split('T')[0];

  Future<void> _loadDay(DateTime day) async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getMealPlan(_userId, _dateKey(day));
      setState(() {
        _plans[_dateKey(day)] = Map<String, Map<String, dynamic>>.from(
          data.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v))),
        );
      });
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _saveMeal(String mealType, String mealName) async {
    try {
      await ApiService.saveMealPlan(
        userId: _userId,
        planDate: _dateKey(_selectedDay),
        mealType: mealType,
        mealName: mealName,
      );
      await _loadDay(_selectedDay);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save meal plan')),
        );
      }
    }
  }

  Future<void> _removeMeal(String mealType) async {
    final entry = _plans[_dateKey(_selectedDay)]?[mealType];
    if (entry == null) return;
    try {
      final id = entry['id'];
      if (id != null) await ApiService.deleteMealPlan(id);
      await _loadDay(_selectedDay);
    } catch (_) {}
  }

  void _showAddMealDialog(String mealType, String label) {
    final existing = _plans[_dateKey(_selectedDay)]?[mealType]?['meal_name'] ?? '';
    final controller = TextEditingController(text: existing);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
        title: Text(
          'Plan $label',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.inter(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Enter meal name or notes...',
            hintStyle: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 13),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _saveMeal(mealType, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Meal Planner'),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildCalendar(),
                _buildDayPlan(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2027, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
          _loadDay(selected);
        },
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          todayTextStyle: GoogleFonts.inter(
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          defaultTextStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
          weekendTextStyle: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
          selectedTextStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          markersMaxCount: 1,
          markerDecoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          leftChevronIcon: const Icon(Icons.chevron_left_rounded, color: AppTheme.textSecondary, size: 20),
          rightChevronIcon: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary, size: 20),
        ),
        eventLoader: (day) {
          final key = _dateKey(day);
          return _plans[key]?.isNotEmpty == true ? [true] : [];
        },
      ),
    ).animate().fadeIn();
  }

  Widget _buildDayPlan() {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final d = _selectedDay;
    final dateStr = '${d.day} ${months[d.month - 1]} ${d.year}';
    final isToday = isSameDay(d, DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$dateStr${isToday ? ' • Today' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ..._mealTypes.asMap().entries.map((entry) {
            final i = entry.key;
            final meal = entry.value;
            final key = meal['key'] as String;
            final planEntry = _plans[_dateKey(_selectedDay)]?[key];
            final plannedMeal = planEntry?['meal_name'] as String?;

            return _MealSlot(
              icon: meal['icon'] as IconData,
              label: meal['label'] as String,
              time: meal['time'] as String,
              plannedMeal: plannedMeal,
              onAdd: () => _showAddMealDialog(key, meal['label'] as String),
              onRemove: () => _removeMeal(key),
            ).animate().fadeIn(delay: (i * 30).ms);
          }),
        ],
      ),
    );
  }
}

class _MealSlot extends StatelessWidget {
  final IconData icon;
  final String label, time;
  final String? plannedMeal;
  final VoidCallback onAdd, onRemove;

  const _MealSlot({
    required this.icon,
    required this.label,
    required this.time,
    this.plannedMeal,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: AppTheme.radius,
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (plannedMeal != null)
                  Text(
                    plannedMeal!,
                    style: GoogleFonts.inter(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    time,
                    style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (plannedMeal != null)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.textSecondary),
                  onPressed: onAdd,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.textTertiary),
                  onPressed: onRemove,
                  tooltip: 'Remove',
                ),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppTheme.primary),
              onPressed: onAdd,
              tooltip: 'Add meal',
            ),
        ],
      ),
    );
  }
}
