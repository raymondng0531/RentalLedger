# Rental Ledger — Current Project Direction & AI Instructions

Version: 1.0
Purpose: This document tells Claude Code the current direction of Rental Ledger and the rules it MUST follow when modifying the project.

---

# 1. CRITICAL RULE — DO NOT CHANGE EXISTING FEATURES UNLESS ASKED

This is the most important instruction.

**DO NOT remove, replace, redesign, disable, simplify, or change any existing feature, workflow, business rule, UI behavior, database behavior, architecture, or package unless I explicitly ask you to do so.**

If I ask you to add a new feature:

- Add the feature without breaking existing features.
- Preserve all existing behavior unless the requested feature necessarily requires a change.
- If an existing feature must change to support the new feature, explain exactly what must change BEFORE making the change.
- Do not "improve" unrelated features automatically.
- Do not remove code just because you think another approach is better.
- Do not rewrite working code unnecessarily.
- Do not replace existing packages/frameworks without my permission.
- Do not change the existing business workflow without my permission.
- Do not invent new requirements.

**Only make changes that are requested or strictly required to implement the requested task.**

If something looks outdated, unnecessary, duplicated, or technically imperfect, report it as a recommendation instead of changing it.

---

# 2. PROJECT IDENTITY

Rental Ledger is a **Central House Account Management System**.

It is NOT:

- Splitwise
- A bill-splitting application
- A banking application
- A full accounting system

The core purpose is to manage a shared household Central Account, reimbursements, deposits, direct payments, household expenses, transaction history, reports, and financial transparency.

The existing core workflow must remain unchanged.

---

# 3. EXISTING CORE WORKFLOW — DO NOT CHANGE

The current workflow is:

1. A member purchases an item using personal money.
2. The member uploads the receipt.
3. The member creates an expense claim.
4. The Treasurer reviews the claim.
5. The Treasurer approves or rejects it.
6. If approved, the Treasurer reimburses the member from the Central Account.
7. The expense becomes Paid/Completed.

The system also supports Direct Payments made from the Central Account.

Do not convert Rental Ledger into an automatic bill-splitting application.

---

# 4. CURRENT TECHNOLOGY STACK — KEEP IT

The current application uses:

- Flutter
- Dart
- Material Design 3
- Riverpod
- GoRouter
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Cloud Messaging
- Isar

The existing Feature-First Clean Architecture must be preserved.

General architecture:

Presentation
↓
Domain
↓
Data
↓
Firebase / Local Database

Do not replace Flutter/Dart with another framework or language unless I explicitly request it.

---

# 5. CURRENT APPLICATION STATUS

The project is already substantially developed.

The latest V1 review reports:

- Flutter analyzer: 0 errors / 0 warnings
- 75 tests passing
- Windows debug build succeeds
- No critical bugs remain

Do not treat this as a new project.

When working on the project, inspect the existing implementation first and extend it safely.

---

# 6. V1.0 — FEATURES TO FINISH

These are the current V1.0 items to complete:

- PDF Export
- Bills History Page
- Better Report Filters
  - Date range
  - Status
- Better Analytics
- Member Management UI
  - Leave House
  - Remove Member
  - Transfer Treasurer
- Unread Notification Badge
- Performance Optimization
- Firebase Production Deployment
  - Firestore Security Rules
  - Cloud Functions

Do not remove or replace existing V1.0 functionality.

---

# 7. NEW PLATFORM DIRECTION — WEB / PWA

I have decided that Rental Ledger should support **Web/PWA as the primary distribution platform**.

The reason is to allow users to access Rental Ledger without requiring an iOS App Store installation.

Target usage:

- iPhone → Safari
- Android → Chrome
- Windows → Chrome / Edge
- Mac → Safari / Chrome

This does NOT mean rewriting Rental Ledger into another framework.

Continue using:

- Flutter
- Dart
- Riverpod
- GoRouter
- Firebase

The goal is to extend the existing Flutter application to Web.

Do not create a separate web application unless I explicitly ask for one.

---

# 8. WEB / PWA REQUIREMENTS

