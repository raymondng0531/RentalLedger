# Rental Ledger AI Starter Kit

> Version: 1.0\
> Purpose: AI-first project documentation for building Rental Ledger
> using Flutter + Firebase.

------------------------------------------------------------------------

# Project Structure

``` text
Rental-Ledger-AI/

README.md

01_PROJECT_CONTEXT.md
02_REQUIREMENTS.md
03_TECH_STACK.md
04_DATABASE.md
05_BUSINESS_RULES.md
06_UI_GUIDELINES.md
07_ARCHITECTURE.md
08_DEVELOPMENT_GUIDE.md
09_ROADMAP.md
10_TASKS.md

prompts/
    build_feature.md
    review_code.md
    bug_fix.md
    refactor.md
    generate_tests.md
```

------------------------------------------------------------------------

# 01_PROJECT_CONTEXT.md

## Purpose

This is the master document for every AI coding assistant.

Include: - Project vision - Business workflow - User roles - Product
scope - Design philosophy - Architecture principles - Tech stack -
Coding standards - Development workflow - AI instructions

------------------------------------------------------------------------

# 02_REQUIREMENTS.md

Document every functional and non-functional requirement.

Sections: - Authentication - House Management - Dashboard - Expenses -
Reimbursements - Reports - Notifications - Members - Settings - Offline
Mode - Security - Performance

Each requirement should include: - Description - User Story - Acceptance
Criteria - Priority

------------------------------------------------------------------------

# 03_TECH_STACK.md

Document: - Flutter - Firebase - Riverpod - GoRouter - Material Design
3 - Firestore - Firebase Storage - Firebase Authentication - Firebase
Cloud Messaging - Isar

Also define: - Package list - Naming conventions - Coding standards -
Folder conventions

------------------------------------------------------------------------

# 04_DATABASE.md

Design every Firestore collection.

Collections: - users - houses - members - expenses - reimbursements -
transactions - notifications - categories - settings

For every collection define: - Fields - Data types - Relationships -
Indexes - Security rules - Query examples

------------------------------------------------------------------------

# 05_BUSINESS_RULES.md

Document all workflows.

Examples: - Submit Expense - Approve Expense - Reject Expense -
Reimburse Expense - Direct Payment - Deposit - Join House - Leave House

Include: - Preconditions - Process Flow - Postconditions - Edge Cases -
Error Handling

------------------------------------------------------------------------

# 06_UI_GUIDELINES.md

Document every screen.

Screens: - Splash - Login - Register - Dashboard - History - Add
Expense - Expense Details - Pending Reimbursements - Reports - Members -
Central Account - Notifications - Settings

For every screen include: - Purpose - Components - Navigation - Empty
State - Loading State - Error State - Offline State

Define: - Color palette - Typography - Icons - Buttons - Cards -
Spacing - Material Design 3 guidelines

------------------------------------------------------------------------

# 07_ARCHITECTURE.md

Document the Flutter architecture.

Include: - Clean Architecture - Feature-first structure - Repository
Pattern - Riverpod providers - Services - Models - Routing - Error
handling - Dependency injection - Folder structure

------------------------------------------------------------------------

# 08_DEVELOPMENT_GUIDE.md

Rules for AI.

For every feature: 1. Read PROJECT_CONTEXT.md 2. Read DATABASE.md 3.
Read BUSINESS_RULES.md 4. Build Model 5. Build Repository 6. Build
Service 7. Build Provider 8. Build UI 9. Write Tests 10. Update TASKS.md
11. Suggest Git commit message

Never skip planning.

------------------------------------------------------------------------

# 09_ROADMAP.md

Milestones:

Sprint 1 - Authentication

Sprint 2 - Dashboard

Sprint 3 - Expenses

Sprint 4 - Reimbursements

Sprint 5 - Reports

Sprint 6 - Notifications

Sprint 7 - OCR - PDF Export - Offline Mode

Sprint 8 - Testing - Deployment

------------------------------------------------------------------------

# 10_TASKS.md

Create a living checklist.

Example:

``` text
Authentication
☐ Login
☐ Register
☐ Forgot Password

Dashboard
☐ Balance Card
☐ Monthly Expenses
☐ Pending Reimbursements
☐ Recent Activity

Expenses
☐ Submit Expense
☐ Upload Receipt
☐ OCR
☐ Approval
☐ Reimbursement

Reports
☐ Charts
☐ PDF Export
```

------------------------------------------------------------------------

# prompts/build_feature.md

Prompt Template:

> Read PROJECT_CONTEXT.md, DATABASE.md, BUSINESS_RULES.md and
> UI_GUIDELINES.md before writing any code.
>
> Build one feature at a time using Clean Architecture, Riverpod, and
> Material Design 3.
>
> Explain your implementation, update TASKS.md, and provide a Git commit
> message.

------------------------------------------------------------------------

# prompts/bug_fix.md

Prompt Template:

> Read PROJECT_CONTEXT.md first.
>
> Analyze the issue, identify the root cause, propose the safest fix,
> explain every modified file, and avoid breaking existing
> functionality.

------------------------------------------------------------------------

# prompts/review_code.md

Prompt Template:

> Review the project as a Senior Flutter Engineer.
>
> Check: - Architecture - Riverpod usage - Firebase usage -
> Performance - Readability - Scalability - Security - UI consistency
>
> Suggest improvements without unnecessary rewrites.

------------------------------------------------------------------------

# Goal

This starter kit should become the single source of truth for the Rental
Ledger project. Every AI assistant should read these documents before
generating code so development remains consistent, maintainable, and
production-ready.
