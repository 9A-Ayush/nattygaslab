# Design Document

## Overview

The admin functionality design provides a comprehensive management system for the NattyGas Lab LIMS. The architecture follows Flutter best practices with Material 3 design, responsive layouts, and clean separation of concerns. All data operations use Firestore with proper error handling, loading states, and offline capabilities where appropriate.

## Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Admin UI      │    │   Services      │    │   Firebase      │
│   Screens       │◄──►│   Layer         │◄──►│   Backend       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
│                      │                      │
├─ Dashboard           ├─ SampleService       ├─ Firestore
├─ Users Screen        ├─ CylinderService     ├─ Cloud Functions
├─ Samples Screen      ├─ ChemicalService     ├─ Firebase Auth
├─ Cylinders Screen    ├─ ReportService       ├─ Cloud Storage
├─ Chemicals Screen    ├─ InvoiceService      └─ Cloudinary
├─ Reports Screen      ├─ UserService
├─ Invoices Screen     └─ CloudinaryService
└─ Settings Screen
```

### Navigation Architecture

- **Responsive Navigation**: BottomNavigationBar for mobile, Sidebar for tablet/desktop
- **Route Management**: Named routes with proper navigation stack management
- **State Management**: StatefulWidget with proper lifecycle management
- **Deep Linking**: Support for direct navigation to specific screens with filters

## Components and Interfaces

### 1. Dashboard Component

**Purpose**: Central hub displaying key metrics and quick actions

**Key Features**:
- Real-time metrics cards (samples, cylinders, reports, invoices)
- Recent activity timeline
- Quick action buttons (Add Sample, Generate Invoice)
- Alert notifications (overdue items, low stock)

**Data Sources**:
- Firestore aggregation queries for metrics
- Real-time listeners for live updates
- Cached data for offline viewing

### 2. User Management Component

**Purpose**: Complete user lifecycle management

**Key Features**:
- User CRUD operations with role-based permissions
- Search and filtering with debounced queries
- Password reset functionality
- User activation/deactivation
- Bulk operations support

**Service Integration**:
```dart
class UserService {
  static Future<List<Map<String, dynamic>>> searchUsers(String query);
  static Future<String> createUser(Map<String, dynamic> userData);
  static Future<void> updateUser(String userId, Map<String, dynamic> updates);
  static Future<void> deactivateUser(String userId);
  static Future<void> sendPasswordReset(String email);
}
```

### 3. Sample Management Component

**Purpose**: Complete sample lifecycle tracking

**Key Features**:
- Sample creation with barcode scanning
- Status workflow management (received → queued → analyzed → reported)
- Tag image upload via Cloudinary
- Assignment to technicians
- Excel result upload processing

**Service Integration**:
```dart
class SampleService {
  static Future<String> createSample(Map<String, dynamic> sampleData);
  static Future<void> updateSampleStatus(String sampleId, String status);
  static Future<void> assignSample(String sampleId, String technicianId);
  static Future<void> uploadResults(String sampleId, File excelFile);
  static Stream<QuerySnapshot> getSamples({filters, pagination});
}
```

### 4. Cylinder Management Component

**Purpose**: Gas cylinder tracking and maintenance

**Key Features**:
- Cylinder check-in/check-out workflow
- Status management (clean, in_use, checked_out, pending_cleaning)
- Customer assignment tracking
- Overdue detection and alerts
- Maintenance scheduling

**Service Integration**:
```dart
class CylinderService {
  static Future<void> checkOutCylinder(String cylinderId, String customerId);
  static Future<void> checkInCylinder(String cylinderId);
  static Future<void> markForCleaning(String cylinderId);
  static Future<List<Map<String, dynamic>>> getOverdueCylinders();
  static Stream<QuerySnapshot> getCylinders({filters, pagination});
}
```

### 5. Chemical Inventory Component

**Purpose**: Laboratory chemical inventory management

**Key Features**:
- Chemical CRUD operations
- Stock level tracking
- Expiry date monitoring
- Low stock alerts
- Supplier management
- Image upload for chemical identification

**Service Integration**: Already implemented in `ChemicalService`

### 6. Report Management Component

**Purpose**: Analysis report generation and approval workflow

**Key Features**:
- Report review and approval workflow
- PDF generation via Cloud Functions
- Customer notification system
- Revision tracking
- Quality control checks

**Service Integration**:
```dart
class ReportService {
  static Future<void> approveReport(String reportId, String comments);
  static Future<void> rejectReport(String reportId, String reason);
  static Future<String> generatePDF(String reportId);
  static Future<void> sendToCustomer(String reportId);
  static Stream<QuerySnapshot> getReports({filters, pagination});
}
```

### 7. Invoice Management Component

**Purpose**: Customer billing and payment tracking

**Key Features**:
- Invoice generation based on completed analyses
- Payment status tracking
- Customer rate management
- Monthly automated invoicing
- PDF generation and email delivery

**Service Integration**:
```dart
class InvoiceService {
  static Future<String> generateInvoice(String customerId, List<String> sampleIds);
  static Future<void> markAsPaid(String invoiceId, Map<String, dynamic> paymentDetails);
  static Future<void> sendInvoice(String invoiceId);
  static Future<void> runMonthlyInvoicing();
  static Stream<QuerySnapshot> getInvoices({filters, pagination});
}
```

## Data Models

### Enhanced Data Models

```dart
// Sample Model
class Sample {
  final String id;
  final String reportNo;
  final String customerId;
  final String cylinderId;
  final String analysisType;
  final String status;
  final String? tagImageUrl;
  final String? assignedTo;
  final Map<String, dynamic>? analysisResults;
  final List<AuditEntry> auditTrail;
  final Timestamp createdAt;
  final Timestamp updatedAt;
}

