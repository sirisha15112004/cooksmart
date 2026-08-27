import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/shopping_item.dart';
import '../../theme/app_theme.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final List<ShoppingItem> _items = [];
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('shopping_list_items');
    setState(() {
      _items.clear();
      if (raw != null && raw.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(raw);
          _items.addAll(decoded.map((m) => ShoppingItem.fromJson(m)));
        } catch (_) {}
      } else {
        _items.addAll([
          ShoppingItem(id: '1', name: 'Tomato', isCompleted: false),
          ShoppingItem(id: '2', name: 'Onion', isCompleted: false),
          ShoppingItem(id: '3', name: 'Milk', isCompleted: false),
          ShoppingItem(id: '4', name: 'Cheese', isCompleted: false),
          ShoppingItem(id: '5', name: 'Rice', isCompleted: false),
        ]);
        _saveItems();
      }
      _isLoading = false;
    });
  }

  Future<void> _saveItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_items.map((i) => i.toJson()).toList());
    await prefs.setString('shopping_list_items', raw);
  }

  void _addItem(String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return;

    final formatted = name.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');

    setState(() {
      _items.insert(
        0,
        ShoppingItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: formatted,
          isCompleted: false,
        ),
      );
    });
    _saveItems();
    _textController.clear();
  }

  void _toggleItem(int index) {
    setState(() {
      _items[index].isCompleted = !_items[index].isCompleted;
    });
    _saveItems();
  }

  void _deleteItem(int index) {
    final removed = _items[index];
    setState(() {
      _items.removeAt(index);
    });
    _saveItems();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleted "${removed.name}" from shopping list'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            setState(() {
              _items.insert(index, removed);
            });
            _saveItems();
          },
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearCompleted() {
    final completedCount = _items.where((i) => i.isCompleted).length;
    if (completedCount == 0) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radius),
        title: Text(
          'Clear Completed Items?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        content: Text(
          'Remove $completedCount purchased items from your list?',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _items.removeWhere((i) => i.isCompleted);
              });
              _saveItems();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _items.length;
    final completedCount = _items.where((i) => i.isCompleted).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Shopping List'),
        actions: [
          if (completedCount > 0)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined, size: 20),
              tooltip: 'Clear completed',
              onPressed: _clearCompleted,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  children: [
                    _buildHeaderCard(totalCount, completedCount),
                    _buildAddInput(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _items.isEmpty ? _buildEmptyState() : _buildList(),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard(int total, int completed) {
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: const Center(
                  child: Text('📝', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completed of $total Items Checked',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Check off items as you buy them',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.surface,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: AppTheme.radius,
          border: Border.all(color: AppTheme.divider),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 14, right: 8),
              child: Icon(Icons.add_rounded, color: AppTheme.textSecondary, size: 18),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Add an item to buy...',
                  hintStyle: GoogleFonts.inter(color: AppTheme.textTertiary, fontSize: 13),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: (val) => _addItem(val),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => _addItem(_textController.text),
                child: Text(
                  'Add',
                  style: GoogleFonts.inter(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: AppTheme.radius,
            border: Border.all(color: AppTheme.divider),
            boxShadow: AppTheme.cardShadow,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            leading: Checkbox(
              value: item.isCompleted,
              activeColor: AppTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (_) => _toggleItem(index),
            ),
            title: Text(
              item.name,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: item.isCompleted ? FontWeight.w400 : FontWeight.w500,
                color: item.isCompleted ? AppTheme.textSecondary : AppTheme.textPrimary,
                decoration: item.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor: Colors.red,
                decorationThickness: 2.0,
              ),
            ),
            subtitle: item.isCompleted
                ? Text(
                    'Purchased ✓',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.textTertiary),
              tooltip: 'Delete',
              onPressed: () => _deleteItem(index),
            ),
            onTap: () => _toggleItem(index),
          ),
        ).animate().fadeIn(delay: (index * 20).ms);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.divider),
              ),
              child: const Center(
                child: Text('📝', style: TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Shopping List is Empty',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Add items you need to buy or add missing recipe ingredients directly from any recipe.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
