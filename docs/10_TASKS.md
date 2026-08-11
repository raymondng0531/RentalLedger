# 10_TASKS.md

# Rental Ledger - Development Backlog

Version: 2.0

## Purpose

Master task list organized by release version. Tasks are updated after each
AI-assisted development session.

------------------------------------------------------------------------

# Task Status

-   [x] Completed
-   \[/\] In Progress
-   [ ] Not Started
-   \[!\] Blocked

Priority: Critical / High / Medium / Low

------------------------------------------------------------------------

# Version 1.0 -- Production Release

## Authentication

-   [x] Splash Screen
-   [x] Login Screen
-   [x] Registration Screen
-   [x] Forgot Password
-   [x] Google / Apple Sign-In
-   [x] Session Persistence
-   [x] Logout

## House Management

-   [x] Create House
-   [x] Join House (Invite Code)
-   [x] Regenerate Invite Code
-   [x] Member List
-   [x] Treasurer Role & Transfer
-   [x] Switch House
-   [x] Leave House

## Dashboard

-   [x] Central Account Balance (animated)
-   [x] Monthly Summary Cards (Month In / Out / Pending)
-   [x] Pending Reimbursements
-   [x] Recent Activity (animated, real names)
-   [x] Upcoming Bills (with urgency + reminders)

## Expenses

-   [x] Submit Expense (title, amount, description, category, source)
-   [x] Receipt Upload (camera / gallery, preview)
-   [x] Edit Pending Expense (purchaser only)
-   [x] Delete Pending Expense
-   [x] Expense Details + Timeline
-   [x] Approve / Reject (with reason) / Mark Paid

## Treasurer Workflow

-   [x] Approve Expense
-   [x] Reject Expense (with reason)
-   [x] Mark Reimbursed
-   [x] Deposit Recording
-   [x] Direct Payment
-   [x] Treasurer-only enforcement (UI + Firestore rules)

## Bills Management

-   [x] Create Bill (amount optional — reminder only)
-   [x] Edit / Delete Bill
-   [x] Recurring bills (roll to next month)
-   [x] Reminder toggle
-   [x] Mark Paid (records Direct Payment; removes from Upcoming Bills)

## History

-   [x] Combined transaction + expense history
-   [x] Search
-   [x] Filter bottom sheet (Type, Period, Category, Status) —
      Touch 'n Go style option tiles
-   [x] Monthly grouping

## Reports

-   [x] Summary cards (Expenses / Deposits / Net Flow)
-   [x] Insights grid (highest category, largest expense, average
      monthly, pending reimbursements, bills paid / pending)
-   [x] Category breakdown (interactive pie — tap to highlight,
      tooltip panel, legend with % )
-   [x] Monthly trend (deposits + expenses grouped bars, Y-axis,
      legend, tooltip with month / deposits / expenses / net)
-   [x] Real-time updates
-   [ ] PDF Export (High)
-   [ ] Better report filters (date range / status) (High)

## Notifications

-   [x] Notification list (grouped, unread indicators)
-   [x] Mark as read / Mark all read
-   [x] Real-time stream
-   [x] In-app toast for new notifications
-   [x] Trigger notifications (expense submitted / approved / rejected / paid,
      bill reminders)

## Settings

-   [x] Profile (edit display name)
-   [x] House info + invite code copy
-   [x] Language picker
-   [x] Currency picker
-   [x] Notification preference toggle

## Polish & QA

-   [x] Animated entrance / count-up / status transitions
-   [x] Animated list insertions / removals
-   [x] Consistent snackbars, empty states, loading states
-   [x] Shared receipt viewer
-   [x] Full UI consistency pass
-   [x] Full QA pass (treasurer + member)
-   [x] Firestore rules hardening
-   [ ] Performance optimization (Medium)
-   [ ] Bills History page (Medium)

------------------------------------------------------------------------

# Version 1.1 -- Quality of Life

-   [ ] Dark Mode
-   [ ] Theme Switching
-   [ ] Persist User Preferences
-   [ ] Additional UI Improvements
-   [ ] Performance Improvements
-   [ ] More Report Customization
-   [ ] Additional Animations

------------------------------------------------------------------------

# Version 1.2 -- Offline Experience

-   [ ] Offline Mode (Isar)
-   [ ] Offline Sync
-   [ ] Retry Queue
-   [ ] Cached Images
-   [ ] Background Synchronization

------------------------------------------------------------------------

# Version 2.0 -- Future Features

-   [ ] OCR Receipt Scanning
-   [ ] AI Receipt Categorization
-   [ ] Budget Planner
-   [ ] Spending Prediction
-   [ ] Excel Export
-   [ ] Calendar Integration
-   [ ] Push Notification Scheduling
-   [ ] Multi-house Dashboard
-   [ ] AI Spending Insights

------------------------------------------------------------------------

# AI Session Workflow

At the start of every coding session:

1.  Review PROJECT_CONTEXT.md and REQUIREMENTS.md
2.  Review relevant documentation
3.  Select ONE unfinished task from the current release version
4.  Implement only that task
5.  Write tests
6.  Update documentation if needed
7.  Mark the task complete

Never work on multiple unrelated tasks in the same session.

------------------------------------------------------------------------

# Next Recommended Document

00_AI_RULES.md (Master AI Prompt)
