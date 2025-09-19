# context.md — Project Context & Implementation Plan

**Project:** Natty Gas Lab — LIMS (Laboratory Information Management System)
**Tech stack:** Flutter (mobile/web), Firebase (Authentication, Firestore, Cloud Functions, Storage), Cloudinary (images), Node.js for serverless parsing & PDF generation (Cloud Functions).
**Last updated:** 2025-09-15

---

## 1. Project overview

Build a secure, production-ready LIMS to manage gas sample life-cycle for Natty Gas Lab. Core capabilities: sample check-in/out, barcode-based cylinder tracking, result ingestion (GC Excel files), generate PDF analysis reports, customer portal, invoices, role-based users (Supervisor, Data Clerk, Technician, Assistant), dashboards and alerts (expiry, overdue returns, low stock).

Primary goals:

* Accurate sample tracking (physical cylinder + digital sample record).
* Fast result ingestion from GC output (Excel → DB).
* Clean, auditable reports & invoices.
* Mobile-friendly "virtual sample tag" entry for field use (offline-first where possible).

---

## 2. High-level architecture

* **Flutter app(s)**: Admin & Field apps (single codebase with role-aware UI).
* **Firebase**: Authentication, Firestore, Cloud Functions, Storage.
* **Cloudinary**: Sample tag images (store + transform).
* **Cloud Functions (Node.js)**: Excel parsing, PDF generation, invoices, email/notifications.
* **CI/CD**: GitHub Actions, Firebase Hosting.

---

## 3. Collections / Data model (Firestore)

### users/{userId}

```json
{
  "name": "string",
  "email": "string",
  "role": "supervisor|clerk|technician|assistant|customer",
  "phone": "string",
  "active": true,
  "createdAt": "timestamp"
}
```

### customers/{customerId}

```json
{
  "companyName": "string",
  "contactName": "string",
  "email": "string",
  "phone": "string",
  "billingRate": { "GPA2261": 2000, "other": 0 },
  "preferredInvoiceFormat": "pdf|email|portal",
  "portalAccess": true,
  "createdAt": "timestamp"
}
```

### cylinders/{cylinderId}

```json
{
  "barcode": "string",
  "serial": "string",
  "status": "clean|in_use|checked_out|pending_cleaning|lost",
  "currentHolder": "customerId|null",
  "lastCheckedOutAt": "timestamp",
  "lastCheckedInAt": "timestamp",
  "notes": "string"
}
```

### samples/{sampleId}

```json
{
  "reportNo": "string",
  "customerId": "ref",
  "cylinderId": "ref",
  "analysisType": "GPA2261",
  "sampleDescription": "string",
  "sampledBy": "string",
  "sampleDate": "timestamp",
  "dateReceived": "timestamp",
  "status": "received|queued|in_analysis|analyzed|review_pending|reported|invoiced",
  "tagImageUrl": "cloudinary_url",
  "gcResultsFileUrl": "storage_url",
  "analysisResults": {},
  "assignedTo": "userId",
  "createdAt": "timestamp",
  "updatedAt": "timestamp",
  "audit": []
}
```

### reports/{reportId}, invoices/{invoiceId}, machines/{machineId}, analysis\_types/{typeId}

(see detailed breakdown above).

---

## 4. Key features & workflows

* Sample check-in/out with barcode + tag photo upload.
* Cylinder tracking with status and overdue detection.
* Analysis ingestion (Excel → DB via Cloud Function).
* Report generation, supervisor approval, PDF export.
* Monthly invoice automation.
* Supervisor dashboard (samples, cylinders, overdue, pending reports).
* Offline-first virtual tag entry in field (sync later).

---

## 5. Firebase / Cloudinary specifics

* Firebase Auth + custom claims for RBAC.
* Firestore security rules enforce strict access by role.
* Cloud Functions: parseGcExcel, generatePdfReport, generateInvoice, monthlyInvoiceJob.
* Storage: raw uploads + generated PDFs.
* Cloudinary: tag image uploads, thumbnails.

---

## 6. Security & compliance

* Firebase App Check.
* Secret Manager for API keys.
* Firestore rules hardened.
* Input validation + file size/type checks.

---

## 7. Env variables

```
FIREBASE_PROJECT_ID=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
SENDGRID_API_KEY=
PDF_TEMPLATES_BUCKET=
INVOICE_SENDER_EMAIL=
```

Flutter side:

```
FIREBASE_API_KEY=
FIREBASE_AUTH_DOMAIN=
FIRESTORE_PROJECT_ID=
CLOUDINARY_UPLOAD_PRESET=
```

---

## 8. Milestones

1. Foundation: auth, schema, role setup, barcode scanning.
2. Sample lifecycle + cylinder management.
3. Analysis ingestion + reporting.
4. Invoicing & automation.
5. Security, polish, docs, handover.

---

## 9. Acceptance criteria

* Users login & create sample records with cylinders.
* Excel upload parsed → report PDF generated & approved.
* Invoices auto-generated monthly.
* Dashboard shows accurate status.
* Offline entries sync when online.
* Firestore rules prevent unauthorized access.

---

## 10. Deliverables

* Flutter app (web + mobile), Cloud Functions, Firestore rules.
* PDF/Excel parsing functions.
* Deployment scripts + docs.
* QA test scripts & final handover.

---

## 11. Branding & UI/UX Guidelines

### Logo Integration

* **Splash Screen:**

  * Show the NattyGas Lab logo centered with a fade-in animation.
  * Background: Gradient (`#003366` → `#00BCD4`) for light mode, deep navy for dark mode.
  * Tagline under logo: *"Smart Laboratory Management System"*.

* **AppBar:**

  * Place small left-aligned logo in the **Dashboard** and **User screens**.
  * Title: *NattyGas Lab* in Material 3 typography.

* **Login/Signup Pages:**

  * Logo displayed above the form card.
  * Background adapts to light/dark mode.

* **Chemical Page:**

  * Minimal branding (optional logo in corner or just title).

---

### UI Guidelines

* **Responsive Layout (MediaQuery + LayoutBuilder):**

  * Mobile: Single-column layout, BottomNavigationBar.
  * Tablet/Desktop: Multi-column dashboard with Sidebar navigation.

* **Dark Mode & Light Mode:**

  * Auto-detect system theme (`ThemeMode.system`).
  * Manual toggle option (persisted in SharedPreferences).

---

### Color Palette (from Logo)

* **Primary Green:** `#66A23F`
* **Primary Blue:** `#0072BC`
* **Accent Cyan:** `#00BCD4`
* **Background Light:** `#F8FAFC`
* **Background Dark:** `#121212`

Typography:

* Use **GoogleFonts.Poppins** or **Roboto** for modern, clean text.
 