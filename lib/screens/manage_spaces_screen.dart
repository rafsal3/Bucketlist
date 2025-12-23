import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/add_space_modal.dart';
import '../providers/app_state.dart';

class ManageSpacesScreen extends StatelessWidget {
  const ManageSpacesScreen({super.key});

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
          'Manage Spaces',
          style: TextStyle(
            color: Theme.of(context).textTheme.titleLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          if (appState.spaces.isEmpty) {
            return Center(
              child: Text(
                'No spaces found',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            );
          }

          return ReorderableListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: appState.spaces.length,
            onReorder: (oldIndex, newIndex) {
              appState.reorderSpaces(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final space = appState.spaces[index];
              return _buildSpaceItem(context, space, appState, index);
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
            builder: (context) => AddSpaceModal(),
          );
        },
        backgroundColor: Theme.of(context).cardColor,
        child: Icon(Icons.add, color: Theme.of(context).iconTheme.color),
      ),
    );
  }

  Widget _buildSpaceItem(
      BuildContext context, dynamic space, AppState appState, int index) {
    return Container(
      key: ValueKey(space.id),
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
            space.icon ?? '🚀',
            style: TextStyle(fontSize: 24),
          ),
        ),
        title: Text(
          space.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleMedium?.color,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${space.categories.length} categories',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined,
                  color: Theme.of(context).textTheme.bodyMedium?.color),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => AddSpaceModal(
                    spaceId: space.id,
                    initialName: space.name,
                    initialIcon: space.icon,
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(
                space.isHidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              onPressed: () => appState.toggleSpaceVisibility(space.id),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
              onPressed: appState.spaces.length > 1
                  ? () => _showDeleteConfirmation(context, appState, space)
                  : null,
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
      BuildContext context, AppState appState, dynamic space) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text('Delete Space?',
            style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color)),
        content: Text(
          'Are you sure you want to delete "${space.name}"? This will delete all categories and items within it.',
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
              appState.deleteSpace(space.id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
