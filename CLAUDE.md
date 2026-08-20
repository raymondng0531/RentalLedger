# Rental Ledger — Binding Project Rules

**Read `docs/12_AI_DIRECTION.md` before making any change to this codebase. Its rules are binding and override default behavior.**

Summary of the standing rules (full detail in the direction doc):

- **Project identity:** Rental Ledger is a **Central House Account Management System** — NOT Splitwise, not bill-splitting, not banking, not full accounting. The core workflow (buy → receipt → expense claim → Treasurer review → approve/reject → reimburse → Paid, plus Direct Payments) must stay unchanged.
- **Preserve everything that works.** Do not remove, replace, redesign, disable, simplify, or change any existing feature, workflow, business rule, UI behavior, database behavior, architecture, or package unless explicitly asked. Add features without breaking existing ones. Report improvements as *"Recommendation: …"* — never auto-apply.
- **Stack stays:** Flutter · Dart · Material 3 · Riverpod · GoRouter · Firebase (Auth / Firestore / Storage / Messaging) · Isar. Feature-First Clean Architecture (Presentation → Domain → Data → Firebase/Local).
- **Source of truth for existing features:** `docs/01_PROJECT_CONTEXT.md` … `docs/11_V1_REVIEW.md`.
- **Roadmap:**
  - V1.0: finish remaining items (PDF export, Bills History, report filters/analytics, member management UI) → **Web/PWA as the PRIMARY distribution platform** (extend this Flutter app — never fork a separate web app; don't sacrifice mobile features) → release.
  - V1.1: quality of life + user preferences + **dashboard customization** + **bottom-navigation customization** (Home and the `+` action stay fixed).
  - V1.2: offline experience (Isar stays — do not remove it for Web, don't build full offline early).
  - V2.0: OCR, AI categorization, Excel export, calendar, scheduled notifications, AI insights.
- **§21 upgrade in progress:** editing already-created expenses is a **required** product upgrade. Inspect the current expense lifecycle first, report the safest edit rules per status, and get explicit approval **before** changing any code or business rules. Do not weaken Treasurer/member permissions or the approval/reimbursement workflow; preserve audit/transaction integrity.