The Web/PWA work should include:

- Flutter Web support
- Responsive UI
- Mobile browser layout
- Tablet layout
- Desktop layout
- iPhone Safari testing
- Android Chrome testing
- Windows Chrome/Edge testing
- macOS Safari/Chrome testing
- Firebase Web configuration
- Firebase Authentication Web
- Firestore Web
- Firebase Storage Web
- Cloud Functions integration
- Web receipt upload
- Mobile camera/photo upload where supported
- Web PDF export
- Web notification / FCM support
- Service worker configuration where required
- PWA manifest
- Add-to-home-screen support
- HTTPS hosting
- Custom domain
- Production Web deployment

Important:

**Do not sacrifice existing mobile functionality just to make Web work.**

If Web compatibility requires a change to an existing feature, identify the issue and explain the safest solution before making a breaking change.

---

# 9. ISAR / OFFLINE

Isar is currently intended for:

- Offline caching
- Faster local loading
- Temporary/local storage
- Future offline functionality

Offline functionality is planned for V1.2.

Do NOT remove Isar just because Web is being added.

Before changing the local storage architecture for Web, inspect the current implementation and determine whether it is actually required for the current task.

Do not implement the full offline system early unless I explicitly ask for it.

---

# 10. V1.1 — QUALITY OF LIFE

Current V1.1 features:

- Dark Mode
- Theme Switching
- Persist User Preferences
- Additional UI Improvements
- Performance Improvements
- More Report Customization
- Additional Animations

---

# 11. NEW V1.1 PERSONALIZATION FEATURES

I have decided that users should be able to personalize the dashboard and bottom navigation.

## Customizable Dashboard

Users should be able to:

- Reorder dashboard sections
- Show/hide optional dashboard sections
- Reset dashboard layout to default
- Save their preferences

Possible dashboard sections include the existing dashboard sections already present in the application.

Do not remove required/core financial information unless I explicitly request it.

## Customizable Bottom Navigation

Users should be able to:

- Rearrange eligible navigation items
- Hide optional navigation items
- Reset navigation to default
- Save their preferences

Keep these predictable/core actions fixed:

- Home remains required
- The primary + / Add action remains fixed

Do not redesign the entire navigation system unless explicitly requested.

---

# 12. USER PREFERENCES

The personalization features should work together with:

- Persist User Preferences

The user's preferences should be stored so their preferred configuration can persist across supported devices/platforms where appropriate.

Do not change the existing settings behavior unless required by the requested personalization feature.

---

# 13. V1.2 — OFFLINE EXPERIENCE

Planned V1.2 features:

- Offline Mode
- Offline Sync
- Retry Queue
- Cached Images
- Background Synchronization

Do not implement these early unless explicitly requested.

---

# 14. V2.0 — ADVANCED FEATURES

Current planned V2.0 features:

- OCR Receipt Scanning
- AI Receipt Categorization
- Excel Export
- Calendar Integration
- Push Notification Scheduling
- AI Spending Insights

These are future features.

Do not implement them unless explicitly requested.

---

# 15. IMPORTANT — FEATURE PRESERVATION

When implementing any task, Claude Code MUST first inspect the existing project.

Before changing code:

1. Understand the existing feature.
2. Identify affected files.
3. Identify dependencies.
4. Check existing tests.
5. Check existing business rules.
6. Check whether the requested feature can be added without changing existing behavior.

After implementation:

1. Run Flutter analyzer.
2. Run relevant tests.
3. Verify existing workflows still work.
4. Verify the new feature.
5. Do not modify unrelated features.
6. Report exactly what changed.

---

# 16. DO NOT MAKE UNREQUESTED "IMPROVEMENTS"

Examples of changes Claude Code MUST NOT make without permission:

- Changing the navigation structure
- Changing the database schema
- Changing Firebase architecture
- Replacing Riverpod
- Replacing GoRouter
- Replacing Firebase
- Removing Isar
- Changing the expense workflow
- Changing Treasurer permissions
- Changing Member permissions
- Changing the Central Account logic
- Changing transaction calculations
- Changing the UI design system
- Removing existing screens
- Removing existing packages
- Changing existing business rules
- Rewriting working features
- Adding unrelated features

