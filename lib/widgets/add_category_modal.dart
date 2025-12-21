import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class AddCategoryModal extends StatefulWidget {
  const AddCategoryModal({super.key});

  @override
  State<AddCategoryModal> createState() => _AddCategoryModalState();
}

class _AddCategoryModalState extends State<AddCategoryModal> {
  final _nameController = TextEditingController();
  String _selectedEmoji = '📝';

  final List<String> _emojiOptions = [
    '📝',
    '✨',
    '🎨',
    '💼',
    '🏃',
    '🍳',
    '🌱',
    '💡',
    '🎯',
    '🚀',
    '🎪',
    '🎭',
    '🎸',
    '⚽',
    '🏔️',
    '🌊',
    '☕',
    '🍕',
    '🎮',
    '📷',
    '✈️',
    '🏖️',
    '🎓',
    '💪',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _createCategory() {
    if (_nameController.text.trim().isEmpty) return;

    final appState = Provider.of<AppState>(context, listen: false);
    appState.addCategory(_nameController.text.trim(), _selectedEmoji);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Add Category',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          SizedBox(height: 24),

          // Category Name Input
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Category name',
            ),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _createCategory(),
          ),
          SizedBox(height: 24),

          // Emoji Picker
          Text(
            'Choose an icon',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: 12),
          Container(
            height: 80,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _emojiOptions.length,
              itemBuilder: (context, index) {
                final emoji = _emojiOptions[index];
                final isSelected = emoji == _selectedEmoji;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedEmoji = emoji;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentLight
                          : AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.accent : AppTheme.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 24),

          // Create Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _createCategory,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Create Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
