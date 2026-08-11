# 06_UI_GUIDELINES.md

# Rental Ledger - UI & Design Guidelines

Version: 1.0

## Purpose

This document defines the visual language, interaction patterns, and UI
standards for Rental Ledger. Every screen should follow these guidelines
to ensure a consistent user experience.

------------------------------------------------------------------------

# Design Principles

-   Modern fintech appearance
-   Material Design 3
-   Clean and minimal
-   Consistent spacing
-   Easy to understand
-   Mobile-first
-   Accessible

------------------------------------------------------------------------

# Theme

Primary Color - Green

Currency - MYR (RM)

Style - Rounded cards - Soft shadows - White surfaces - Simple icons -
High contrast text

------------------------------------------------------------------------

# Typography

Use Material 3 typography.

Large numbers: - Account balances - Expense totals

Medium: - Card titles

Small: - Labels - Helper text

Example:

RM (smaller) 2,847.62 (larger)

------------------------------------------------------------------------

# Spacing

-   8px base spacing
-   16px page padding
-   12--16px card padding
-   16px spacing between sections
-   12px spacing inside cards

------------------------------------------------------------------------

# Border Radius

Cards: 20dp

Buttons: 16dp

Input Fields: 16dp

Bottom Sheets: 24dp

------------------------------------------------------------------------

# Icons

Use Material Symbols Rounded.

Common icons: - Dashboard - Receipt - Wallet - History - Reports -
People - Settings - Notifications

------------------------------------------------------------------------

# Navigation

Bottom Navigation: - Home - History - Add - Reports

Additional pages: - Members - Central Account - Pending Reimbursements -
Settings

Use FAB with Speed Dial: - Add Expense - Deposit - Direct Payment

------------------------------------------------------------------------

# Dashboard

Components: - Central Account Balance - This Month In - This Month Out -
Monthly Expenses - Upcoming Bills - Pending Reimbursements - Recent
Activity

States: - Loading - Empty - Error - Offline

------------------------------------------------------------------------

# History

Features: - Search - Filters - Month grouping - Transaction details

Filters: - All - Expenses - Deposits - Reimbursements - Direct Payments

------------------------------------------------------------------------

# Add Expense

Fields: - Title - Description - Amount - Category - Purchased By -
Payment Source - Receipt Upload

Buttons: - Take Photo - Choose Photo - Submit Expense

------------------------------------------------------------------------

# Expense Details

Display: - Receipt - Description - Amount - Category - Status -
Timeline - Payment Source - Reimbursed By - Payment Date

------------------------------------------------------------------------

# Reports

Show: - Monthly Expenses - Category Breakdown - Income vs Expense -
Trend Chart

Actions: - Export PDF

------------------------------------------------------------------------

# Members

Display: - Avatar - Name - Role - Outstanding Balance - Join Date

Treasurer badge highlighted.

------------------------------------------------------------------------

# Central Account

Display: - Current Balance - Deposit - Pay Expense - Transfer - Recent
Transactions

------------------------------------------------------------------------

# Notifications

Grouped by: - Today - This Week - Earlier

Unread notifications highlighted.

------------------------------------------------------------------------

# Settings

Sections: - House - Account - Appearance - Notifications - Language -
Currency - Help - About

------------------------------------------------------------------------

# Status Badges

Pending - Orange

Approved - Blue

Paid - Green

Rejected - Red

Direct Payment - Purple

------------------------------------------------------------------------

# Empty States

Every screen should include: - Friendly illustration (optional) -
Title - Description - Primary action

Example: "No expenses yet."

------------------------------------------------------------------------

# Loading States

Use skeleton loaders for: - Dashboard - History - Reports - Members

Avoid blocking the whole screen.

------------------------------------------------------------------------

# Error States

Display: - Clear explanation - Retry button

Never expose technical errors.

------------------------------------------------------------------------

# Offline State

Show banner: "You're offline. Showing cached data."

Queue supported actions where appropriate.

------------------------------------------------------------------------

# Accessibility

-   Touch targets ≥48dp
-   Dynamic text support
-   Color contrast
-   Screen reader labels

------------------------------------------------------------------------

# Animations

Use subtle animations: - Page transitions - FAB expansion - Success
confirmation - Pull-to-refresh - Card elevation

Keep durations around 200--300ms.

------------------------------------------------------------------------

# Reusable Components

-   Primary Button
-   Secondary Button
-   Status Badge
-   Balance Card
-   Expense Card
-   Transaction Tile
-   Empty State
-   Search Bar
-   Filter Chips
-   Confirmation Dialog

------------------------------------------------------------------------

# Definition of Done

A screen is complete when: - Matches Figma - Responsive - Accessible -
Handles loading/error/empty/offline states - Uses reusable components -
Follows Material Design 3

------------------------------------------------------------------------

# Next Document

07_ARCHITECTURE.md
