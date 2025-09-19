# Requirements Document

## Introduction

This document outlines the requirements for implementing complete admin functionality for the NattyGas Lab LIMS (Laboratory Information Management System). The admin side provides comprehensive management capabilities for users, samples, cylinders, chemicals, reports, and invoices within the laboratory system. The implementation must be dynamic, pulling all data from Firestore, and follow Material 3 design principles with responsive layouts.

## Requirements

### Requirement 1: User Management System

**User Story:** As an admin, I want to manage all system users, so that I can control access and maintain proper role-based permissions throughout the laboratory system.

#### Acceptance Criteria

1. WHEN an admin accesses the users screen THEN the system SHALL display all users with pagination support
2. WHEN an admin searches for users THEN the system SHALL filter results by name or email with debounced search
3. WHEN an admin creates a new user THEN the system SHALL validate all required fields and create the user via Cloud Function
4. WHEN an admin edits a user THEN the system SHALL update user information and maintain audit trail
5. WHEN an admin deactivates a user THEN the system SHALL prevent login while preserving data integrity
6. WHEN an admin resets a user password THEN the system SHALL send password reset email via Firebase Auth
7. IF the user list is empty THEN the system SHALL display appropriate empty state with add user option

### Requirement 2: Sample Management System

**User Story:** As an admin, I want to manage all laboratory samples, so that I can track sample lifecycle from receipt to reporting.

#### Acceptance Criteria

1. WHEN an admin views samples THEN the system SHALL display all samples with status, customer, and analysis type
2. WHEN an admin creates a sample THEN the system SHALL assign unique report number and link to customer and cylinder
3. WHEN an admin updates sample status THEN the system SHALL maintain audit trail and notify relevant users
4. WHEN an admin uploads sample tag image THEN the system SHALL use Cloudinary for storage and transformation
5. WHEN an admin assigns sample to technician THEN the system SHALL update assignment and send notification
6. WHEN an admin searches samples THEN the system SHALL filter by report number, customer, status, or date range
7. IF sample requires analysis results THEN the system SHALL provide Excel upload functionality via Cloud Function

### Requirement 3: Cylinder Management System

**User Story:** As an admin, I want to manage gas cylinders, so that I can track cylinder status, location, and maintenance schedules.

#### Acceptance Criteria

1. WHEN an admin views cylinders THEN the system SHALL display all cylinders with barcode, status, and current holder
2. WHEN an admin checks out a cylinder THEN the system SHALL update status and record customer assignment
3. WHEN an admin checks in a cylinder THEN the system SHALL update status and clear customer assignment
4. WHEN an admin marks cylinder for cleaning THEN the system SHALL update status and add to cleaning queue
5. WHEN an admin searches cylinders THEN the system SHALL filter by barcode, serial, status, or customer
6. WHEN cylinder is overdue THEN the system SHALL highlight in dashboard and send alerts
7. IF cylinder status changes THEN the system SHALL maintain complete audit trail

### Requirement 4: Chemical Inventory Management

**User Story:** As an admin, I want to manage chemical inventory, so that I can ensure adequate supplies for laboratory operations.

#### Acceptance Criteria

1. WHEN an admin views chemicals THEN the system SHALL display all chemicals with stock levels and expiry dates
2. WHEN an admin adds new chemical THEN the system SHALL validate chemical data and update inventory
3. WHEN an admin updates stock levels THEN the system SHALL record transaction and maintain history
4. WHEN chemical stock is low THEN the system SHALL display alerts in dashboard
5. WHEN chemical expires soon THEN the system SHALL highlight in inventory and send notifications
6. WHEN admin searches chemicals THEN the system SHALL filter by name, category, or supplier
7. IF chemical is hazardous THEN the system SHALL display appropriate safety warnings

### Requirement 5: Report Management System

**User Story:** As an admin, I want to manage analysis reports, so that I can ensure quality control and timely delivery to customers.

#### Acceptance Criteria

1. WHEN an admin views reports THEN the system SHALL display all reports with status and approval workflow
2. WHEN an admin reviews report THEN the system SHALL provide approval or rejection with comments
3. WHEN an admin generates PDF report THEN the system SHALL use Cloud Function for PDF generation
4. WHEN report is approved THEN the system SHALL automatically notify customer and update sample status
5. WHEN admin searches reports THEN the system SHALL filter by customer, date range, or approval status
6. WHEN report requires revision THEN the system SHALL track revision history and comments
7. IF report data is incomplete THEN the system SHALL prevent approval and highlight missing information

### Requirement 6: Invoice Management System

**User Story:** As an admin, I want to manage customer invoices, so that I can ensure accurate billing and payment tracking.

#### Acceptance Criteria

1. WHEN an admin views invoices THEN the system SHALL display all invoices with payment status and amounts
2. WHEN an admin generates invoice THEN the system SHALL calculate charges based on customer rates and analysis types
3. WHEN an admin sends invoice THEN the system SHALL use Cloud Function for PDF generation and email delivery
4. WHEN payment is received THEN the system SHALL update invoice status and record payment details
5. WHEN admin searches invoices THEN the system SHALL filter by customer, date range, or payment status
6. WHEN monthly invoicing runs THEN the system SHALL automatically generate invoices for completed analyses
7. IF invoice has discrepancies THEN the system SHALL allow manual adjustments with approval workflow

### Requirement 7: Dashboard Analytics and Monitoring

**User Story:** As an admin, I want to view comprehensive dashboard analytics, so that I can monitor laboratory operations and make informed decisions.

#### Acceptance Criteria

1. WHEN an admin accesses dashboard THEN the system SHALL display real-time metrics for samples, cylinders, and reports
2. WHEN metrics are calculated THEN the system SHALL use Firestore aggregation queries for performance
3. WHEN admin views trends THEN the system SHALL display charts for sample volume, revenue, and turnaround times
4. WHEN alerts are present THEN the system SHALL highlight overdue samples, low stock, and pending approvals
5. WHEN admin clicks metric cards THEN the system SHALL navigate to detailed screens with pre-applied filters
6. WHEN dashboard loads THEN the system SHALL show loading states and handle errors gracefully
7. IF no data exists THEN the system SHALL display appropriate empty states with guidance

### Requirement 8: System Configuration and Settings

**User Story:** As an admin, I want to configure system settings, so that I can customize the laboratory workflow and business rules.

#### Acceptance Criteria

1. WHEN an admin accesses settings THEN the system SHALL display configurable parameters for analysis types and pricing
2. WHEN an admin updates analysis types THEN the system SHALL validate configuration and update available options
3. WHEN an admin sets customer rates THEN the system SHALL apply to future invoicing calculations
4. WHEN an admin configures notifications THEN the system SHALL update email templates and delivery settings
5. WHEN admin updates system parameters THEN the system SHALL validate changes and maintain configuration history
6. WHEN settings are saved THEN the system SHALL apply changes immediately without requiring restart
7. IF configuration is invalid THEN the system SHALL prevent saving and display validation errors