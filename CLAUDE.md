# Rental Ledger — Binding Project Rules

**Read `docs/12_AI_DIRECTION.md` before making any change to this codebase. Its rules are binding and override default behavior.**

Summary of the standing rules (full detail in the direction doc):

- **Project identity:** Rental Ledger is a **Central House Account Management System** — NOT Splitwise, not bill-splitting, not banking, not full accounting. The core workflow (buy → receipt → expense claim → Treasurer review → approve/reject → reimburse → Paid, plus Direct Payments) must stay unchanged.
- **Preserve everything that works.** Do not remove, replace, redesign, disable, simplify, or change any existing feature, workflow, business rule, UI behavior, database behavior, architecture, or package unless explicitly asked. Add features without breaking existing ones. Report improvements as *"Recommendation: …"* — never auto-apply.
- **Stack stays:** Flutter · Dart · Material 3 · Riverpod · GoRouter · Firebase (Auth / Firestore / Storage / Messaging) · Isar. Feature-First Clean Architecture (Presentation → Domain → Data → Firebase/Local).
- **Source of truth for existing features:** `docs/01_PROJECT_CONTEXT.md` … `docs/11_V1_REVIEW.md`.
- **Roadmap:**
  - **Web/PWA is the PRIMARY ACTIVE DEVELOPMENT TARGET.** The existing Android/iOS app is FROZEN for personal use — do not make mobile-only changes unless explicitly requested; do not remove mobile support/features. Continue this ONE Flutter app (never fork a separate web app); preserve mobile behavior when touching shared code.
  - Current priorities: Flutter Web/PWA compatibility → responsive UI (phone / tablet / desktop) → Firebase Web → browser testing → PWA functionality → web hosting → production Web deployment → custom domain.
  - V1.1 (QoL + dashboard/bottom-nav customization), V1.2 (offline; Isar stays), V2.0 (OCR, AI, Excel, calendar, scheduled notifications, AI insights) — only when explicitly requested. The old mobile V1 release roadmap is paused unless explicitly requested.
- **§21 (expense editing) — implemented:** a member may edit their own **pending** expense (title, amount, description, category, receipt — take/choose/replace/remove). Payment source is locked; rejected/approved/paid expenses stay locked. Do not weaken Treasurer/member permissions or the approval/reimbursement workflow; preserve audit/transaction integrity.
