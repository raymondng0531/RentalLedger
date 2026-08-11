# 08_DEVELOPMENT_GUIDE.md

# Rental Ledger - AI Development Guide

Version: 1.0

## Purpose

This document defines the standard workflow for developing Rental Ledger
with AI coding assistants such as ChatGPT, Cursor, Claude Code,
Windsurf, and Gemini CLI.

Every feature should be built consistently using this guide.

------------------------------------------------------------------------

# Development Principles

-   Build one feature at a time.
-   Finish the current feature before starting the next.
-   Never skip planning.
-   Keep business logic separate from UI.
-   Prefer reusable components over duplication.
-   Small, reviewable commits.

------------------------------------------------------------------------

# AI Workflow

Before coding, always read:

1.  01_PROJECT_CONTEXT.md
2.  02_REQUIREMENTS.md
3.  03_TECH_STACK.md
4.  04_DATABASE.md
5.  05_BUSINESS_RULES.md
6.  06_UI_GUIDELINES.md
7.  07_ARCHITECTURE.md

Do not assume requirements that are not documented.

------------------------------------------------------------------------

# Feature Development Process

For every new feature:

## Step 1 -- Understand

-   Review requirements
-   Identify user stories
-   Check business rules

## Step 2 -- Plan

-   Database changes
-   Models
-   Repository methods
-   Providers
-   UI screens
-   Navigation
-   Tests

## Step 3 -- Implement

Create in this order:

1.  Entity
2.  Model
3.  Data Source
4.  Repository
5.  Provider
6.  UI
7.  Routing
8.  Tests

## Step 4 -- Verify

Confirm: - UI matches Figma - Business rules are respected - Error
handling exists - Loading/empty/offline states work

------------------------------------------------------------------------

# Standard Feature Checklist

-   UI completed
-   Validation implemented
-   Firebase integrated
-   Riverpod provider added
-   Repository implemented
-   Navigation configured
-   Tests written
-   Documentation updated

------------------------------------------------------------------------

# Code Review Checklist

Architecture - Clean Architecture followed - No business logic inside
widgets - Repository pattern used

Code Quality - Meaningful names - Small widgets - No duplicate code -
SOLID principles

Performance - Avoid unnecessary rebuilds - Minimize Firestore reads -
Pagination where appropriate

Security - Firestore rules respected - Role checks implemented - Input
validated

------------------------------------------------------------------------

# Git Workflow

Branch examples:

feature/dashboard

feature/expenses

feature/reports

bugfix/login

refactor/providers

Commit format:

feat(dashboard): add monthly expenses card

fix(expense): validate amount input

docs(database): update expense schema

refactor(history): simplify transaction provider

------------------------------------------------------------------------

# Pull Request Checklist

-   Builds successfully
-   Analyzer clean
-   Screenshots attached (UI changes)
-   Documentation updated
-   Tests pass

------------------------------------------------------------------------

# Debugging Workflow

1.  Reproduce the issue.
2.  Identify root cause.
3.  Fix the smallest possible area.
4.  Retest affected features.
5.  Update documentation if business logic changes.

------------------------------------------------------------------------

# Refactoring Rules

Refactor only when: - Readability improves - Complexity decreases - No
functionality changes

Never mix new features with refactoring.

------------------------------------------------------------------------

# Testing Strategy

Unit Tests - Use cases - Repositories - Utilities

Widget Tests - Forms - Buttons - Cards - Navigation

Integration Tests - Login - Expense submission - Approval workflow -
Reports

------------------------------------------------------------------------

# Documentation Rules

Update documentation whenever: - Database changes - Business rules
change - New screen added - New package introduced - Architecture
changes

------------------------------------------------------------------------

# AI Prompt Templates

## Build Feature

Read all project documents.

Implement one feature following Clean Architecture.

Explain: - Files created - Design decisions - How to test

Provide a Git commit message.

------------------------------------------------------------------------

## Fix Bug

Read project documents.

Identify: - Root cause - Affected files - Safest fix

Avoid introducing breaking changes.

------------------------------------------------------------------------

## Review Code

Review as a Senior Flutter Engineer.

Check: - Architecture - Readability - Riverpod usage - Firebase usage -
Performance - Security

Suggest improvements only where beneficial.

------------------------------------------------------------------------

# Definition of Done

A feature is complete only if:

-   Requirements satisfied
-   UI implemented
-   Business rules followed
-   Firebase integrated
-   Error handling complete
-   Loading, empty, and offline states handled
-   Tests pass
-   Documentation updated
-   Git commit ready

------------------------------------------------------------------------

# Next Document

09_ROADMAP.md
