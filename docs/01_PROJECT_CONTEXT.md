# 01_PROJECT_CONTEXT.md

# Rental Ledger - Project Context

## Purpose

This document is the single source of truth for every AI assistant
working on Rental Ledger.

Before writing code, modifying existing features, or suggesting
improvements, always read this document completely.

------------------------------------------------------------------------

# Project Vision

Rental Ledger is a modern mobile application that helps housemates
manage a shared household **Central Account**.

It is designed to simplify expense tracking, reimbursements, deposits,
and financial transparency within a rental house.

The application emphasizes accountability, transparency, and ease of
use.

------------------------------------------------------------------------

# What Rental Ledger IS

-   A Central House Account Management System
-   A reimbursement management application
-   A household finance tracker
-   A Flutter + Firebase portfolio project
-   Built using Material Design 3

------------------------------------------------------------------------

# What Rental Ledger IS NOT

Rental Ledger is NOT: - Splitwise - A bill-splitting application - A
banking application - An accounting system

Expenses are **not automatically divided** among members.

------------------------------------------------------------------------

# Core Workflow

1.  Member purchases an item using personal money.
2.  Member uploads the receipt.
3.  Expense Claim is created.
4.  Treasurer reviews the claim.
5.  Treasurer reimburses the member from the Central Account.
6.  Expense becomes Completed.

The system must also support Direct Payments made immediately from the
Central Account.

------------------------------------------------------------------------

# User Roles

## Treasurer

Responsibilities: - Manage Central Account - Approve or reject claims -
Record deposits - Record direct payments - Reimburse members - View
reports - Manage members

## Member

Responsibilities: - Submit expenses - Upload receipts - View own
claims - View house activity - Receive reimbursements

------------------------------------------------------------------------

# Core Features

-   Authentication
-   Create House
-   Join House
-   Dashboard
-   Expense Claims
-   Receipt Upload
-   Expense Approval
-   Reimbursements
-   Deposits
-   Direct Payments
-   History
-   Reports
-   Notifications
-   Member Management
-   Settings

------------------------------------------------------------------------

# Design Principles

-   Clean
-   Minimal
-   Professional
-   Fintech-inspired
-   Material Design 3
-   Consistent spacing
-   Rounded cards
-   Green theme
-   MYR (RM) currency

------------------------------------------------------------------------

# Tech Stack

Frontend - Flutter

State Management - Riverpod

Routing - GoRouter

Backend - Firebase Authentication - Cloud Firestore - Firebase Storage -
Firebase Cloud Messaging

Local Storage - Isar

------------------------------------------------------------------------

# Development Philosophy

-   Build one feature at a time.
-   Finish one feature before starting another.
-   Use reusable widgets.
-   Avoid duplicated code.
-   Separate UI from business logic.
-   Keep code readable.
-   Document important decisions.

------------------------------------------------------------------------

# Coding Standards

-   Follow SOLID principles.
-   Use meaningful names.
-   Keep widgets small.
-   Use feature-first folder structure.
-   Handle loading, error, empty and offline states.
-   Write reusable components whenever possible.

------------------------------------------------------------------------

# UI Philosophy

Every screen should: - Have a clear purpose - Require minimal taps -
Provide immediate feedback - Feel modern and lightweight - Maintain
consistent spacing and typography

------------------------------------------------------------------------

# AI Instructions

Whenever generating code:

1.  Read this document first.
2.  Never assume missing business rules.
3.  Follow Material Design 3.
4.  Use Flutter best practices.
5.  Use Riverpod.
6.  Use Clean Architecture where practical.
7.  Explain implementation decisions.
8.  Suggest improvements when appropriate.
9.  Generate production-quality code.
10. Do not introduce unnecessary packages.

------------------------------------------------------------------------

# Development Workflow

1.  Understand the feature.
2.  Design the data model.
3.  Design the UI.
4.  Implement business logic.
5.  Connect Firebase.
6.  Test the feature.
7.  Refactor if needed.
8.  Update documentation.
9.  Suggest a Git commit message.

------------------------------------------------------------------------

# Future Enhancements

-   OCR receipt scanning
-   PDF export
-   Offline mode
-   Dark mode
-   Push notifications
-   Analytics dashboard
-   Multi-house support
-   Budget planning
-   Recurring bills

------------------------------------------------------------------------

# Success Criteria

Rental Ledger should be: - Easy to use - Visually polished -
Maintainable - Scalable - Suitable for a professional portfolio - Built
with production-quality engineering practices
