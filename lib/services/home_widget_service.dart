import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import '../models/space_model.dart';
import '../models/category_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeWidgetService {
  static const String appWidgetProvider = 'TodoWidgetProvider';

  /// Register the background callback
  static Future<void> initialize() async {
    await HomeWidget.registerBackgroundCallback(backgroundCallback);
  }

  /// Update the widget data
  static Future<void> updateWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final box = Hive.isBoxOpen('spaces')
          ? Hive.box<Space>('spaces')
          : await Hive.openBox<Space>('spaces');

      String currentSpaceId = prefs.getString('currentSpaceId') ?? '';

      // If no current space, verify valid one
      if (box.values.isEmpty) {
        // No data handling
        await _saveData([], 'No Spaces');
        return;
      }

      Space? currentSpace;
      try {
        currentSpace = box.values.firstWhere((s) => s.id == currentSpaceId);
      } catch (e) {
        currentSpace = box.values.first;
        currentSpaceId = currentSpace.id;
        await prefs.setString('currentSpaceId', currentSpaceId);
      }

      // Flatten items
      final items = <Map<String, dynamic>>[];

      // Items collection
      final allItems = <ChecklistItem>[];
      allItems.addAll(currentSpace.uncategorizedItems);
      for (var cat in currentSpace.categories) {
        allItems.addAll(cat.items);
      }

      // Sort: Incomplete first
      allItems.sort((a, b) {
        if (a.isCompleted == b.isCompleted) return 0;
        return a.isCompleted ? 1 : -1;
      });

      for (var item in allItems) {
        items.add({
          'id': item.id,
          'title': item.text,
          'isCompleted': item.isCompleted,
        });
      }

      await _saveData(items.take(20).toList(), currentSpace.name);

      debugPrint('📱 Home Widget updated for space: ${currentSpace.name}');
    } catch (e) {
      debugPrint('❌ Failed to update widget: $e');
    }
  }

  static Future<void> _saveData(
      List<Map<String, dynamic>> items, String title) async {
    await HomeWidget.saveWidgetData('widget_title', title);
    await HomeWidget.saveWidgetData('widget_data', jsonEncode(items));
    await HomeWidget.updateWidget(
      name: appWidgetProvider,
      androidName: appWidgetProvider,
    );
  }
}

/// BACKGROUND CALLBACK
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  if (uri == null) return;

  if (uri.host == 'updateitem') {
    final itemId = uri.queryParameters['id'];
    if (itemId != null) {
      await _toggleItem(itemId);
    }
  } else if (uri.host == 'switchspace') {
    await _switchSpace();
  }
}

Future<void> _toggleItem(String itemId) async {
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0))
    Hive.registerAdapter(ChecklistItemAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(CategoryAdapter());
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(SpaceAdapter());

  final box = await Hive.openBox<Space>('spaces');

  bool found = false;

  for (var space in box.values) {
    // Check uncategorized
    for (var item in space.uncategorizedItems) {
      if (item.id == itemId) {
        item.isCompleted = !item.isCompleted;
        found = true;
        break;
      }
    }

    // Check categories
    if (!found) {
      for (var cat in space.categories) {
        for (var item in cat.items) {
          if (item.id == itemId) {
            item.isCompleted = !item.isCompleted;
            found = true;
            break;
          }
        }
        if (found) break;
      }
    }

    if (found) {
      await space.save();
      break;
    }
  }

  await HomeWidgetService.updateWidget();
}

Future<void> _switchSpace() async {
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(2))
    Hive.registerAdapter(SpaceAdapter()); // Min needed

  final prefs = await SharedPreferences.getInstance();
  final box = await Hive.openBox<Space>('spaces');

  if (box.isEmpty) return;

  final spaces = box.values.toList();
  String currentId = prefs.getString('currentSpaceId') ?? spaces.first.id;

  int index = spaces.indexWhere((s) => s.id == currentId);
  int nextIndex = (index + 1) % spaces.length;

  await prefs.setString('currentSpaceId', spaces[nextIndex].id);

  // Need to ensure we load full data for widget update
  if (!Hive.isAdapterRegistered(0))
    Hive.registerAdapter(ChecklistItemAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(CategoryAdapter());

  await HomeWidgetService.updateWidget();
}
