# Rental Ledger — Current Project Direction & AI Instructions

Version: 2.0
Purpose: This document tells Claude Code the current direction of Rental Ledger and the rules it MUST follow when modifying the project.

**v2.0 change:** Web/PWA is now the PRIMARY ACTIVE DEVELOPMENT TARGET. The existing Android/iOS Flutter application is FROZEN for personal use. Rental Ledger remains ONE shared Flutter/Dart project — never fork a separate web application. Git/deploy actions require explicit instruction.

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

```
Presentation
↓
Domain
↓
Data
↓
Firebase / Local Database
```

Do not replace Flutter/Dart with another framework or language unless I explicitly request it.

---

# 5. CURRENT APPLICATION STATUS

The project is already substantially developed.

The existing Android/iOS Flutter application is now considered **stable enough for personal use** and is effectively **FROZEN** (see §8).

The **Web/PWA build is now the PRIMARY ACTIVE DEVELOPMENT TARGET** (see §7).

The latest V1 review reports:

- Flutter analyzer: 0 errors / 0 warnings
- 75+ tests passing
- Windows debug build succeeds
- No critical bugs remain

Do not treat this as a new project.

When working on the project, inspect the existing implementation first and extend it safely.

---

# 6. V1.0 — FEATURES TO FINISH (LEGACY MOBILE ROADMAP — PAUSED)

The following is the **old mobile V1.0 release roadmap**. It is **NO LONGER the active development priority** and must **not** be continued automatically. Only work on these items when I explicitly request them.

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

# 7. DEVELOPMENT PRIORITY — WEB/PWA IS THE PRIMARY ACTIVE TARGET

Web/PWA is now the **PRIMARY ACTIVE DEVELOPMENT TARGET** for Rental Ledger.

The existing Flutter mobile application is now considered **stable enough for personal use** and is effectively **FROZEN** (see §8).

The goal is **NOT** to abandon or delete the mobile application.

The goal is to **continue using the existing Flutter/Dart codebase** while making Web/PWA the main active development target.

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

# 8. MOBILE APPLICATION — FROZEN

The existing Android/iOS Flutter application is primarily for **personal use**.

Claude Code MUST NOT make additional mobile-specific feature changes unless I explicitly request them.

Do NOT:

- Add new mobile-only features unless explicitly requested.
- Continue the old mobile V1 release roadmap unless explicitly requested.
- Perform mobile-only UI redesigns unless explicitly requested.
- Perform unnecessary mobile optimizations.
- Rewrite existing mobile functionality simply because another implementation seems better.
- Remove existing Android/iOS support.
- Remove existing mobile configuration or platform code.
- Delete existing mobile features.

The existing mobile application must remain functional.

---

# 9. DO NOT CREATE A SEPARATE WEB APPLICATION

Do NOT create a separate React, Next.js, Vue, Angular, or other Web application.

Continue using the existing Flutter/Dart application.

Preferred architecture:

```
Flutter / Dart
       ↓
Shared Application Code
       ↓
 ┌───────────────┬───────────────┐
 ↓               ↓
Mobile           Web/PWA
FROZEN           ACTIVE
```

Use shared Flutter/Dart code whenever possible.

Only use platform-specific implementations when technically necessary.

---

# 10. SHARED CODE RULE

Because Flutter uses shared code for multiple platforms, a change to shared code may affect Android, iOS, and Web.

When modifying shared code:

1. Prioritize the requested Web requirement.
2. Preserve existing mobile behavior.
3. Do not create duplicate implementations unnecessarily.
4. Do not break mobile compatibility simply to make Web work.
5. If Web requires platform-specific code, isolate it appropriately.
6. Test the affected Web functionality.
7. Do not perform unrelated mobile changes.

The goal is:

**WEB-FIRST DEVELOPMENT + MOBILE PRESERVATION.**

---

# 11. FEATURE DEVELOPMENT RULE

When I request a new feature:

- IF the feature already works on Mobile but does not work on Web:
  → Make it Web-compatible while preserving the existing Mobile behavior.
- IF the feature already works on both Mobile and Web:
  → Do not change it unnecessarily.
- IF the feature is completely new:
  → Implement it with Web/PWA as the primary target while preserving existing Mobile functionality.
- IF implementing the Web feature requires a breaking Mobile change:
  → STOP and tell me before making the change.

Do not assume that breaking Mobile compatibility is acceptable.

---

# 12. WEB / PWA REQUIREMENTS

All new development should prioritize Flutter Web/PWA.

Primary Web targets:

- iPhone Safari
- Android Chrome
- Windows Chrome
- Windows Edge
- macOS Safari
- macOS Chrome
- Desktop browsers
- Mobile browsers
- Tablet browsers

Web development priorities include:

- Flutter Web compatibility
- Responsive UI
- Mobile browser layouts
- Tablet layouts
- Desktop layouts
- Safari compatibility
- Chrome compatibility
- Edge compatibility
- Firebase Web compatibility
- Web receipt upload
- Web PDF functionality
- Web notifications / FCM where supported
- PWA functionality
- Service worker configuration where required
- HTTPS
- Production Web hosting
- Custom domain

Additional Web work should include (from the original direction):

- Firebase Web configuration
- Firebase Authentication Web
- Firestore Web
- Firebase Storage Web
- Cloud Functions integration
- Mobile camera/photo upload where supported
- Web PDF export
- PWA manifest
- Add-to-home-screen support
- HTTPS hosting

Important:

**Do not sacrifice existing mobile functionality just to make Web work.**

If Web compatibility requires a change to an existing feature, identify the issue and explain the safest solution before making a breaking change.

---

# 13. ISAR / OFFLINE

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

