import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/category_model.dart';
import '../widgets/add_movie_modal.dart';
import '../widgets/add_category_modal.dart';
import '../widgets/add_item_modal.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;

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

            // Tab controller logic removed

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
                      _ProgressRing(
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
          return _ItemCard(
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
        return _ItemCard(
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

class _ItemCard extends StatelessWidget {
  final ChecklistItem item;
  final AppState appState;
  final bool enableDrag;
  final int? index;

  const _ItemCard({
    Key? key,
    required this.item,
    required this.appState,
    this.enableDrag = false,
    this.index,
  }) : super(key: key);

  void _showItemOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(24),
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

            // Item text
            Text(
              item.text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 24),

            // Move to category
            ListTile(
              leading: Icon(Icons.folder_outlined, color: AppTheme.accent),
              title: Text('Move to Category'),
              onTap: () {
                Navigator.pop(context);
                _showCategoryPicker(context);
              },
            ),

            // Delete
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.red),
              title: Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                appState.deleteItem(item.id);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

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

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    context,
                    icon: Icons.check_circle_outline,
                    label: item.isCompleted ? 'Mark Undone' : 'Mark Done',
                    color: AppTheme.accent,
                    onTap: () {
                      appState.toggleItem(item.id);
                      Navigator.pop(context);
                    },
                  ),
                  _buildActionButton(
                    context,
                    icon: Icons.edit_outlined,
                    label: 'Options',
                    color: AppTheme.textPrimary,
                    onTap: () {
                      Navigator.pop(context);
                      _showItemOptions(context);
                    },
                  ),
                ],
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
      onLongPress: () => _showItemOptions(context),
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

class _ProgressRing extends StatelessWidget {
  final double progress;
  final double size;

  const _ProgressRing({
    required this.progress,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Background circle
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: 1.0,
              color: AppTheme.accentLight,
              strokeWidth: 6,
            ),
          ),
          // Progress circle
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress,
              color: AppTheme.accent,
              strokeWidth: 6,
            ),
          ),
          // Percentage text
          Center(
            child: Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
