import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../providers/app_state.dart';
import '../models/category_model.dart';
import '../widgets/add_movie_modal.dart';
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
  final ScrollController _scrollController = ScrollController();
  late ConfettiController _confettiController;
  double _previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String? _getCurrentCategoryId(
      AppState appState, List<Category> visibleCategories) {
    if (_currentTabIndex == 0) return null; // "All" tab
    if (_currentTabIndex - 1 < visibleCategories.length) {
      return visibleCategories[_currentTabIndex - 1].id;
    }
    return null;
  }

  double _getCurrentProgress(
      AppState appState, List<Category> visibleCategories) {
    if (_currentTabIndex == 0) {
      // "All" tab - show overall progress
      return appState.overallProgress;
    }
    // Specific category tab - show that category's progress
    if (_currentTabIndex - 1 < visibleCategories.length) {
      final category = visibleCategories[_currentTabIndex - 1];
      return category.progress;
    }
    return 0.0;
  }

  void _checkAndTriggerConfetti(double currentProgress) {
    // Trigger confetti when progress reaches 100% (1.0) and it wasn't 100% before
    if (currentProgress >= 1.0 && _previousProgress < 1.0) {
      _confettiController.play();
    }
    _previousProgress = currentProgress;
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
    return Consumer<AppState>(
      builder: (context, appState, child) {
        if (appState.isLoading) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: SafeArea(
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final visibleCategories =
            appState.categories.where((c) => !c.isHidden).toList();

        // Get current progress and check for confetti trigger
        final currentProgress =
            _getCurrentProgress(appState, visibleCategories);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndTriggerConfetti(currentProgress);
        });

        return Stack(
          children: [
            Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: SafeArea(
                child: NestedScrollView(
                  controller: _scrollController,
                  headerSliverBuilder:
                      (BuildContext context, bool innerBoxIsScrolled) {
                    return <Widget>[
                      SliverAppBar(
                        expandedHeight: 118.0,
                        floating: true,
                        snap: true,
                        pinned: false,
                        elevation: 0,
                        backgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        surfaceTintColor: Colors.transparent,
                        flexibleSpace: FlexibleSpaceBar(
                          background: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Image.asset(
                                      'assets/images/bucket-icon.png',
                                      height: 70,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                ProgressRing(
                                  progress: _getCurrentProgress(
                                      appState, visibleCategories),
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
                                    onPressed: () =>
                                        _showSettingsModal(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          minHeight: 50.0,
                          maxHeight: 50.0,
                          child: Container(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            height: 50,
                            child: ListView(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              scrollDirection: Axis.horizontal,
                              children: [
                                _buildTabChip('All', '📋', 0, context),
                                for (int i = 0;
                                    i < visibleCategories.length;
                                    i++) ...[
                                  SizedBox(width: 8),
                                  _buildTabChip(
                                    visibleCategories[i].name,
                                    visibleCategories[i].icon,
                                    i + 1,
                                    context,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
                  body: Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: _buildItemsList(appState, visibleCategories),
                  ),
                ),
              ),
              floatingActionButton: Consumer<AppState>(
                builder: (context, appState, child) {
                  final visibleCategories =
                      appState.categories.where((c) => !c.isHidden).toList();
                  final currentCategoryId =
                      _getCurrentCategoryId(appState, visibleCategories);
                  final isMoviesCategory =
                      currentCategoryId == 'default_movies';

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
            ),
            // Confetti widget overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: 3.14 / 2, // downward
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.3,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.yellow,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabChip(
      String label, String icon, int index, BuildContext context) {
    final isSelected = _currentTabIndex == index;

    return GestureDetector(
      onTap: () {
        if (_currentTabIndex != index) {
          setState(() {
            _currentTabIndex = index;
          });
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
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

  Widget _buildItemsList(AppState appState, List<Category> visibleCategories) {
    List<ChecklistItem> items;

    if (_currentTabIndex == 0) {
      // "All" tab - show all items
      items = appState.getAllItems();
    } else {
      // Specific category tab
      if (_currentTabIndex - 1 < visibleCategories.length) {
        final categoryId = visibleCategories[_currentTabIndex - 1].id;
        items = appState.getItemsForCategory(categoryId);
      } else {
        // Tab index out of range (category deleted or hidden), fallback to All
        items = appState.getAllItems();
        // create a microtask to update state if needed, but for build just render All
        // We can't call setState here.
        // Just fail safe to All items.
      }
    }

    // Drag and drop is definitely easier when viewing a specific category
    // For "All" tab, reordering is disabled because items are mixed
    final bool enableReorder = _currentTabIndex != 0 &&
        (_currentTabIndex - 1 < visibleCategories.length);

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
          final categoryId = visibleCategories[_currentTabIndex - 1].id;
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
