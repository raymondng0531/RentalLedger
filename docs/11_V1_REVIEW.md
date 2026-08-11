# 11_V1_REVIEW.md

# Version 1.0 -- Final Review

Date: 2026-08-06
Status: App is stable and polished; a small set of V1.0 features remain
unfinished before release.

------------------------------------------------------------------------

## 1. Remaining bugs / inconsistencies

No critical bugs remain. The app builds cleanly (`flutter analyze` 0
errors / 0 warnings), all 75 tests pass, and a Windows debug build
succeeds. Remaining low-severity items:

- **Language picker is decorative.** The app locale is hardcoded
  `Locale('ms', 'MY')` in `lib/app/app.dart` and there are no
  localization delegates / .arb files, so choosing English changes
  nothing visible.
- **Preferences aren't persisted.** Language / currency / notification
  settings are in-memory only and reset on every restart (planned for
  V1.1 "Persist User Preferences").
- **Profile edit doesn't propagate display name.** Editing the profile
  updates Firebase Auth, but the Firestore `users/{uid}.displayName` and
  existing `house_members` records keep the old name, so member lists and
  the activity feed show the previous name until those records refresh.
- **Push requires deployment.** In-app notifications work (Firestore +
  rules fix). Actual FCM push needs `firebase deploy --only functions`
  (the Cloud Function is ready) plus the Firestore rules deploy.
- **Splash auth race (minor).** `SplashPage` reads a one-shot auth
  snapshot; on a very slow session restore a signed-in user may briefly
  see the login screen (the router then redirects back).
- **Dead provider.** `notificationsProvider` (one-shot) is no longer used
  by any UI (the stream is used) — safe to remove.

## 2. Unfinished V1.0 features (to complete before release)

- [ ] **PDF Export** — the Reports toolbar button is a stub
      (`reports_page.dart`).
- [ ] **Bills History Page** — paid bills are hidden from Upcoming Bills
      with no dedicated history view.
- [ ] **Better Report Filters** — Reports has no date-range / status
      filters yet.
- [ ] **Better Analytics** — deposits now appear in the monthly bar
      chart; further analytics are open.
- [ ] **Member Management UI** — `leaveHouseProvider`,
      `transferTreasurerProvider`, and `removeMember` are implemented at
      the data layer but have **no UI entry points**. The Member list
      shows members but has no Leave / Remove / Transfer actions. (The
      `MemberTile` already supports `showActions`/`onRemove`; only
      wiring is missing.)
- [ ] **Unread notification badge** — the dashboard bell has no unread
      count badge even though `unreadCountProvider` exists.

## 3. Placeholders / TODOs

- `lib/core/services/isar_service.dart` — placeholder for the offline
  feature (V1.2).
- `lib/features/settings/.../settings_page.dart` — Dark Mode toggle is
  "coming soon" (V1.1).
- `lib/features/reports/.../reports_page.dart` — "TODO: Export PDF".
- `_NoOp*Repository` stubs (auth / house / expense) — intentional
  fallbacks when Firebase isn't configured; keep.

## 4. Technical debt / architecture improvements

- **Duplicate data-source construction.** `expenseListProvider`,
  `billsProvider`, and `historyProvider` each `new ExpenseRemoteDataSource()`
  instead of sharing one provider.
- **`_NoOp*Repository` duplication** across three providers could be
  centralized.
- **Repeated UI patterns** — every form page re-implements the
  "loading button with spinner" and "white scaffold + back AppBar".
  Extracting shared widgets (`PrimarySubmitButton`, `FormScaffold`)
  would reduce drift.
- **`CurrencyUtils` uses mutable static state** (functional now, but a
  global — acceptable until multi-currency lands in V2.0).
- **`_CombinedListenable`** in the router is a small workaround for
  combining notifiers — fine, but worth a comment.
- **Test coverage is thin**: 75 unit/widget tests, no integration tests,
  and nothing covering the new History filter sheet or the animated
  list. Add widget tests for the filter sheet and key flows.

## 5. Suggested missing features to improve V1.0

- Leave House + Member Management UI (listed above — highest value).
- Unread badge on the dashboard notifications bell.
- Pull-to-refresh on the Notifications page.
- Empty-state illustrations reuse (already consistent via `EmptyState`).
- `Firebase deploy` runbook (rules + functions) documented in the
  README so push and rules take effect in production.

------------------------------------------------------------------------

# Recommendation

The app is stable, consistent, and production-ready **except** for the
Member Management UI and PDF Export. Completing those two, plus deploying
the Firestore rules and Cloud Function, makes Version 1.0 genuinely
release-ready. Version 1.1 (dark mode, persistence, QoL) can start after.