If an improvement is useful, say:

> "Recommendation: ..."

Do not implement it automatically.

---

# 17. WHEN I ASK FOR A FEATURE

Follow this process:

### Step 1 — Understand

Read the relevant project documentation and inspect the current implementation.

### Step 2 — Explain

Tell me:

- What will change
- Which files are affected
- Whether existing features are affected
- Any risks

### Step 3 — Implement

Implement ONLY the requested feature.

### Step 4 — Test

Run:

- flutter analyze
- Relevant tests
- Existing tests when practical

### Step 5 — Report

Tell me:

- What was changed
- What was not changed
- Test results
- Any remaining issues
- Git commit recommendation

---

# 18. SOURCE OF TRUTH

The project's existing documentation remains the source of truth for existing features and business rules.

Important documents include:

- 01_PROJECT_CONTEXT.md
- 02_REQUIREMENTS.md
- 03_TECH_STACK.md
- 04_DATABASE.md
- 05_BUSINESS_RULES.md
- 06_UI_GUIDELINES.md
- 07_ARCHITECTURE.md
- 08_DEVELOPMENT_GUIDE.md
- 09_ROADMAP.md
- 10_TASKS.md
- 11_V1_REVIEW.md

This document adds the new direction and clarifies how AI assistants must behave.

If there is a conflict:

1. Follow my latest explicit instruction.
2. Preserve existing features unless I explicitly request a change.
3. Ask/confirm before making a potentially breaking architectural change.

---

# 19. CURRENT HIGH-LEVEL ROADMAP

## V1.0

Finish existing features → Web/PWA production support → Release

## V1.1

Quality of life → User preferences → Dashboard customization → Bottom navigation customization

## V1.2

Offline experience

## V2.0

OCR → AI → Excel → Calendar → Scheduled notifications → AI insights

---

# 20. FINAL INSTRUCTION TO CLAUDE CODE

**Rental Ledger is an existing working project. Do not treat it as a blank project.**

**Do not change existing features unless Raymond explicitly asks for the change.**

When asked to build something:

> Add the requested feature while preserving everything that already works.

When you see something that could be improved:

> Recommend it first. Do not change it automatically.

When a change could affect existing behavior:

> Explain the impact before implementation.

The priority is:

**Preserve existing functionality → Implement the requested change → Test → Report.**


---

# 21. NEW UPGRADE REQUEST — MODIFY EXISTING EXPENSES

A user specifically reported that they **cannot modify an expense after it has already been added**.

This is a requested upgrade and should be investigated as a real product requirement.

## Requested behavior

Users should be able to modify an expense that they have already added, subject to the appropriate business/security rules.

Before implementing:

1. Inspect the current expense lifecycle and existing edit functionality.
2. Determine which expense statuses currently allow editing.
3. Do NOT remove or weaken existing Treasurer/member permissions.
4. Do NOT change the existing expense approval/reimbursement workflow unnecessarily.
5. Determine the safest rules for editing an already-created expense.
6. Preserve the existing audit/transaction integrity.

## Important

The request came from a user feedback conversation where the issue was described as:

> "but i cant modify what i already add"

The clarification confirmed that the issue refers to **expenses that have already been added**.

Therefore, treat **editing existing expenses** as an upgrade requirement, but do not assume that every expense status should become editable.

For example, an expense that has already been approved, reimbursed/paid, or has created an immutable financial transaction may require different handling from a pending expense.

**Do not automatically change the business rules. First inspect the existing implementation and report the safest approach.**

---

# 22. AI RULE FOR NEW UPGRADE REQUESTS

When a new upgrade request is added to this document:

- Treat it as a requested feature/upgrade.
- Do not modify unrelated existing features.
- Inspect the current implementation first.
- Preserve existing functionality.
- Identify conflicts with existing business rules.
- Explain the proposed behavior before making potentially breaking changes.
- Implement only the requested upgrade after the intended behavior is clear.
