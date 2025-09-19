# Firestore Index Deployment

## Automatic Deployment
If you have Firebase CLI installed, you can deploy the indexes automatically:

```bash
firebase deploy --only firestore:indexes
```

## Manual Index Creation
If you prefer to create indexes manually through the Firebase Console, create these indexes:

### 1. Chemicals Collection - Manufacturer + Name
- Collection: `chemicals`
- Fields:
  - `manufacturer` (Ascending)
  - `name` (Ascending)

### 2. Chemicals Collection - Name Search
- Collection: `chemicals`
- Fields:
  - `nameLowercase` (Ascending)

### 3. Chemicals Collection - Expiry Date
- Collection: `chemicals`
- Fields:
  - `expiryDate` (Ascending)

### 4. Chemicals Collection - Quantity (for low stock)
- Collection: `chemicals`
- Fields:
  - `quantity` (Ascending)

## Firebase Console Links
You can also create indexes directly from the error messages in your console. The error messages contain direct links to create the required indexes.

## Notes
- Single field indexes are created automatically by Firestore
- Composite indexes need to be created manually or via deployment
- The app has been optimized to minimize complex index requirements