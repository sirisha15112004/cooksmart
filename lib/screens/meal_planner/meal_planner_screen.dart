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
  DateTime _focusedDay  = DateTime.now();
  // date string -> meal_type -> {id, meal_name}
  final Map<String, Map<String, Map<String, dynamic>>> _plans = {};
  bool _isLoading = false;
  int _userId = 0;

  final List<Map<String, dynamic>> _mealTypes = [
    {'key': 'breakfast', 'label': 'Breakfast', 'emoji': '🌅', 'time': '7:00 – 9:00 AM'},
    {'key': 'lunch',     'label': 'Lunch',     'emoji': '☀️', 'time': '12:00 – 2:00 PM'},
    {'key': 'dinner',    'label': 'Dinner',    'emoji': '🌙', 'time': '7:00 – 9:00 PM'},
    {'key': 'snacks',    'label': 'Snacks',    'emoji': '🍎', 'time': 'Anytime'},
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
        userId:    _userId,
        planDate:  _dateKey(_selectedDay),
        mealType:  mealType,
        mealName:  mealName,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Plan $label',
            style: Theme.of(context).textTheme.titleLarge),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              hintText: 'Enter meal name or description...'),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.dmSans(color: AppTheme.textSecondary))),
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
      appBar: AppBar(
        title: const Text('Meal Planner'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildCalendar(),
            _buildDayPlan(),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.divider),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2027, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay  = focused;
          });
          _loadDay(selected);
        },
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
              color: AppTheme.primary, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.3),
              shape: BoxShape.circle),
          markersMaxCount: 1,
          markerDecoration: const BoxDecoration(
              color: AppTheme.accent, shape: BoxShape.circle),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: GoogleFonts.playfairDisplay(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          leftChevronIcon: const Icon(Icons.chevron_left_rounded,
              color: AppTheme.primary),
          rightChevronIcon: const Icon(Icons.chevron_right_rounded,
              color: AppTheme.primary),
        ),
        eventLoader: (day) {
          final key = _dateKey(day);
          return _plans[key]?.isNotEmpty == true ? [true] : [];
        },
      ),
    ).animate().fadeIn();
  }

  Widget _buildDayPlan() {
    final months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    final d = _selectedDay;
    final dateStr = '${d.day} ${months[d.month - 1]} ${d.year}';
    final isToday = isSameDay(d, DateTime.now());

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$dateStr${isToday ? ' · Today' : ''}',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary)),
            ],
          ),
          const SizedBox(height: 14),
          ..._mealTypes.asMap().entries.map((entry) {
            final i    = entry.key;
            final meal = entry.value;
            final key  = meal['key'] as String;
            final planEntry = _plans[_dateKey(_selectedDay)]?[key];
            final plannedMeal = planEntry?['meal_name'] as String?;
            return _MealSlot(
              emoji:       meal['emoji'] as String,
              label:       meal['label'] as String,
              time:        meal['time']  as String,
              plannedMeal: plannedMeal,
              onAdd:    () => _showAddMealDialog(key, meal['label'] as String),
              onRemove: () => _removeMeal(key),
            )
                .animate()
                .fadeIn(delay: (i * 80).ms)
                .slideX(begin: 0.1);
          }),
        ],
      ),
    );
  }
}

class _MealSlot extends StatelessWidget {
  final String emoji, label, time;
  final String? plannedMeal;
  final VoidCallback onAdd, onRemove;

  const _MealSlot({
    required this.emoji,
    required this.label,
    required this.time,
    this.plannedMeal,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plannedMeal != null
              ? AppTheme.primary.withValues(alpha: 0.3)
              : AppTheme.divider,
          width: plannedMeal != null ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: plannedMeal != null
                  ? AppTheme.primary.withValues(alpha: 0.1)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                if (plannedMeal != null)
                  Text(plannedMeal!,
                      style: GoogleFonts.dmSans(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis)
                else
                  Text(time,
                      style: GoogleFonts.dmSans(
                          color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (plannedMeal != null)
            Row(
              children: [
                _IconBtn(icon: Icons.edit_rounded,
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    iconColor: AppTheme.primary, onTap: onAdd),
                const SizedBox(width: 8),
                _IconBtn(icon: Icons.delete_rounded,
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    iconColor: AppTheme.errorColor, onTap: onRemove),
              ],
            )
          else
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.add_rounded,
                    size: 22, color: AppTheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color, iconColor;
  final VoidCallback onTap;
  const _IconBtn(
      {required this.icon, required this.color,
       required this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(9)),
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}