# 14. V1.1 — QUALITY OF LIFE (ONLY WHEN REQUESTED)

Current V1.1 features:

- Dark Mode
- Theme Switching
- Persist User Preferences
- Additional UI Improvements
- Performance Improvements
- More Report Customization
- Additional Animations

V1.1 features are **not** an active priority. Implement them only when I explicitly request them or when we reach that development stage.

---

# 15. NEW V1.1 PERSONALIZATION FEATURES

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

Implement these features only when I explicitly request them.

---

# 16. USER PREFERENCES

The personalization features should work together with:

- Persist User Preferences

The user's preferences should be stored so their preferred configuration can persist across supported devices/platforms where appropriate.

Do not change the existing settings behavior unless required by the requested personalization feature.

---

# 17. V1.2 — OFFLINE EXPERIENCE (ONLY WHEN REQUESTED)

Planned V1.2 features:

- Offline Mode
- Offline Sync
- Retry Queue
- Cached Images
- Background Synchronization

Do not implement these early unless explicitly requested.

---

# 18. V2.0 — ADVANCED FEATURES (ONLY WHEN REQUESTED)

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

# 19. IMPORTANT — FEATURE PRESERVATION

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

# 20. DO NOT MAKE UNREQUESTED "IMPROVEMENTS"

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

# 21. WHEN I ASK FOR A FEATURE

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

Implement ONLY the requested feature, prioritizing Web/PWA and preserving existing mobile behavior (see §10 Shared Code Rule and §11 Feature Development Rule).

### Step 4 — Test

Run:

- flutter analyze
- Relevant tests
- Existing tests when practical
- Test the affected Web functionality

### Step 5 — Report

Tell me:

- What was changed
- What was not changed
- Test results
- Any remaining issues
- Git commit recommendation (do NOT commit or push without instruction — see §23)

---

# 22. SOURCE OF TRUTH

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

# 23. GITHUB / GIT RULE

GitHub is currently used as source-code backup and version history.

DO NOT automatically:

- Commit
- Push
- Create branches
- Merge branches
- Deploy production
- Change Git configuration

unless I explicitly ask you to do so.

After completing a development task:

1. Run appropriate tests.
2. Run flutter analyze where appropriate.
3. Show me what changed.
4. Show Git status/diff when useful.
5. Wait for my instruction before committing.
6. Wait for my instruction before pushing.
7. Wait for my instruction before deploying.

I decide when a Web milestone is stable enough to commit and push.

---

# 24. CURRENT HIGH-LEVEL ROADMAP

The old mobile release roadmap is **NO LONGER the active development priority**.

The current priority is:

1. Flutter Web/PWA
2. Web compatibility
3. Responsive UI
4. Firebase Web compatibility
5. Browser testing
6. PWA functionality
7. Web hosting
8. Production Web deployment
9. Custom domain

V1.1, V1.2, and V2.0 features should only be implemented when I explicitly request them or when we reach that development stage.

Do not continue the old mobile roadmap automatically.

---

# 25. IMPORTANT PLATFORM PRINCIPLE

Rental Ledger remains **ONE Flutter/Dart project**.

We are NOT maintaining two separate applications.

We are maintaining:

```
ONE CODEBASE
    ↓
Flutter/Dart
    ↓
 ┌───────────────────────┐
 │                       │
Mobile                 Web/PWA
FROZEN                 ACTIVE
Personal use           Primary product
```

Shared functionality should remain shared.

---

# 26. FINAL INSTRUCTION TO CLAUDE CODE

**Rental Ledger is an existing working project. Do not treat it as a blank project.**

**Do not change existing features unless Raymond explicitly asks for the change.**

From this point forward:

**WEB FIRST.**
**MOBILE PRESERVED.**
**NO UNREQUESTED FEATURE CHANGES.**
**NO AUTOMATIC GIT COMMIT.**
**NO AUTOMATIC GIT PUSH.**
**NO AUTOMATIC DEPLOYMENT.**

When I ask you to develop something:

1. Read the existing project and documentation first.
2. Understand the current implementation.
3. Prioritize Web/PWA.
4. Preserve existing Mobile behavior.
5. Modify only what I requested or what is strictly required.
6. Do not make unrelated improvements.
7. Test the change.
8. Show me the result.
9. Wait for my approval before committing or pushing.

The priority is:

**Preserve existing functionality → Implement the requested change → Test → Report.**

---

# 27. NEW UPGRADE REQUEST — MODIFY EXISTING EXPENSES (IMPLEMENTED)

Status: **IMPLEMENTED** — pending-expense editing upgrade only.

A user specifically reported that they **cannot modify an expense after it has already been added**.

## Implemented behavior

A member may edit their own **pending** expense before the Treasurer reviews it:

- Title
- Amount
- Description
- Category
- Receipt (take photo / choose photo / replace / remove)

Payment source is locked. Rejected, Approved, and Paid expenses remain unchanged and locked for members (per the approved scope).

## Constraints that were preserved

1. Treasurer/member permissions were NOT weakened.
2. The expense approval/reimbursement workflow was NOT changed.
3. Only the submitter can edit their own pending expense (UI + repository guard + Firestore rules).
4. Audit/transaction integrity preserved — edits never touch status/approval fields.

---

# 28. AI RULE FOR NEW UPGRADE REQUESTS

When a new upgrade request is added to this document:

- Treat it as a requested feature/upgrade.
- Do not modify unrelated existing features.
- Inspect the current implementation first.
- Preserve existing functionality.
- Identify conflicts with existing business rules.
- Explain the proposed behavior before making potentially breaking changes.
- Implement only the requested upgrade after the intended behavior is clear.
