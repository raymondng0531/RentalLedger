# 07_ARCHITECTURE.md

# Rental Ledger - Flutter Architecture

Version: 1.0

## Purpose

This document defines the software architecture for Rental Ledger. Every
feature must follow this architecture to ensure scalability,
maintainability, and consistency.

------------------------------------------------------------------------

# Architecture Overview

Rental Ledger follows a **Feature-First Clean Architecture**.

``` text
Presentation
      ↓
Domain
      ↓
Data
      ↓
Firebase / Local Database
```

Each layer has a single responsibility.

------------------------------------------------------------------------

# Project Structure

``` text
lib/
├── app/
│   ├── router/
│   ├── theme/
│   └── app.dart
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── services/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── authentication/
│   ├── dashboard/
│   ├── expenses/
│   ├── history/
│   ├── reports/
│   ├── members/
│   ├── notifications/
│   └── settings/
│
└── main.dart
```

------------------------------------------------------------------------

# Feature Structure

Every feature should follow the same layout.

``` text
expenses/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
│
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
│
└── presentation/
    ├── pages/
    ├── widgets/
    └── providers/
```

------------------------------------------------------------------------

# Layer Responsibilities

## Presentation

-   Pages
-   Widgets
-   Providers
-   UI state
-   User interactions

Never access Firebase directly.

## Domain

-   Business rules
-   Entities
-   Use cases
-   Repository contracts

Independent from Flutter and Firebase.

## Data

-   Firebase implementation
-   Local cache
-   Models
-   Repository implementation
-   Data mapping

------------------------------------------------------------------------

# State Management

Use Riverpod.

Guidelines: - AsyncNotifier for async state - Notifier for simple
state - Keep providers feature-specific - Avoid global mutable state

------------------------------------------------------------------------

# Navigation

Use GoRouter.

Routes: - Splash - Login - Register - Dashboard - History - Add
Expense - Expense Details - Reports - Members - Notifications - Settings

Protect authenticated routes.

------------------------------------------------------------------------

# Repository Pattern

Each feature owns its repository.

Example:

ExpenseRepository - createExpense() - updateExpense() -
deleteExpense() - approveExpense() - markPaid() - getExpenses()

Presentation communicates only with repositories through the domain
layer.

------------------------------------------------------------------------

# Data Sources

Remote: - Firestore - Firebase Storage - Firebase Authentication

Local: - Isar

------------------------------------------------------------------------

# Model Mapping

Firestore JSON ↓ Data Model ↓ Domain Entity ↓ UI Model (if required)

Keep mapping explicit.

------------------------------------------------------------------------

# Dependency Flow

UI ↓ Provider ↓ Use Case ↓ Repository ↓ Data Source ↓ Firebase

Dependencies only flow downward.

------------------------------------------------------------------------

# Error Handling

Create shared error types: - NetworkFailure - AuthenticationFailure -
PermissionFailure - ValidationFailure - UnknownFailure

Convert Firebase exceptions into application-specific failures.

------------------------------------------------------------------------

# Offline Strategy

Cache: - Dashboard - Categories - Recent Transactions - User Profile

Sync pending changes when connectivity returns.

------------------------------------------------------------------------

# Logging

Development: - debugPrint

Production: - Crashlytics (future)

Never log sensitive user data.

------------------------------------------------------------------------

# Security

Never trust client input.

Validate: - User permissions - Treasurer role - House membership -
Required fields

Enforce rules in Firestore Security Rules.

------------------------------------------------------------------------

# Testing Strategy

Unit Tests: - Use cases - Repositories

Widget Tests: - UI components - Forms

Integration Tests: - Authentication - Expense workflow - Dashboard

------------------------------------------------------------------------

# Coding Principles

-   SOLID
-   DRY
-   KISS
-   Composition over inheritance
-   Reusable widgets
-   Feature isolation

------------------------------------------------------------------------

# AI Implementation Rules

Before implementing a feature: 1. Read PROJECT_CONTEXT.md 2. Read
REQUIREMENTS.md 3. Read DATABASE.md 4. Read BUSINESS_RULES.md 5. Read
UI_GUIDELINES.md

Then: - Create entities - Create models - Create repository - Create
providers - Build UI - Write tests - Suggest Git commit

Never skip architecture.

------------------------------------------------------------------------

# Definition of Done

Architecture is followed when: - Feature is isolated - UI is separated
from business logic - Firebase is accessed only through repositories -
Providers are scoped correctly - No duplicated logic exists

------------------------------------------------------------------------

# Next Document

08_DEVELOPMENT_GUIDE.md
