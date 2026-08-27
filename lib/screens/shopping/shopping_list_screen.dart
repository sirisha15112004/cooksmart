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
        // Helpful initial demo items
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Completed Items?'),
        content: Text('Remove $completedCount purchased items from your list?'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        title: const Text('Shopping List & Notes'),
        actions: [
          if (completedCount > 0)
            IconButton(
              icon: const Icon(Icons.cleaning_services_rounded),
              tooltip: 'Clear completed items',
              onPressed: _clearCompleted,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                _buildHeaderCard(totalCount, completedCount),
                _buildAddInput(),
                const SizedBox(height: 8),
                Expanded(
                  child: _items.isEmpty ? _buildEmptyState() : _buildList(),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderCard(int total, int completed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFF9800)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text('📝', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingredients to Buy',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  total == 0
                      ? 'No items on your list'
                      : '$completed of $total items purchased • Tap checkbox to cross off',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _buildAddInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, right: 8),
              child: Icon(Icons.playlist_add_rounded, color: Color(0xFFE65100), size: 24),
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Add an ingredient to buy (e.g. Tomato, Milk)...',
                  hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: _addItem,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ElevatedButton(
                onPressed: () => _addItem(_textController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Add', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];

        return Container(
          decoration: BoxDecoration(
            color: item.isCompleted ? const Color(0xFFFAFAFA) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: item.isCompleted
                  ? Colors.grey.shade300
                  : AppTheme.divider,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            leading: Checkbox(
              value: item.isCompleted,
              activeColor: AppTheme.successColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              onChanged: (_) => _toggleItem(index),
            ),
            title: Text(
              item.name,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: item.isCompleted ? FontWeight.w500 : FontWeight.w600,
                color: item.isCompleted ? Colors.grey.shade600 : AppTheme.textPrimary,
                // Red Strikethrough line across the ingredient name when checked
                decoration: item.isCompleted ? TextDecoration.lineThrough : TextDecoration.none,
                decorationColor: Colors.red,
                decorationThickness: 2.5,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
              tooltip: 'Delete',
              onPressed: () => _deleteItem(index),
            ),
            onTap: () => _toggleItem(index),
          ),
        ).animate().fadeIn(duration: 150.ms);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🛒', style: TextStyle(fontSize: 38)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your shopping list is empty',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add the ingredients you need to buy at the store.\nChecked items will show with a red strikethrough.',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
