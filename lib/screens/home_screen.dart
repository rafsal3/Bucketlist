import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/category_model.dart';
import '../widgets/add_movie_modal.dart';
import '../widgets/add_category_modal.dart';
import '../widgets/add_item_modal.dart';
import '../widgets/checklist_item_card.dart';
import '../widgets/progress_ring.dart';

import 'manage_categories_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;

  String? _getCurrentCategoryId(AppState appState) {
    if (_currentTabIndex == 0) return null; // "All" tab
    if (_currentTabIndex - 1 < appState.categories.length) {
      return appState.categories[_currentTabIndex - 1].id;
    }
    return null;
  }

  void _showSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Consumer<AppState>(
                builder: (context, appState, child) {
                  return SwitchListTile(
                    title: Text('Dark Mode'),
                    secondary: Icon(
                      appState.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                    ),
                    value: appState.isDarkMode,
                    onChanged: (value) {
                      appState.toggleTheme();
                    },
                  );
                },
              ),
              ListTile(
                title: Text('Manage Categories'),
                leading: Icon(Icons.category_rounded),
                trailing: Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context); // Close the modal
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageCategoriesScreen(),
                    ),
                  );
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            if (appState.isLoading) {
              return Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                // Header with progress ring
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'My Bucket List',
                              style: Theme.of(context).textTheme.displayLarge,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Track your life goals',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      ProgressRing(
                        progress: appState.overallProgress,
                        size: 70,
                      ),
                      SizedBox(width: 8),
                      SizedBox(width: 8),
                      // Settings Button
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.settings_rounded,
                            color: Theme.of(context).iconTheme.color,
                          ),
                          tooltip: 'Settings',
                          onPressed: () => _showSettingsModal(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // Category tabs
                Container(
                  height: 50,
                  child: ListView(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildTabChip('All', '📋', 0, context),
                      for (int i = 0; i < appState.categories.length; i++) ...[
                        SizedBox(width: 8),
                        _buildTabChip(
                          appState.categories[i].name,
                          appState.categories[i].icon,
                          i + 1,
                          context,
                        ),
                      ],
                    ],
                  ),
                ),

                SizedBox(height: 24),

                // Items list
                Expanded(
                  child: _buildItemsList(appState),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add Category button
          FloatingActionButton(
            heroTag: 'add_category',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddCategoryModal(),
              );
            },
            backgroundColor: Theme.of(context).cardColor,
            child: Icon(Icons.folder_outlined,
                color: Theme.of(context).colorScheme.primary),
          ),
          SizedBox(height: 12),
          // Add Item button
          Consumer<AppState>(
            builder: (context, appState, child) {
              final currentCategoryId = _getCurrentCategoryId(appState);
              final isMoviesCategory = currentCategoryId == 'default_movies';

              return FloatingActionButton.extended(
                heroTag: 'add_item',
                onPressed: () {
                  if (isMoviesCategory) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddMovieModal(
                        categoryId: currentCategoryId!,
                      ),
                    );
                  } else {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => AddItemModal(
                        selectedCategoryId: currentCategoryId,
                      ),
                    );
                  }
                },
                backgroundColor: Theme.of(context).colorScheme.primary,
                icon: Icon(isMoviesCategory ? Icons.movie : Icons.add,
                    color: Theme.of(context).colorScheme.onPrimary),
                label: Text(
                  isMoviesCategory ? 'Find Movie' : 'Add Item',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(
      String label, String icon, int index, BuildContext context) {
    final isSelected = _currentTabIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentTabIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : [],
          border: isSelected
              ? null
              : Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
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

  Widget _buildItemsList(AppState appState) {
    List<ChecklistItem> items;

    if (_currentTabIndex == 0) {
      // "All" tab - show all items
      items = appState.getAllItems();
    } else {
      // Specific category tab
      if (_currentTabIndex - 1 < appState.categories.length) {
        final categoryId = appState.categories[_currentTabIndex - 1].id;
        items = appState.getItemsForCategory(categoryId);
      } else {
        // Tab index out of range (category deleted), fallback to All
        items = appState.getAllItems();
        // create a microtask to update state if needed, but for build just render All
        // We can't call setState here.
        // Just fail safe to All items.
      }
    }

    // Drag and drop is definitely easier when viewing a specific category
    // For "All" tab, reordering is disabled because items are mixed
    final bool enableReorder = _currentTabIndex != 0 &&
        (_currentTabIndex - 1 < appState.categories.length);

    if (items.isEmpty) {
      return Center(
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the + button to add your first item',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      );
    }

    if (!enableReorder) {
      // Standard list for "All" tab (no reordering)
      return ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 24),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ChecklistItemCard(
            key: ValueKey(item.id),
            item: item,
            appState: appState,
            enableDrag: false,
          );
        },
      );
    }

    return ReorderableListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 24),
      buildDefaultDragHandles: false, // We use custom drag handles
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {
        if (_currentTabIndex != 0) {
          final categoryId = appState.categories[_currentTabIndex - 1].id;
          appState.reorderItems(categoryId, oldIndex, newIndex);
        }
      },
      itemBuilder: (context, index) {
        final item = items[index];
        return ChecklistItemCard(
          key: ValueKey(item.id),
          item: item,
          appState: appState,
          enableDrag: true,
          index: index,
        );
      },
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          child: child, // Keep the same look while dragging
        );
      },
    );
  }
}
