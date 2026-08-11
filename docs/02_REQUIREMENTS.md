# 02_REQUIREMENTS.md

# Rental Ledger - Software Requirements Specification (SRS)

Version: 1.0

------------------------------------------------------------------------

# 1. Introduction

Rental Ledger is a Central House Account Management System for
housemates sharing a rental property. It manages a shared central
account, reimbursements, deposits, direct payments, and household
expenses.

This document defines all functional and non-functional requirements.

------------------------------------------------------------------------

# 2. Functional Requirements

## Authentication

### FR-001 Register

Users can create an account using email and password.

**Acceptance Criteria** - Email validation - Password minimum 8
characters - Duplicate emails are rejected

Priority: High

------------------------------------------------------------------------

### FR-002 Login

Users can sign in securely.

Acceptance Criteria - Firebase Authentication - Remember login session -
Error messages displayed

Priority: High

------------------------------------------------------------------------

### FR-003 Forgot Password

Users can reset their password via email.

Priority: High

------------------------------------------------------------------------

# House Management

### FR-004 Create House

Treasurer can create a new house.

Acceptance Criteria - Generate unique invite code - Creator becomes
Treasurer

Priority: High

------------------------------------------------------------------------

### FR-005 Join House

Members join using an invite code.

Acceptance Criteria - Validate invite code - Prevent duplicate
membership

Priority: High

------------------------------------------------------------------------

### FR-006 Leave House

Members can leave a house.

Treasurer cannot leave until ownership is transferred.

Priority: Medium

------------------------------------------------------------------------

# Dashboard

### FR-007 Dashboard Overview

Display: - Central Account Balance - This Month In - This Month Out -
Monthly Expenses - Upcoming Bills - Pending Reimbursements - Recent
Activity

Priority: High

------------------------------------------------------------------------

# Expense Management

### FR-008 Submit Expense

Members submit an expense with: - Title - Description - Amount -
Category - Receipt - Payment Source

Status: Pending Approval

Priority: High

------------------------------------------------------------------------

### FR-009 Edit Expense

Allowed only before approval.

Priority: Medium

------------------------------------------------------------------------

### FR-010 Delete Expense

Allowed only before approval.

Priority: Medium

------------------------------------------------------------------------

### FR-011 Approve Expense

Treasurer approves or rejects submitted expenses.

Priority: High

------------------------------------------------------------------------

### FR-012 Mark as Paid

Treasurer records reimbursement.

Status changes: Approved → Paid

Priority: High

------------------------------------------------------------------------

### FR-013 Direct Payment

Treasurer records purchases paid directly using the Central Account.

Priority: High

------------------------------------------------------------------------

# Deposits

### FR-014 Record Deposit

Treasurer records money entering the Central Account.

Priority: High

------------------------------------------------------------------------

# History

### FR-015 Transaction History

Support: - Search - Filters - Monthly grouping - Transaction details

Priority: High

------------------------------------------------------------------------

# Reports

### FR-016 Financial Reports

Display: - Monthly Expenses - Category Breakdown - Income vs Expense -
Monthly Trends

Export PDF.

Priority: Medium

------------------------------------------------------------------------

# Notifications

### FR-017 Notifications

Notify: - Expense Submitted - Expense Approved - Expense Rejected -
Reimbursement Completed

Priority: Medium

------------------------------------------------------------------------

# Member Management

### FR-018 Manage Members

Treasurer can: - Invite - Remove - Transfer Treasurer role

Priority: Medium

------------------------------------------------------------------------

# Settings

### FR-019 Settings

Allow users to manage: - Theme - Language - Currency - Notifications -
Account

Priority: Low

------------------------------------------------------------------------

# 3. Non-Functional Requirements

## Performance

-   Dashboard loads within 2 seconds on a normal connection.
-   Lists support pagination.

## Security

-   Firebase Authentication
-   Firestore Security Rules
-   Role-based access

## Reliability

-   Prevent duplicate submissions.
-   Handle network failures gracefully.

## Usability

-   Material Design 3
-   Consistent navigation
-   Accessible typography

## Scalability

-   Support multiple houses in future versions.

------------------------------------------------------------------------

# 4. User Stories

As a Member, I want to submit an expense, so that I can be reimbursed.

As a Treasurer, I want to approve expenses, so that reimbursements are
verified.

As a House Member, I want to view the Central Account balance, so that I
know the available funds.

As a Treasurer, I want to record deposits, so that the balance remains
accurate.

As a User, I want to search transaction history, so that I can find
previous expenses quickly.

------------------------------------------------------------------------

# 5. Out of Scope

-   Bill splitting
-   Bank integration
-   Automatic bank transfers
-   Investment tracking
-   Cryptocurrency
-   Accounting and tax features

------------------------------------------------------------------------

# 6. Definition of Done

A feature is complete only if: - UI implemented - Business logic
completed - Firebase integrated - Error handling implemented - Loading
and empty states handled - Tested - Documentation updated - Git commit
prepared

------------------------------------------------------------------------

# Next Document

03_TECH_STACK.md
