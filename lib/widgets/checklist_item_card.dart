import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/category_model.dart';
import '../providers/app_state.dart';

class ChecklistItemCard extends StatelessWidget {
  final ChecklistItem item;
  final AppState appState;
  final bool enableDrag;
  final int? index;

  const ChecklistItemCard({
    Key? key,
    required this.item,
    required this.appState,
    this.enableDrag = false,
    this.index,
  }) : super(key: key);

  void _showItemDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
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
                    color: AppTheme.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Title
              Text(
                item.text,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),

              // Image
              if (item.imageUrl != null) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      item.imageUrl!,
                      height: 300,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 300,
                        width: 200,
                        color: Colors.grey[300],
                        child: Icon(Icons.movie,
                            size: 64, color: Colors.grey[600]),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],

              // Description
              if (item.description != null && item.description!.isNotEmpty) ...[
                Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  item.description!,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 24),
              ],

              Divider(color: AppTheme.textSecondary.withOpacity(0.1)),
              SizedBox(height: 8),

              // Actions List
              // Mark Done/Undone
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.isCompleted
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    color: AppTheme.accent,
                  ),
                ),
                title: Text(
                  item.isCompleted ? 'Mark as Undone' : 'Mark as Done',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  appState.toggleItem(item.id);
                  Navigator.pop(context);
                },
              ),

              // Move to Category
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.textPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(Icons.folder_outlined, color: AppTheme.textPrimary),
                ),
                title: Text(
                  'Move to Category',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showCategoryPicker(context);
                },
              ),

              // Delete
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.delete_outlined, color: Colors.red),
                ),
                title: Text(
                  'Delete Item',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  appState.deleteItem(item.id);
                  Navigator.pop(context);
                },
              ),

              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24),

              Text(
                'Move to Category',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 24),

              // Uncategorized option
              ListTile(
                leading: Text('📝', style: TextStyle(fontSize: 24)),
                title: Text('Uncategorized'),
                onTap: () {
                  appState.moveItemToCategory(item.id, null);
                  Navigator.pop(context);
                },
              ),

              // Categories
              ...appState.categories.map((category) {
                return ListTile(
                  leading: Text(category.icon, style: TextStyle(fontSize: 24)),
                  title: Text(category.name),
                  onTap: () {
                    appState.moveItemToCategory(item.id, category.id);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Find the category for this item
    String categoryLabel = 'Uncategorized';
    String categoryIcon = '📝';

    if (item.categoryId != null) {
      try {
        final category = appState.categories.firstWhere(
          (cat) => cat.id == item.categoryId,
        );
        categoryLabel = category.name;
        categoryIcon = category.icon;
      } catch (e) {
        // Category not found, keep default
      }
    }

    return GestureDetector(
      onTap: () => _showItemDetails(context),
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => appState.toggleItem(item.id),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.isCompleted
                        ? AppTheme.accent
                        : AppTheme.textSecondary.withOpacity(0.3),
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
            ),
            SizedBox(width: 12),

            // Image thumbnail
            if (item.imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.imageUrl!,
                  width: 50,
                  height: 75,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      SizedBox(width: 0, height: 0),
                ),
              ),
              SizedBox(width: 12),
            ],

            // Item text and category
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: item.isCompleted
                          ? AppTheme.textSecondary
                          : AppTheme.textPrimary,
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        categoryIcon,
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(width: 4),
                      Text(
                        categoryLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Drag Handle
            if (enableDrag && index != null) ...[
              ReorderableDragStartListener(
                index: index!,
                child: Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.drag_indicator,
                      color: AppTheme.textSecondary.withOpacity(0.5)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