// Cylinder Model
class Cylinder {
  final String id;
  final String barcode;
  final String serial;
  final String status;
  final String? currentHolder;
  final Timestamp? lastCheckedOutAt;
  final Timestamp? lastCheckedInAt;
  final List<MaintenanceRecord> maintenanceHistory;
}

// Report Model
class Report {
  final String id;
  final String sampleId;
  final String status; // draft, pending_review, approved, rejected
  final String? reviewedBy;
  final String? comments;
  final String? pdfUrl;
  final List<ReportRevision> revisions;
  final Timestamp createdAt;
  final Timestamp? approvedAt;
}

// Invoice Model
class Invoice {
  final String id;
  final String customerId;
  final List<String> sampleIds;
  final double totalAmount;
  final String status; // draft, sent, paid, overdue
  final String? pdfUrl;
  final PaymentDetails? paymentDetails;
  final Timestamp createdAt;
  final Timestamp? paidAt;
}
```

## Error Handling

### Comprehensive Error Management

1. **Network Errors**: Retry mechanisms with exponential backoff
2. **Firestore Errors**: Proper error codes handling and user-friendly messages
3. **Validation Errors**: Client-side validation with server-side verification
4. **Permission Errors**: Role-based access control with clear error messages
5. **File Upload Errors**: Progress tracking and error recovery

### Error Display Strategy

```dart
class ErrorHandler {
  static void showError(BuildContext context, dynamic error) {
    String message = _getErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _retryLastAction(),
        ),
      ),
    );
  }
  
  static String _getErrorMessage(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        default:
          return 'An error occurred. Please try again.';
      }
    }
    return error.toString();
  }
}
```

## Testing Strategy

### Unit Testing

1. **Service Layer Tests**: Mock Firestore operations and test business logic
2. **Model Tests**: Validate data serialization/deserialization
3. **Utility Tests**: Test helper functions and calculations

### Widget Testing

1. **Screen Tests**: Test UI rendering and user interactions
2. **Dialog Tests**: Test form validation and submission
3. **Navigation Tests**: Test route transitions and state management

### Integration Testing

1. **End-to-End Workflows**: Test complete user journeys
2. **Firebase Integration**: Test with Firebase emulator
3. **Performance Tests**: Test with large datasets

### Test Structure

```dart
// Example service test
class SampleServiceTest {
  testWidgets('should create sample with valid data', (tester) async {
    // Arrange
    final mockFirestore = MockFirebaseFirestore();
    final sampleData = {...};
    
    // Act
    final result = await SampleService.createSample(sampleData);
    
    // Assert
    expect(result, isNotNull);
    verify(mockFirestore.collection('samples').add(any)).called(1);
  });
}
```

## Performance Considerations

### Firestore Optimization

1. **Pagination**: Use `limit()` and `startAfter()` for large datasets
2. **Indexing**: Create composite indexes for complex queries
3. **Caching**: Implement local caching for frequently accessed data
4. **Offline Support**: Use Firestore offline persistence

### UI Performance

1. **Lazy Loading**: Implement lazy loading for lists and images
2. **Image Optimization**: Use Cloudinary transformations for thumbnails
3. **State Management**: Minimize widget rebuilds with proper state management
4. **Memory Management**: Dispose controllers and listeners properly

### Required Firestore Indexes

```javascript
// Composite indexes required
{
  "collectionGroup": "samples",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "createdAt", "order": "DESCENDING"}
  ]
},
{
  "collectionGroup": "cylinders",
  "queryScope": "COLLECTION", 
  "fields": [
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "lastCheckedOutAt", "order": "DESCENDING"}
  ]
},
{
  "collectionGroup": "users",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "role", "order": "ASCENDING"},
    {"fieldPath": "active", "order": "ASCENDING"},
    {"fieldPath": "name", "order": "ASCENDING"}
  ]
}
```

## Security Considerations

### Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - admin and supervisor access
    match /users/{userId} {
      allow read, write: if request.auth != null && 
        (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'supervisor']);
    }
    
    // Samples collection - role-based access
    match /samples/{sampleId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin', 'supervisor', 'clerk']);
    }
  }
}
```

### Data Validation

1. **Client-side Validation**: Immediate feedback for user input
2. **Server-side Validation**: Cloud Functions for critical operations
3. **Role-based Access**: Enforce permissions at multiple levels
4. **Audit Logging**: Track all administrative actions

## Cloud Functions Integration

### Required Cloud Functions

```javascript
// User management
exports.createUser = functions.https.onCall(async (data, context) => {
  // Validate admin permissions
  // Create user with custom claims
  // Send welcome email
  // Log audit trail
});

// Report generation
exports.generateReport = functions.https.onCall(async (data, context) => {
  // Validate sample data
  // Generate PDF using template
  // Upload to Cloud Storage
  // Update sample status
});

// Invoice generation
exports.generateInvoice = functions.https.onCall(async (data, context) => {
  // Calculate charges based on customer rates
  // Generate PDF invoice
  // Send email notification
  // Update invoice status
});

// Monthly invoicing automation
exports.monthlyInvoicing = functions.pubsub.schedule('0 0 1 * *').onRun(async (context) => {
  // Query completed samples from previous month
  // Group by customer
  // Generate invoices automatically
  // Send notifications
});
```