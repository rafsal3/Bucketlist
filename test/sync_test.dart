import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/sync_helper.dart';
import 'package:flutter_application_1/models/space_model.dart';
import 'package:flutter_application_1/models/category_model.dart';
import 'package:flutter_application_1/models/sync_models.dart';

void main() {
  group('SyncHelper Tests', () {
    test('generateId creates unique IDs with prefix', () {
      final id1 = SyncHelper.generateId('space');
      final id2 = SyncHelper.generateId('space');

      expect(id1, startsWith('space_'));
      expect(id2, startsWith('space_'));
      expect(id1, isNot(equals(id2)));
    });

    test('filterDeleted removes deleted entities', () {
      final spaces = [
        Space(id: '1', name: 'Active', deleted: false),
        Space(id: '2', name: 'Deleted', deleted: true),
        Space(id: '3', name: 'Active 2', deleted: false),
      ];

      final filtered = SyncHelper.filterDeleted(spaces);

      expect(filtered.length, equals(2));
      expect(filtered.any((s) => s.deleted), isFalse);
    });

    test('sortByOrder sorts entities correctly', () {
      final spaces = [
        Space(id: '1', name: 'Third', order: 2),
        Space(id: '2', name: 'First', order: 0),
        Space(id: '3', name: 'Second', order: 1),
      ];

      final sorted = SyncHelper.sortByOrder(spaces);

      expect(sorted[0].name, equals('First'));
      expect(sorted[1].name, equals('Second'));
      expect(sorted[2].name, equals('Third'));
    });

    test('buildSyncChanges creates valid SyncChanges', () {
      final space = Space(id: '1', name: 'Test');
      final category = Category(id: '2', name: 'Test', icon: '📝');
      final item = ChecklistItem(id: '3', text: 'Test');

      final changes = SyncHelper.buildSyncChanges(
        spaces: [space],
        categories: [category],
        items: [item],
      );

      expect(changes.spaces.length, equals(1));
      expect(changes.categories.length, equals(1));
      expect(changes.items.length, equals(1));
      expect(changes.isEmpty, isFalse);
    });

    test('buildSyncChanges handles empty lists', () {
      final changes = SyncHelper.buildSyncChanges();

      expect(changes.spaces.length, equals(0));
      expect(changes.categories.length, equals(0));
      expect(changes.items.length, equals(0));
      expect(changes.isEmpty, isTrue);
    });

    test('mergeEntity prefers newer timestamp', () {
      final older = Space(
        id: '1',
        name: 'Old',
        updatedAt: DateTime(2024, 1, 1),
      );
      final newer = Space(
        id: '1',
        name: 'New',
        updatedAt: DateTime(2024, 1, 2),
      );

      final merged = SyncHelper.mergeEntity(older, newer);

      expect(merged.name, equals('New'));
    });

    test('mergeEntity prefers server when timestamps equal', () {
      final timestamp = DateTime(2024, 1, 1);
      final local = Space(
        id: '1',
        name: 'Local',
        updatedAt: timestamp,
      );
      final server = Space(
        id: '1',
        name: 'Server',
        updatedAt: timestamp,
      );

      final merged = SyncHelper.mergeEntity(local, server);

      // When equal, server wins (Last-Write-Wins tie-breaker)
      expect(merged.name, equals('Server'));
    });
  });

  group('SyncChanges Tests', () {
    test('toJson and fromJson work correctly', () {
      final original = SyncChanges(
        spaces: [
          {'id': '1', 'name': 'Test'},
        ],
        categories: [
          {'id': '2', 'name': 'Test'},
        ],
        items: [
          {'id': '3', 'text': 'Test'},
        ],
      );

      final json = original.toJson();
      final restored = SyncChanges.fromJson(json);

      expect(restored.spaces.length, equals(1));
      expect(restored.categories.length, equals(1));
      expect(restored.items.length, equals(1));
    });

    test('isEmpty returns true for empty changes', () {
      final empty = SyncChanges();
      expect(empty.isEmpty, isTrue);

      final notEmpty = SyncChanges(spaces: [
        {'id': '1'}
      ]);
      expect(notEmpty.isEmpty, isFalse);
    });
  });

  group('Model Tests', () {
    test('Space toJson includes all sync fields', () {
      final space = Space(
        id: 'test-id',
        name: 'Test Space',
        icon: '📝',
        order: 5,
        deleted: false,
        deviceId: 'device-123',
        userId: 'user-456',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
      );

      final json = space.toJson();

      expect(json['id'], equals('test-id'));
      expect(json['name'], equals('Test Space'));
      expect(json['icon'], equals('📝'));
      expect(json['order'], equals(5));
      expect(json['deleted'], equals(false));
      expect(json['deviceId'], equals('device-123'));
      expect(json['userId'], equals('user-456'));
      expect(json['createdAt'], isNotNull);
      expect(json['updatedAt'], isNotNull);
    });

    test('Category toJson includes all sync fields', () {
      final category = Category(
        id: 'test-id',
        name: 'Test Category',
        icon: '📌',
        spaceId: 'space-123',
        order: 3,
        deleted: false,
        deviceId: 'device-123',
        userId: 'user-456',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
      );

      final json = category.toJson();

      expect(json['id'], equals('test-id'));
      expect(json['spaceId'], equals('space-123'));
      expect(json['order'], equals(3));
      expect(json['deleted'], equals(false));
      expect(json['deviceId'], equals('device-123'));
      expect(json['userId'], equals('user-456'));
    });

    test('ChecklistItem toJson includes all sync fields', () {
      final item = ChecklistItem(
        id: 'test-id',
        text: 'Test Item',
        spaceId: 'space-123',
        categoryId: 'category-456',
        order: 2,
        deleted: false,
        deviceId: 'device-123',
        userId: 'user-456',
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 2),
      );

      final json = item.toJson();

      expect(json['id'], equals('test-id'));
      expect(json['spaceId'], equals('space-123'));
      expect(json['categoryId'], equals('category-456'));
      expect(json['order'], equals(2));
      expect(json['deleted'], equals(false));
      expect(json['deviceId'], equals('device-123'));
      expect(json['userId'], equals('user-456'));
    });

    test('Space fromJson parses all sync fields', () {
      final json = {
        'id': 'test-id',
        'name': 'Test Space',
        'icon': '📝',
        'isHidden': false,
        'order': 5,
        'deleted': false,
        'deviceId': 'device-123',
        'userId': 'user-456',
        'createdAt': '2024-01-01T00:00:00.000Z',
        'updatedAt': '2024-01-02T00:00:00.000Z',
        'categories': [],
      };

      final space = Space.fromJson(json);

      expect(space.id, equals('test-id'));
      expect(space.order, equals(5));
      expect(space.deleted, equals(false));
      expect(space.deviceId, equals('device-123'));
      expect(space.userId, equals('user-456'));
      expect(space.createdAt, isNotNull);
      expect(space.updatedAt, isNotNull);
    });
  });
}
