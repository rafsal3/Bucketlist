import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/space_model.dart';
import 'package:flutter_application_1/models/category_model.dart';

void main() {
  group('Uncategorized Items Fix Tests', () {
    test('Space should have uncategorizedItems list', () {
      final space = Space(
        id: 'test_space',
        name: 'Test Space',
        categories: [],
      );

      expect(space.uncategorizedItems, isNotNull);
      expect(space.uncategorizedItems, isEmpty);
    });

    test('Space should serialize uncategorizedItems to JSON', () {
      final item = ChecklistItem(
        id: 'item_1',
        text: 'Test Item',
        categoryId: null,
      );

      final space = Space(
        id: 'test_space',
        name: 'Test Space',
        categories: [],
        uncategorizedItems: [item],
      );

      final json = space.toJson();

      expect(json['uncategorizedItems'], isNotNull);
      expect(json['uncategorizedItems'], isList);
      expect(json['uncategorizedItems'].length, 1);
      expect(json['uncategorizedItems'][0]['id'], 'item_1');
    });

    test('Space should deserialize uncategorizedItems from JSON', () {
      final json = {
        'id': 'test_space',
        'name': 'Test Space',
        'icon': '🚀',
        'isHidden': false,
        'categories': [],
        'uncategorizedItems': [
          {
            'id': 'item_1',
            'text': 'Test Item',
            'isCompleted': false,
            'categoryId': null,
          }
        ],
      };

      final space = Space.fromJson(json);

      expect(space.uncategorizedItems, isNotNull);
      expect(space.uncategorizedItems.length, 1);
      expect(space.uncategorizedItems[0].id, 'item_1');
      expect(space.uncategorizedItems[0].categoryId, isNull);
    });

    test('Space should handle missing uncategorizedItems in JSON', () {
      final json = {
        'id': 'test_space',
        'name': 'Test Space',
        'icon': '🚀',
        'isHidden': false,
        'categories': [],
      };

      final space = Space.fromJson(json);

      expect(space.uncategorizedItems, isNotNull);
      expect(space.uncategorizedItems, isEmpty);
    });

    test('Uncategorized items should not be counted in category progress', () {
      final uncategorizedItem = ChecklistItem(
        id: 'item_1',
        text: 'Uncategorized',
        categoryId: null,
        isCompleted: true,
      );

      final categorizedItem = ChecklistItem(
        id: 'item_2',
        text: 'Categorized',
        categoryId: 'cat_1',
        isCompleted: false,
      );

      final category = Category(
        id: 'cat_1',
        name: 'Test Category',
        icon: '📝',
        items: [uncategorizedItem, categorizedItem],
      );

      // Should only count the categorized item
      expect(category.totalCount, 1);
      expect(category.completedCount, 0);
    });
  });
}
