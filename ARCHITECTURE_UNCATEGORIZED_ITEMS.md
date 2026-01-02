# Uncategorized Items Architecture

## Before (Buggy Implementation)

```
Space
├── categories: [
│   ├── Category "Places" (id: cat_1)
│   │   └── items: [
│   │       ├── Item "Visit Paris" (categoryId: cat_1) ✅ Visible in Places tab
│   │       ├── Item "Random task" (categoryId: null) ❌ ORPHANED - Invisible!
│   │       └── Item "Buy groceries" (categoryId: null) ❌ ORPHANED - Invisible!
│   │   ]
│   ├── Category "Books" (id: cat_2)
│   │   └── items: [...]
│   └── Category "Movies" (id: cat_3)
│       └── items: [...]
└── (no dedicated storage for uncategorized items)
```

**Problems:**
- ❌ Orphaned items only visible in "All" tab
- ❌ Deleting "Places" category deletes all orphaned items
- ❌ No categories = no storage for uncategorized items

---

## After (Fixed Implementation)

```
Space
├── uncategorizedItems: [ ✅ DEDICATED STORAGE
│   ├── Item "Random task" (categoryId: null) ✅ Visible in All tab
│   └── Item "Buy groceries" (categoryId: null) ✅ Visible in All tab
│   ]
├── categories: [
│   ├── Category "Places" (id: cat_1)
│   │   └── items: [
│   │       └── Item "Visit Paris" (categoryId: cat_1) ✅ Visible in Places tab
│   │   ]
│   ├── Category "Books" (id: cat_2)
│   │   └── items: [
│   │       └── Item "Read 1984" (categoryId: cat_2) ✅ Visible in Books tab
│   │   ]
│   └── Category "Movies" (id: cat_3)
│       └── items: [
│           └── Item "Watch Inception" (categoryId: cat_3) ✅ Visible in Movies tab
│       ]
└── (clean separation of concerns)
```

**Benefits:**
- ✅ Uncategorized items have dedicated storage
- ✅ Deleting categories doesn't affect uncategorized items
- ✅ Works even with zero categories
- ✅ Clear separation of concerns

---

## Data Flow

### Adding an Item

**Categorized Item:**
```
User adds "Visit Paris" to "Places"
    ↓
addItem(categoryId: "cat_1", text: "Visit Paris")
    ↓
Item stored in: categories[0].items[]
    ↓
Item visible in: "Places" tab + "All" tab
```

**Uncategorized Item:**
```
User adds "Random task" as uncategorized
    ↓
addItem(categoryId: null, text: "Random task")
    ↓
Item stored in: space.uncategorizedItems[]
    ↓
Item visible in: "All" tab only
```

### Viewing Items

**"All" Tab:**
```
getAllItems()
    ↓
Collect: space.uncategorizedItems
    +
Collect: all items from visible categories (where item.categoryId == category.id)
    ↓
Sort by timestamp (newest first)
    ↓
Display all items
```

**Category Tab (e.g., "Places"):**
```
getItemsForCategory("cat_1")
    ↓
Filter: category.items.where(item.categoryId == "cat_1")
    ↓
Display only items belonging to this category
```

### Moving Items

**From Category to Uncategorized:**
```
moveItemToCategory(itemId, newCategoryId: null)
    ↓
1. Find and remove item from category.items[]
2. Set item.categoryId = null
3. Add item to space.uncategorizedItems[]
    ↓
Item now appears only in "All" tab
```

**From Uncategorized to Category:**
```
moveItemToCategory(itemId, newCategoryId: "cat_1")
    ↓
1. Find and remove item from space.uncategorizedItems[]
2. Set item.categoryId = "cat_1"
3. Add item to categories[0].items[]
    ↓
Item now appears in "Places" tab + "All" tab
```

---

## Migration Process

### Automatic Migration on App Startup

```
App starts
    ↓
Load spaces from SharedPreferences
    ↓
Run _migrateOrphanedItems()
    ↓
For each space:
    For each category:
        Find items where categoryId == null
            ↓
        Move to space.uncategorizedItems[]
            ↓
        Remove from category.items[]
    ↓
Save migrated data
    ↓
App ready with clean data structure
```

### Example Migration

**Before Migration:**
```json
{
  "spaces": [
    {
      "id": "space_1",
      "categories": [
        {
          "id": "cat_1",
          "name": "Places",
          "items": [
            {"id": "item_1", "categoryId": "cat_1", "text": "Visit Paris"},
            {"id": "item_2", "categoryId": null, "text": "Random task"}
          ]
        }
      ]
    }
  ]
}
```

**After Migration:**
```json
{
  "spaces": [
    {
      "id": "space_1",
      "uncategorizedItems": [
        {"id": "item_2", "categoryId": null, "text": "Random task"}
      ],
      "categories": [
        {
          "id": "cat_1",
          "name": "Places",
          "items": [
            {"id": "item_1", "categoryId": "cat_1", "text": "Visit Paris"}
          ]
        }
      ]
    }
  ]
}
```

---

## Category Progress Calculation

### How it Works

Categories only count items that belong to them:

```dart
class Category {
  int get completedCount => 
    items.where((item) => item.categoryId == id && item.isCompleted).length;
  
  int get totalCount => 
    items.where((item) => item.categoryId == id).length;
  
  double get progress => 
    totalCount == 0 ? 0.0 : completedCount / totalCount;
}
```

### Example

```
Category "Places" (id: cat_1)
├── items: [
│   ├── Item A (categoryId: cat_1, completed: true)  ✅ Counted
│   ├── Item B (categoryId: cat_1, completed: false) ✅ Counted
│   └── Item C (categoryId: null, completed: true)   ❌ Not counted (orphaned)
│   ]
└── Progress: 1/2 = 50% (only counts Items A and B)
```

This ensures that even if orphaned items exist (during migration), they don't affect category progress calculations.

---

## Summary

**Key Principle:** 
> Uncategorized items are first-class citizens with their own dedicated storage, not parasites living inside category objects.

**Benefits:**
1. ✅ No data loss when deleting categories
2. ✅ Clear visibility rules
3. ✅ Works with zero categories
4. ✅ Clean separation of concerns
5. ✅ Automatic migration for existing data
