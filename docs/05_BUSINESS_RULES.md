# 05_BUSINESS_RULES.md

# Rental Ledger - Business Rules

Version: 1.0

## Purpose

This document defines the business rules that govern how Rental Ledger
behaves. All implementations must follow these rules to ensure
consistent behavior.

------------------------------------------------------------------------

# User Roles

## Treasurer

Permissions: - Create a house - Manage the Central Account - Record
deposits - Approve or reject member deposit requests - Record direct
payments - Approve or reject expense claims - Mark reimbursements as
paid - Manage members - View all reports

## Member

Permissions: - Join a house - Submit expense claims - Upload receipts -
Submit their own deposits for Treasurer approval - View transaction
history - View reports - Track reimbursement status

------------------------------------------------------------------------

# Expense Claim Workflow

## Personal Purchase

1.  Member purchases an item using personal funds.
2.  Member submits an expense with a receipt.
3.  Status becomes **Pending**.
4.  Treasurer reviews the claim.
5.  Treasurer either approves or rejects it.
6.  If approved, reimbursement is made from the Central Account.
7.  Status becomes **Paid**.
8.  A reimbursement transaction is recorded.

Status flow:

Draft → Pending → Approved → Paid

Rejected is a terminal state.

------------------------------------------------------------------------

# Direct Payment Workflow

Used when payment is made directly from the Central Account.

Flow:

Create Direct Payment

↓

Record Transaction

↓

Update Balance

↓

Completed

No reimbursement is required.

------------------------------------------------------------------------

# Deposit Workflow

There are two ways a deposit reaches the Central Account.

## Treasurer records a deposit (direct — unchanged)

1.  Treasurer records a deposit (any member may be chosen as the payer;
    proof required).
2.  Central Account balance increases.
3.  Deposit transaction is created.
4.  Members can view the transaction history.

## Member submits a deposit (request → Treasurer approval)

1.  A member opens **Submit Deposit** and records a deposit they paid
    themselves: amount, payment method, period and purpose (optional),
    notes, and a proof image (required). The payer is always the member
    themselves.
2.  A **deposit request** is created with status **Pending** in
    `deposit_requests`. It is NOT a transaction: the balance does not
    change. The Treasurer is notified.
3.  The request appears in the dashboard's Pending Items for the
    Treasurer (all requests) and for the submitter (their own).
4.  While Pending, the member may **cancel** (delete) their own request.
5.  The Treasurer reviews it:
    -   **Approve** — in ONE Firestore transaction the request is
        re-read and must still be Pending, it becomes **Approved**, and
        a Deposit transaction is written with the request id as its id
        (idempotency key), `performedBy` = Treasurer, `paidByUserId` =
        member, and the member's proof as `receiptUrl`; the balance
        increases in the same commit. The member is notified.
    -   **Reject** — the request becomes **Rejected** with an optional
        reason; nothing is written to the ledger. The member is notified.
6.  Reviewed requests are final: they cannot be reviewed again, edited
    or deleted. A second concurrent approval fails cleanly ("already
    reviewed") instead of recording the deposit twice.

History and reports read only `transactions`, so a request appears there
only after it is approved (as an ordinary Deposit).

------------------------------------------------------------------------

# House Creation

-   Creator automatically becomes Treasurer.
-   Generate a unique invite code.
-   House starts with RM0.00 balance.

------------------------------------------------------------------------

# Join House

Requirements: - Valid invite code - User is not already a member

Result: - User becomes a Member.

------------------------------------------------------------------------

# Leave House

Members may leave if: - No pending responsibilities.

Treasurer: - Must transfer ownership before leaving.

------------------------------------------------------------------------

# Expense Rules

Required fields: - Title - Amount (\> 0) - Category - Receipt - Payment
source

Members may edit or delete only while status is Pending.

Approved or Paid expenses cannot be modified.

------------------------------------------------------------------------

# Reimbursement Rules

Only the Treasurer may mark a reimbursement as paid.

When paid: - Expense status = Paid - Central Account balance decreases -
Transaction record created - Member notified

------------------------------------------------------------------------

# Transaction Rules

Transaction Types: - Deposit - Direct Payment - Reimbursement -
Adjustment

Transactions are immutable.

Corrections must be made with Adjustment transactions.

------------------------------------------------------------------------

# Notification Rules

Notify members when: - Expense submitted - Expense approved - Expense
rejected - Reimbursement completed - Deposit recorded - Deposit
submitted (to the Treasurer) - Deposit approved / rejected (to the
member who submitted it) - Treasurer changed

Notifications should be marked read/unread.

------------------------------------------------------------------------

# Dashboard Rules

Display: - Central Account Balance - This Month In - This Month Out -
Monthly Expenses - Upcoming Bills - Pending Reimbursements - Recent
Activity

Dashboard data should refresh after any financial transaction.

------------------------------------------------------------------------

# Balance Calculation

Current Balance = Total Deposits - Direct Payments - Reimbursements ±
Adjustments

Never calculate using expense status alone.

Use transaction history as the financial source of truth.

------------------------------------------------------------------------

# Permissions Matrix

  Action             Treasurer   Member
  ----------------- ----------- --------
  Create House           ✔         ✘
  Join House             ✔         ✔
  Submit Expense         ✔         ✔
  Approve Expense        ✔         ✘
  Reject Expense         ✔         ✘
  Mark Paid              ✔         ✘
  Record Deposit         ✔         ✘
  Submit Deposit         ✔¹        ✔
  Approve/Reject Deposit ✔         ✘
  Cancel own Pending
  Deposit Request        ✔         ✔
  View Reports           ✔         ✔
  Manage Members         ✔         ✘

¹ The Treasurer normally uses Record Deposit; the Submit Deposit entry
is offered to members.

------------------------------------------------------------------------

# Edge Cases

-   Duplicate receipt upload
-   Invalid invite code
-   Reimbursement with insufficient balance
-   Deleted user
-   Offline submission
-   Network interruption
-   Treasurer leaves the house
-   Expense approved twice
-   Duplicate deposit
-   Receipt upload failure

All edge cases must provide clear user feedback.

------------------------------------------------------------------------

# Audit Trail

Record: - Who performed the action - What changed - Timestamp

Examples: - Expense Submitted - Expense Approved - Expense Rejected -
Reimbursement Paid - Deposit Recorded - Member Joined - Treasurer
Changed

Audit records should never be edited.

------------------------------------------------------------------------

# Future Rules

-   Multi-house support
-   Budget limits
-   Recurring expenses
-   Recurring deposits
-   OCR confidence validation
-   Spending alerts

------------------------------------------------------------------------

# Definition of Done

Business logic is complete only if: - Workflow follows this document -
Permission checks are enforced - Transactions are recorded correctly -
Notifications are triggered - Audit trail is updated - Dashboard
reflects latest data

------------------------------------------------------------------------

# Next Document

06_UI_GUIDELINES.md
