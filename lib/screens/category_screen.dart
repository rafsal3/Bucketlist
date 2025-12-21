import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/category_model.dart';
import '../theme/app_theme.dart';

class CategoryScreen extends StatefulWidget {
  final String categoryId;

  const CategoryScreen({
    super.key,
    required this.categoryId,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final _itemController = TextEditingController();

  @override
  void dispose() {
    _itemController.dispose();
    super.dispose();
  }

  void _addItem(AppState appState) {
    if (_itemController.text.trim().isEmpty) return;

    appState.addItem(widget.categoryId, _itemController.text.trim());
    _itemController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<AppState>(
          builder: (context, appState, child) {
            final category = appState.categories.firstWhere(
              (cat) => cat.id == widget.categoryId,
            );
            return Row(
              children: [
                Text(category.icon, style: TextStyle(fontSize: 24)),
                SizedBox(width: 12),
                Text(category.name),
              ],
            );
          },
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          final category = appState.categories.firstWhere(
            (cat) => cat.id == widget.categoryId,
          );

          return Column(
            children: [
              // Progress indicator at top
              if (category.totalCount > 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${category.completedCount} of ${category.totalCount} completed',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '${(category.progress * 100).toInt()}%',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppTheme.accent,
                                ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: category.progress,
                          minHeight: 6,
                          backgroundColor: AppTheme.accentLight,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(AppTheme.accent),
                        ),
                      ),
                    ],
                  ),
                ),

              Divider(height: 1, color: AppTheme.divider),

              // Items list
              Expanded(
                child: category.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '📝',
                              style: TextStyle(fontSize: 64),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No items yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Add your first item below',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        itemCount: category.items.length,
                        itemBuilder: (context, index) {
                          final item = category.items[index];
                          return _ChecklistItemTile(
                            item: item,
                            onToggle: () {
                              appState.toggleItem(item.id);
                            },
                            onDelete: () {
                              appState.deleteItem(item.id);
                            },
                          );
                        },
                      ),
              ),

              // Add item input
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  border: Border(
                    top: BorderSide(color: AppTheme.divider),
                  ),
                ),
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _itemController,
                        decoration: InputDecoration(
                          hintText: 'Add new item...',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _addItem(appState),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: () => _addItem(appState),
                        icon: Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ChecklistItemTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ChecklistItemTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24),
        color: Colors.red.shade50,
        child: Icon(Icons.delete_outline, color: Colors.red.shade300),
      ),
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            children: [
              // Checkbox
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.isCompleted
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                    width: 2,
                  ),
                  color:
                      item.isCompleted ? AppTheme.accent : Colors.transparent,
                ),
                child: item.isCompleted
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
              SizedBox(width: 16),

              // Item text
              Expanded(
                child: Text(
                  item.text,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        decoration: item.isCompleted
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: item.isCompleted
                            ? AppTheme.completedItem
                            : AppTheme.textPrimary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
