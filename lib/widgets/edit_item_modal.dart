import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/category_model.dart';

class EditItemModal extends StatefulWidget {
  final ChecklistItem item;

  const EditItemModal({
    super.key,
    required this.item,
  });

  @override
  State<EditItemModal> createState() => _EditItemModalState();
}

class _EditItemModalState extends State<EditItemModal> {
  late final TextEditingController _textController;
  late String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.item.text);
    _selectedCategoryId = widget.item.categoryId;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    if (_textController.text.trim().isEmpty) return;

    final appState = Provider.of<AppState>(context, listen: false);

    // Update the item text
    final updatedItem = ChecklistItem(
      id: widget.item.id,
      text: _textController.text.trim(),
      isCompleted: widget.item.isCompleted,
      categoryId: _selectedCategoryId,
      imageUrl: widget.item.imageUrl,
      description: widget.item.description,
    );

    // Update in app state
    appState.updateItem(updatedItem);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Title
              Text(
                'Edit Item',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              // Item text field
              TextField(
                controller: _textController,
                autofocus: true,
                style: TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'Enter item name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onSubmitted: (_) => _saveChanges(),
              ),
              SizedBox(height: 24),

              // Category selector
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            // Uncategorized option
                            _CategoryChip(
                              label: 'Uncategorized',
                              icon: '📝',
                              isSelected: _selectedCategoryId == null,
                              onTap: () {
                                setState(() {
                                  _selectedCategoryId = null;
                                });
                              },
                            ),
                            // Category options
                            ...appState.categories.map((category) {
                              return _CategoryChip(
                                label: category.name,
                                icon: category.icon,
                                isSelected: _selectedCategoryId == category.id,
                                onTap: () {
                                  setState(() {
                                    _selectedCategoryId = category.id;
                                  });
                                },
                              );
                            }).toList(),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
