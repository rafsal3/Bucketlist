import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/category_model.dart';
import '../widgets/add_movie_modal.dart';
import '../widgets/add_category_modal.dart';
import '../widgets/add_item_modal.dart';
import '../widgets/checklist_item_card.dart';
import '../widgets/progress_ring.dart';
import '../theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
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
                    ],
                  ),
                ),

                // Category tabs
                Container(
                  height: 50,
                  margin: EdgeInsets.symmetric(horizontal: 24),
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _buildTabChip('All', '📋', 0),
                      SizedBox(width: 8),
                      ...appState.categories.asMap().entries.map((entry) {
                        final index =
                            entry.key + 1; // +1 because "All" is at index 0
                        final category = entry.value;
                        return Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: _buildTabChip(
                            category.name,
                            category.icon,
                            index,
                          ),
                        );
                      }).toList(),
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
            backgroundColor: AppTheme.surface,
            child: Icon(Icons.folder_outlined, color: AppTheme.accent),
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
                backgroundColor: AppTheme.accent,
                icon: Icon(isMoviesCategory ? Icons.movie : Icons.add,
                    color: Colors.white),
                label: Text(
                  isMoviesCategory ? 'Find Movie' : 'Add Item',
                  style: TextStyle(
                    color: Colors.white,
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

  Widget _buildTabChip(String label, String icon, int index) {
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
          color: isSelected ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : [],
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
                color: isSelected ? Colors.white : AppTheme.textPrimary,
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
      final categoryId = appState.categories[_currentTabIndex - 1].id;
      items = appState.getItemsForCategory(categoryId);
    }

    // Drag and drop is definitely easier when viewing a specific category
    // For "All" tab, reordering is disabled because items are mixed
    final bool enableReorder = _currentTabIndex != 0;

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
                color: AppTheme.textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the + button to add your first item',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
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
