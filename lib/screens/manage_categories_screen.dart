import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/add_category_modal.dart';
import '../providers/app_state.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back, color: Theme.of(context).iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Manage Categories',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.categories.isEmpty) {
            return Center(
              child: Text(
                'No categories found',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            );
          }

          return ReorderableListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: appState.categories.length,
            onReorder: (oldIndex, newIndex) {
              appState.reorderCategories(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final category = appState.categories[index];
              return _buildCategoryItem(context, category, appState, index);
            },
            proxyDecorator: (child, index, animation) {
              return Material(
                color: Colors.transparent,
                elevation: 0,
                child: child,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => AddCategoryModal(),
          );
        },
        backgroundColor: Theme.of(context).cardColor,
        child: Icon(Icons.add, color: Theme.of(context).iconTheme.color),
      ),
    );
  }

  Widget _buildCategoryItem(
      BuildContext context, dynamic category, AppState appState, int index) {
    return Container(
      key: ValueKey(category.id),
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            category.icon,
            style: TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          category.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${category.totalCount} items',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                category.isHidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              onPressed: () => appState.toggleCategoryVisibility(category.id),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
              onPressed: () =>
                  _showDeleteConfirmation(context, appState, category),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.drag_handle,
                    color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
      BuildContext context, AppState appState, dynamic category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Delete Category?',
            style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color)),
        content: Text(
          'Are you sure you want to delete "${category.name}"? This will also delete all ${category.totalCount} items in it.',
          style:
              TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color)),
          ),
          TextButton(
            onPressed: () {
              appState.deleteCategory(category.id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
