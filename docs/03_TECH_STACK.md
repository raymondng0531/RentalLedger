# 03_TECH_STACK.md

# Rental Ledger - Technical Stack & Engineering Standards

Version: 1.0

------------------------------------------------------------------------

# Purpose

This document defines the technology stack, project architecture, coding
standards, and engineering practices for Rental Ledger.

Every AI assistant and developer must follow this document when
implementing features.

------------------------------------------------------------------------

# Core Technology Stack

## Frontend

-   Flutter (Latest Stable)
-   Dart (Latest Stable)
-   Material Design 3

Reason: - Cross-platform - Fast development - Excellent Firebase support

------------------------------------------------------------------------

## Backend

Firebase Services

-   Firebase Authentication
-   Cloud Firestore
-   Firebase Storage
-   Firebase Cloud Messaging
-   Firebase Analytics (Future)

------------------------------------------------------------------------

## Local Database

Isar

Purpose: - Offline caching - Faster loading - Temporary storage

------------------------------------------------------------------------

# State Management

Riverpod

Guidelines

-   Prefer AsyncNotifier/Notifier
-   Avoid global mutable state
-   Keep business logic inside providers

------------------------------------------------------------------------

# Navigation

GoRouter

Requirements

-   Typed routes where practical
-   Route guards for authentication
-   Deep link ready

------------------------------------------------------------------------

# Recommended Packages

Core

-   flutter_riverpod
-   go_router
-   firebase_core
-   firebase_auth
-   cloud_firestore
-   firebase_storage
-   firebase_messaging

Utilities

-   intl
-   uuid
-   image_picker
-   flutter_image_compress
-   google_mlkit_text_recognition

Charts

-   fl_chart

PDF

-   pdf
-   printing

Local Storage

-   isar
-   isar_flutter_libs

------------------------------------------------------------------------

# Folder Structure

``` text
lib/
│
├── core/
│   ├── constants/
│   ├── theme/
│   ├── errors/
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
│   ├── settings/
│   └── notifications/
│
├── services/
├── shared/
└── main.dart
```

------------------------------------------------------------------------

# Feature Structure

``` text
expenses/

data/
domain/
presentation/

data/
  models/
  repositories/
  datasources/

presentation/
  pages/
  widgets/
  providers/
```

------------------------------------------------------------------------

# Naming Conventions

Classes

-   PascalCase

Variables

-   camelCase

Files

-   snake_case.dart

Constants

-   UPPER_SNAKE_CASE

Private members

-   \_privateVariable

------------------------------------------------------------------------

# UI Standards

-   Material Design 3
-   Currency: MYR (RM)
-   Green fintech theme
-   Rounded corners
-   Responsive layouts
-   Reusable widgets

------------------------------------------------------------------------

# Theme

Support

-   Light Mode
-   Dark Mode (Future)

Typography

-   Display
-   Headline
-   Title
-   Body
-   Label

------------------------------------------------------------------------

# Error Handling

Every screen must handle:

-   Loading
-   Empty
-   Error
-   Offline

Never crash the application.

Provide meaningful user messages.

------------------------------------------------------------------------

# Firebase Standards

Authentication

-   Email & Password

Firestore

-   Collection per entity
-   Avoid nested collections unless justified
-   Use timestamps
-   Use UUID where appropriate

Storage

-   Compress images before upload

------------------------------------------------------------------------

# Security

-   Firebase Security Rules
-   Role-based access
-   Validate user permissions
-   Never trust client input

------------------------------------------------------------------------

# Logging

Development

-   debugPrint()

Production

-   Firebase Crashlytics (Future)

------------------------------------------------------------------------

# Git Workflow

Branch Naming

feature/dashboard

feature/history

bugfix/login

refactor/database

Commit Format

feat:

fix:

refactor:

docs:

style:

test:

Example

feat(expense): implement expense submission flow

------------------------------------------------------------------------

# Code Quality

-   Follow SOLID principles
-   Small reusable widgets
-   Single Responsibility Principle
-   Avoid duplicated code
-   Prefer composition over inheritance

------------------------------------------------------------------------

# Performance

-   Lazy loading
-   Pagination
-   Cached images
-   Minimize Firestore reads
-   Optimize rebuilds with Riverpod

------------------------------------------------------------------------

# AI Development Rules

Before generating code:

1.  Read PROJECT_CONTEXT.md
2.  Read REQUIREMENTS.md
3.  Read DATABASE.md
4.  Read BUSINESS_RULES.md

When implementing:

-   Build one feature at a time
-   Keep UI and business logic separate
-   Explain architecture decisions
-   Suggest improvements
-   Provide Git commit message

------------------------------------------------------------------------

# Definition of Done

A technical task is complete only if:

-   Code compiles
-   Analyzer has no warnings
-   UI follows design
-   Business logic works
-   Firebase integrated
-   Error states handled
-   Documentation updated
-   Git commit prepared

------------------------------------------------------------------------

# Next Document

04_DATABASE.md
