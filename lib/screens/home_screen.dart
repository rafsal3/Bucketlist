import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../providers/app_state.dart';
import '../models/category_model.dart';
import '../models/space_model.dart';
import '../widgets/add_movie_modal.dart';
import '../widgets/add_book_modal.dart';
import '../widgets/add_item_modal.dart';
import '../widgets/add_space_modal.dart';
import 'manage_spaces_screen.dart';
import '../widgets/checklist_item_card.dart';
import '../widgets/progress_ring.dart';
import '../utils/toast_helper.dart';

import 'manage_categories_screen.dart';
import 'customization_screen.dart';
import 'cloud_sync_screen.dart';
import '../models/sync_status.dart';

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
  String? _previousCategoryId;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Add listener to check for progress changes immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = Provider.of<AppState>(context, listen: false);
      appState.addListener(_onAppStateChanged);
    });
  }

  void _onAppStateChanged() {
    if (!mounted) return;

    final appState = Provider.of<AppState>(context, listen: false);
    final visibleCategories =
        appState.categories.where((c) => !c.isHidden).toList();

    final currentProgress = _getCurrentProgress(appState, visibleCategories);
    final categoryKey = _currentTabIndex == 0
        ? 'all'
        : (_currentTabIndex - 1 < visibleCategories.length
            ? visibleCategories[_currentTabIndex - 1].id
            : 'all');

    // Use setState to ensure the confetti triggers
    setState(() {
      _checkAndTriggerConfetti(currentProgress, categoryKey);
    });
  }

  @override
  void dispose() {
    // Remove listener to prevent memory leaks
    final appState = Provider.of<AppState>(context, listen: false);
    appState.removeListener(_onAppStateChanged);

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

  void _checkAndTriggerConfetti(double currentProgress, String categoryKey) {
    // Check if category changed - if so, just update tracking and don't trigger
    if (_previousCategoryId != categoryKey) {
      _previousProgress = currentProgress;
      _previousCategoryId = categoryKey;
      return;
    }

    // Trigger confetti when progress reaches 100% (1.0) and it wasn't 100% before
    // This will trigger EVERY TIME you complete a category, not just once
    if (currentProgress >= 1.0 && _previousProgress < 1.0) {
      print(
          '🎉 Triggering confetti! Progress: $currentProgress, Category: $categoryKey');
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
                title: Text('Customization'),
                leading: Icon(Icons.palette_rounded),
                trailing: Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context); // Close the modal
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CustomizationScreen(),
                    ),
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
              ListTile(
                title: Text('Manage Spaces'),
                leading: Icon(Icons.space_dashboard_rounded),
                trailing: Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context); // Close the modal
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManageSpacesScreen(),
                    ),
                  );
                },
              ),
              // Cloud Sync Option - Show login if not logged in
              Consumer<AppState>(
                builder: (context, appState, child) {
                  if (!appState.isLoggedIn) {
                    // Show "Enable Cloud Sync" option
                    return ListTile(
                      title: Text('Enable Cloud Sync'),
                      subtitle: Text('Sync across devices'),
                      leading: Icon(Icons.cloud_sync_rounded),
                      trailing: Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(context); // Close the modal
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CloudSyncScreen(),
                          ),
                        );
                      },
                    );
                  } else {
                    // Show logged in status and logout option
                    return Column(
                      children: [
                        ListTile(
                          title: Text('Cloud Sync'),
                          subtitle: Text(appState.userEmail ?? 'Logged in'),
                          leading: Icon(
                            Icons.cloud_done_rounded,
                            color: Colors.green,
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              // Show confirmation dialog
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Logout'),
                                  content: Text(
                                      'Are you sure you want to logout? Your data will remain on this device.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text('Logout'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                await appState.logout();
                                if (context.mounted) {
                                  Navigator.pop(context); // Close settings
                                  ToastHelper.showInfo(
                                      context, 'Logged out successfully');
                                }
                              }
                            },
                            child: Text('Logout'),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSpacesSelector(BuildContext context) {
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
          child: Consumer<AppState>(
            builder: (context, appState, child) {
              return Column(
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
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'My Spaces',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),

                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: appState.spaces.length,
                      itemBuilder: (context, index) {
                        final space = appState.spaces[index];
                        final isSelected = space.id == appState.currentSpace.id;

                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1)
                                  : Theme.of(context).cardColor,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              space.icon ?? '🚀',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                          title: Text(
                            space.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.color,
                            ),
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle_rounded,
                                  color: Theme.of(context).colorScheme.primary)
                              : null,
                          onTap: () {
                            appState.switchSpace(space.id);
                            Navigator.pop(context);
                          },
                          onLongPress: () {
                            if (appState.spaces.length > 1) {
                              // Optional: Show delete dialog
                            }
                          },
                        );
                      },
                    ),
                  ),
                  // Divider removed
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => AddSpaceModal(),
                          );
                        },
                        icon: Icon(Icons.add_rounded),
                        label: Text('Create New Space'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showSearchOptions(BuildContext context, String? currentCategoryId) {
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
                padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                child: Text(
                  'Search Options',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Find Movie Option
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        // Pass null if no category selected - will add as uncategorized
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddMovieModal(
                            categoryId: currentCategoryId,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.movie_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Find Movie',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Search for movies to add',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    // Find Book Option
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        // Pass null if no category selected - will add as uncategorized
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => AddBookModal(
                            categoryId: currentCategoryId,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.menu_book_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 28,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Find Book',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Search for books to add',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Manual Sync Method
  Future<void> _performSync(BuildContext context, AppState appState) async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cloud_upload_rounded,
                color: Theme.of(context).colorScheme.primary),
            SizedBox(width: 12),
            Text('Sync to Cloud?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload your latest changes to the cloud backup?',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will update your cloud backup with local changes',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Sync Now'),
          ),
        ],
      ),
    );

    // If user cancelled, return early
    if (confirmed != true) return;

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Syncing to cloud...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Perform sync
      await appState.manualSync();

      // Hide loading
      if (context.mounted) Navigator.pop(context);

      // Show success
      if (context.mounted) {
        ToastHelper.showSuccess(context, 'Synced successfully!');
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ToastHelper.showError(context, 'Sync failed: $e');
      }
    }
  }

  // Backup Dialog
  Future<void> _showBackupDialog(BuildContext context) async {
    // Navigate to cloud sync screen for registration
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CloudSyncScreen(),
      ),
    );
  }

  // Restore Dialog
  Future<void> _showRestoreDialog(
      BuildContext context, AppState appState) async {
    if (!appState.isLoggedIn) {
      // Show login screen first
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CloudSyncScreen(),
        ),
      );
      return;
    }

    // Show warning dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Warning'),
          ],
        ),
        content: Text(
          'This will DELETE all your local data and replace it with your cloud backup.\\n\\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Yes, Restore'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _performRestore(context, appState);
    }
  }

  // Perform Restore
  Future<void> _performRestore(BuildContext context, AppState appState) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Restoring backup...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Perform restore
      await appState.restoreFromBackup();

      // Hide loading
      if (context.mounted) Navigator.pop(context);

      // Show success
      if (context.mounted) {
        ToastHelper.showSuccess(context, 'Backup restored successfully!');
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ToastHelper.showError(context, 'Restore failed: $e');
      }
    }
  }

  // Perform Logout
  Future<void> _performLogout(BuildContext context, AppState appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Your local data will remain safe on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await appState.logout();
      if (context.mounted) {
        ToastHelper.showInfo(context, 'Logged out. Your local data is safe.');
      }
    }
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

        // Create a unique key for the current tab/category
        final categoryKey = _currentTabIndex == 0
            ? 'all'
            : visibleCategories[_currentTabIndex - 1].id;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndTriggerConfetti(currentProgress, categoryKey);
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
                                    child: GestureDetector(
                                      onTap: () => _showSpacesSelector(context),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              appState.currentSpace.icon ??
                                                  '🚀',
                                              style: TextStyle(fontSize: 24),
                                            ),
                                            SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                appState.currentSpace.name,
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                ProgressRing(
                                  progress: _getCurrentProgress(
                                      appState, visibleCategories),
                                  size: 70,
                                ),
                                SizedBox(width: 16),
                                // Manual Sync Button (only if logged in)
                                if (appState.isLoggedIn) ...[
                                  IconButton(
                                    icon: Icon(
                                      Icons.cloud_upload_rounded,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                    tooltip: 'Sync to Cloud',
                                    onPressed: () =>
                                        _performSync(context, appState),
                                    iconSize: 24,
                                  ),
                                ],
                                // Backup/Restore Menu
                                PopupMenuButton<String>(
                                  icon: Icon(
                                    Icons.more_vert_rounded,
                                    color: Theme.of(context).iconTheme.color,
                                  ),
                                  tooltip: 'More options',
                                  itemBuilder: (context) => [
                                    if (!appState.isLoggedIn)
                                      PopupMenuItem(
                                        value: 'backup',
                                        child: Row(
                                          children: [
                                            Icon(Icons.backup_rounded,
                                                size: 20),
                                            SizedBox(width: 12),
                                            Text('Backup to Cloud'),
                                          ],
                                        ),
                                      ),
                                    if (!appState.isLoggedIn)
                                      PopupMenuItem(
                                        value: 'restore',
                                        child: Row(
                                          children: [
                                            Icon(Icons.cloud_download_rounded,
                                                size: 20),
                                            SizedBox(width: 12),
                                            Text('Restore from Cloud'),
                                          ],
                                        ),
                                      ),
                                    if (appState.isLoggedIn)
                                      PopupMenuItem(
                                        value: 'restore',
                                        child: Row(
                                          children: [
                                            Icon(Icons.cloud_download_rounded,
                                                size: 20),
                                            SizedBox(width: 12),
                                            Text('Restore Backup'),
                                          ],
                                        ),
                                      ),
                                    if (appState.isLoggedIn)
                                      PopupMenuItem(
                                        value: 'logout',
                                        child: Row(
                                          children: [
                                            Icon(Icons.logout_rounded,
                                                size: 20),
                                            SizedBox(width: 12),
                                            Text('Logout'),
                                          ],
                                        ),
                                      ),
                                  ],
                                  onSelected: (value) async {
                                    switch (value) {
                                      case 'backup':
                                        await _showBackupDialog(context);
                                        break;
                                      case 'restore':
                                        await _showRestoreDialog(
                                            context, appState);
                                        break;
                                      case 'logout':
                                        await _performLogout(context, appState);
                                        break;
                                    }
                                  },
                                ),
                                // Settings Button
                                IconButton(
                                  icon: Icon(
                                    Icons.settings_rounded,
                                    color: Theme.of(context).iconTheme.color,
                                  ),
                                  tooltip: 'Settings',
                                  onPressed: () => _showSettingsModal(context),
                                  iconSize: 24,
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

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Search button for Find Movie/Book
                      Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.8),
                              Theme.of(context).colorScheme.primary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                _showSearchOptions(context, currentCategoryId),
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              width: 56,
                              height: 56,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.search_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Main Add Item FAB - always shows "Add Item"
                      FloatingActionButton.extended(
                        heroTag: 'add_item',
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => AddItemModal(
                              selectedCategoryId: currentCategoryId,
                            ),
                          );
                        },
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        icon: Icon(Icons.add,
                            color: Theme.of(context).colorScheme.onPrimary),
                        label: Text(
                          'Add Item',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // Confetti widget overlay - positioned on top of everything
            IgnorePointer(
              child: Align(
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

  Widget _buildSyncStatusIndicator(AppState appState) {
    IconData icon;
    Color color;
    String tooltip;

    switch (appState.syncStatus) {
      case SyncStatus.syncing:
        icon = Icons.cloud_sync_rounded;
        color = Colors.blue;
        tooltip = 'Syncing...';
        break;
      case SyncStatus.synced:
        icon = Icons.cloud_done_rounded;
        color = Colors.green;
        tooltip = 'Synced';
        break;
      case SyncStatus.error:
        icon = Icons.cloud_off_rounded;
        color = Colors.red;
        tooltip = appState.syncErrorMessage ?? 'Sync failed';
        break;
      case SyncStatus.localOnly:
      default:
        icon = Icons.cloud_queue_rounded;
        color = Colors.grey;
        tooltip = 'Pending sync';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: color,
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
