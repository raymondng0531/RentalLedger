# 04_DATABASE.md

# Rental Ledger - Firestore Database Design

Version: 1.0

## Purpose

This document defines the Firestore database structure, relationships,
security considerations, and query patterns for Rental Ledger.

------------------------------------------------------------------------

# Database Overview

Collections:

-   users
-   houses
-   house_members
-   expenses
-   transactions
-   deposit_requests
-   categories
-   notifications
-   app_settings

The design is optimized for: - Fast dashboard loading - Low Firestore
read costs - Simple queries - Future scalability

------------------------------------------------------------------------

# Collection: users

Document ID: uid

  Field         Type        Description
  ------------- ----------- --------------
  uid           String      Firebase UID
  email         String      User email
  displayName   String      Full name
  photoUrl      String?     Avatar
  createdAt     Timestamp   Created time
  updatedAt     Timestamp   Last updated
  lastLoginAt   Timestamp   Last login

------------------------------------------------------------------------

# Collection: houses

Document ID: houseId

  Field         Type
  ------------- -----------
  houseId       String
  houseName     String
  inviteCode    String
  treasurerId   String
  balance       Double
  currency      String
  createdAt     Timestamp
  updatedAt     Timestamp
  isArchived    Boolean

------------------------------------------------------------------------

# Collection: house_members

Document ID: memberId

  Field      Type
  ---------- ---------------------------
  memberId   String
  houseId    String
  userId     String
  role       String (Treasurer/Member)
  joinedAt   Timestamp
  isActive   Boolean

------------------------------------------------------------------------

# Collection: categories

Examples: - Rent - Utilities - Food - Household - Maintenance -
Internet - Other

Fields: - categoryId - houseId - name - icon - color - createdAt

------------------------------------------------------------------------

# Collection: expenses

Document ID: expenseId

  Field           Type
  --------------- --------------------------------------
  expenseId       String
  houseId         String
  purchasedBy     String
  approvedBy      String?
  reimbursedBy    String?
  title           String
  description     String
  categoryId      String
  amount          Double
  receiptUrl      String
  paymentSource   personal / central
  status          pending / approved / rejected / paid
  createdAt       Timestamp
  approvedAt      Timestamp?
  paidAt          Timestamp?
  updatedAt       Timestamp

Notes: - Personal payments require reimbursement. - Central payments are
immediately completed.

------------------------------------------------------------------------

# Collection: transactions

Tracks all balance changes.

Types: - Deposit - Reimbursement - Direct Payment - Adjustment

Fields:

-   transactionId
-   houseId
-   expenseId (optional)
-   type
-   amount
-   performedBy
-   notes
-   createdAt

------------------------------------------------------------------------

# Collection: deposit_requests

A deposit a member submitted for themselves, awaiting the Treasurer. A
request is NOT a transaction and never affects the balance by itself.
On approval ONE Deposit transaction is written in the same Firestore
transaction, with `transactionId` = `requestId`.

Fields:

-   requestId
-   houseId
-   amount (positive)
-   paidByUserId (= submittedBy)
-   submittedBy
-   paymentMethod (optional)
-   periodLabel (optional, e.g. 2026-10)
-   purpose (optional)
-   notes (optional)
-   receiptUrl (proof — required by the app)
-   status: Pending \| Approved \| Rejected
-   rejectReason (optional)
-   reviewedBy (Treasurer uid)
-   reviewedAt
-   transactionId (set on approval; equals requestId)
-   createdAt
-   updatedAt (set on review)

Rules: house members read; a member creates only for themselves, as
Pending, in a house they belong to; only the house Treasurer moves
Pending → Approved/Rejected (an approval must be committed together
with its matching Deposit transaction); the submitter may delete only
their own Pending request.

Query: houseId == X and status == "Pending" (equality filters only, so
no composite index is required; sorted by createdAt in the app).

Proof images are stored under `receipts/{houseId}/` in Storage, like
expense receipts.

------------------------------------------------------------------------

# Collection: notifications

Fields:

-   notificationId
-   userId
-   title
-   body
-   type
-   isRead
-   relatedId
-   createdAt

Types: - Expense Submitted - Expense Approved - Expense Rejected -
Payment Completed - Deposit Recorded - Deposit Submitted - Deposit
Approved - Deposit Rejected

------------------------------------------------------------------------

# Collection: app_settings

Per-house configuration.

Fields:

-   language
-   currency
-   notificationsEnabled
-   theme

------------------------------------------------------------------------

# Relationships

users ↓ house_members ↓ houses ↓ expenses ↓ transactions

Notifications reference users.

------------------------------------------------------------------------

# Dashboard Queries

Central Balance - Read house document

Pending Reimbursements - expenses - where(status == "approved")

Monthly Expenses - expenses - where(createdAt within month)

Recent Activity - transactions - orderBy(createdAt desc) - limit(20)

------------------------------------------------------------------------

# Suggested Composite Indexes

expenses - houseId + status - houseId + createdAt - houseId + categoryId

transactions - houseId + createdAt

notifications - userId + isRead

------------------------------------------------------------------------

# Firestore Security Rules (Concept)

Users: - Read/write own profile only.

Houses: - Members can read. - Treasurer can update.

Expenses: - Members create own expenses. - Treasurer approves/rejects. -
Members edit only pending expenses.

Transactions: - Read by house members. - Write by Treasurer only.

Notifications: - Owner read only.

------------------------------------------------------------------------

# Soft Delete Strategy

Instead of deleting: - isArchived = true or - deletedAt timestamp

This preserves audit history.

------------------------------------------------------------------------

# Offline Strategy

Use Isar to cache: - Dashboard - Expenses - Categories - Recent Activity

Sync when online.

------------------------------------------------------------------------

# Example Expense JSON

``` json
{
  "expenseId": "exp001",
  "houseId": "house001",
  "purchasedBy": "uid123",
  "title": "Laundry Detergent",
  "amount": 25.90,
  "categoryId": "household",
  "paymentSource": "personal",
  "status": "pending",
  "receiptUrl": "https://...",
  "createdAt": "timestamp"
}
```

------------------------------------------------------------------------

# Future Expansion

-   Multiple houses per user
-   Budget planning
-   Recurring expenses
-   OCR metadata
-   Audit logs
-   Analytics

------------------------------------------------------------------------

# Next Document

05_BUSINESS_RULES.md
