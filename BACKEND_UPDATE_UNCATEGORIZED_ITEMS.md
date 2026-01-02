# Backend Update Instructions: Uncategorized Items Support

## Overview
The Flutter app has been updated to fix a critical bug where uncategorized items were being stored inside category objects, leading to data loss when categories were deleted. The backend needs to be updated to support the new data structure.

## Changes Required

### 1. Update Space Schema/Model

The `Space` model/schema needs to include a new field for uncategorized items.

**Before:**
```javascript
{
  id: String,
  name: String,
  icon: String,
  isHidden: Boolean,
  categories: [Category]
}
```

**After:**
```javascript
{
  id: String,
  name: String,
  icon: String,
  isHidden: Boolean,
  categories: [Category],
  uncategorizedItems: [ChecklistItem]  // NEW FIELD
}
```

### 2. Update Database Schema (if using MongoDB)

If you're using MongoDB, update your Space schema to include the new field:

```javascript
const spaceSchema = new mongoose.Schema({
  id: String,
  name: String,
  icon: String,
  isHidden: { type: Boolean, default: false },
  categories: [categorySchema],
  uncategorizedItems: [checklistItemSchema]  // Add this line
});
```

### 3. Migration Strategy

**For existing data:**

You need to migrate any items that have `categoryId: null` from within category objects to the new `uncategorizedItems` array.

**Migration Script (Pseudo-code):**
```javascript
// For each space in the database
for (const space of spaces) {
  const uncategorizedItems = [];
  
  // For each category in the space
  for (const category of space.categories) {
    // Find items with null categoryId
    const orphanedItems = category.items.filter(item => item.categoryId === null);
    
    // Move them to uncategorizedItems
    uncategorizedItems.push(...orphanedItems);
    
    // Remove them from the category
    category.items = category.items.filter(item => item.categoryId !== null);
  }
  
  // Set the new uncategorizedItems field
  space.uncategorizedItems = uncategorizedItems;
  
  // Save the updated space
  await space.save();
}
```

### 4. API Endpoint Updates

**Sync Endpoint (`POST /api/sync/push`):**
- Accept the new `uncategorizedItems` field in the request body
- Store it in the database
- Return it in the response

**Pull Endpoint (`GET /api/sync/pull`):**
- Include `uncategorizedItems` in the response data
- Ensure it's initialized as an empty array `[]` if it doesn't exist

### 5. Validation

Update your validation schemas to accept the new field:

```javascript
// Example using Joi or similar
const spaceValidation = {
  id: Joi.string().required(),
  name: Joi.string().required(),
  icon: Joi.string().optional(),
  isHidden: Joi.boolean().default(false),
  categories: Joi.array().items(categorySchema),
  uncategorizedItems: Joi.array().items(checklistItemSchema).default([])  // Add this
};
```

### 6. Backward Compatibility

To ensure backward compatibility with older app versions:

1. **When receiving data without `uncategorizedItems`:**
   - Initialize it as an empty array `[]`
   - Run the migration logic to extract orphaned items from categories

2. **When sending data to older clients:**
   - You may need to keep the old behavior temporarily
   - Consider using API versioning

### 7. Testing Checklist

- [ ] Create a new space with uncategorized items
- [ ] Sync uncategorized items to the cloud
- [ ] Pull uncategorized items from the cloud
- [ ] Delete a category and verify uncategorized items are preserved
- [ ] Move items between categorized and uncategorized states
- [ ] Test with existing data (migration)

## Example API Response

**Updated Sync Response:**
```json
{
  "version": 5,
  "data": {
    "spaces": [
      {
        "id": "space_123",
        "name": "Personal",
        "icon": "👤",
        "isHidden": false,
        "categories": [
          {
            "id": "cat_1",
            "name": "Places",
            "icon": "🌍",
            "items": [
              {
                "id": "item_1",
                "text": "Visit Paris",
                "categoryId": "cat_1",
                "isCompleted": false
              }
            ]
          }
        ],
        "uncategorizedItems": [
          {
            "id": "item_2",
            "text": "Random task",
            "categoryId": null,
            "isCompleted": false
          }
        ]
      }
    ]
  }
}
```

## Priority

**HIGH** - This is a critical bug fix that prevents data loss. The migration should be deployed as soon as possible.

## Notes

- The `categoryId` field in `ChecklistItem` should remain `null` for uncategorized items
- Ensure that when items are moved from uncategorized to a category, the `categoryId` is properly updated
- When items are moved from a category to uncategorized, set `categoryId` to `null`
