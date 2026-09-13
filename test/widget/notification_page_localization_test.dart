import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:rental_ledger/features/notifications/domain/entities/notification_entity.dart';
import 'package:rental_ledger/features/notifications/presentation/pages/notification_page.dart';
import 'package:rental_ledger/features/notifications/presentation/providers/notification_provider.dart';
import 'package:rental_ledger/l10n/generated/app_localizations.dart';

/// Phase 13 cover for the Notifications screen.
///
/// The screen has two kinds of text and they follow opposite rules:
///
/// * **Stored content** — a notification's `title` and `body` are written to
///   Firestore by the Cloud Functions / `NotificationRemoteDataSource` and are
///   deliberately NOT localized. The same event has to read the same way for
///   every member of the house, and for the same member after they switch
///   language, so these strings must come through byte-for-byte in both
///   locales.
/// * **UI chrome** — the app bar, the group headers, the empty state and the
///   toasts are presentation. They follow the reader's language.
///
/// These tests pin both halves, so a future change that localizes stored
/// content (or forgets to localize chrome) fails here.

/// Stored content, exactly as a Cloud Function would have written it.
const _storedTitle = 'Expense Submitted';
const _storedBody = '"Aisyah" submitted an expense of RM 120.00 for "Groceries".';

NotificationEntity _notification({
  String id = 'n1',
  bool isRead = false,
  DateTime? createdAt,
}) {
  return NotificationEntity(
    notificationId: id,
    userId: 'member-1',
    title: _storedTitle,
    body: _storedBody,
    type: 'expense_submitted',
    isRead: isRead,
    createdAt: createdAt ?? DateTime.now(),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Locale locale, {
  List<NotificationEntity> items = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationsStreamProvider.overrideWith(
          (ref) => Stream.value(items),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const NotificationPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A "Back" pop needs somewhere to pop to, so the page is also exercised under
/// a router — a bare `MaterialApp` has an empty stack and `context.pop()` would
/// throw before the assertion ever runs.
Future<void> _pumpRouted(WidgetTester tester, Locale locale) async {
  final router = GoRouter(
    initialLocation: '/notifications',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const Scaffold()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationPage()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationsStreamProvider.overrideWith(
          (ref) => Stream.value(const <NotificationEntity>[]),
        ),
      ],
      child: MaterialApp.router(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Notifications — UI chrome follows the locale', () {
    testWidgets('English chrome', (tester) async {
      await _pump(tester, const Locale('en'), items: [_notification()]);

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byTooltip('Mark all as read'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      // The group header is the localized "Today" plus the date.
      expect(find.textContaining('Today'), findsOneWidget);
    });

    testWidgets('Malay chrome', (tester) async {
      await _pump(tester, const Locale('ms'), items: [_notification()]);

      expect(find.text('Pemberitahuan'), findsOneWidget);
      expect(find.byTooltip('Tanda semua sebagai dibaca'), findsOneWidget);
      expect(find.byTooltip('Kembali'), findsOneWidget);
      expect(find.textContaining('Hari ini'), findsOneWidget);
      expect(find.text('Notifications'), findsNothing);
      expect(find.byTooltip('Mark all as read'), findsNothing);
    });

    testWidgets('the empty state is localized in both locales', (tester) async {
      await _pump(tester, const Locale('en'));
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(
        find.text(
          'Updates about expenses, payments, and approvals will appear here.',
        ),
        findsOneWidget,
      );

      await _pump(tester, const Locale('ms'));
      expect(find.text('Tiada pemberitahuan lagi'), findsOneWidget);
      expect(find.text('No notifications yet'), findsNothing);
    });

    testWidgets('the group headers are localized', (tester) async {
      final now = DateTime.now();
      final items = [
        _notification(id: 'n1', createdAt: now.subtract(const Duration(days: 2))),
        _notification(id: 'n2', createdAt: now.subtract(const Duration(days: 30))),
      ];

      await _pump(tester, const Locale('en'), items: items);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('Earlier'), findsOneWidget);

      await _pump(tester, const Locale('ms'), items: items);
      expect(find.text('Minggu Ini'), findsOneWidget);
      expect(find.text('Terdahulu'), findsOneWidget);
      expect(find.text('This Week'), findsNothing);
      expect(find.text('Earlier'), findsNothing);
    });
  });

  group('Notifications — stored content is never translated', () {
    testWidgets('the stored title and body read identically in both locales',
        (tester) async {
      await _pump(tester, const Locale('en'), items: [_notification()]);
      expect(find.text(_storedTitle), findsOneWidget);
      expect(find.text(_storedBody), findsOneWidget);

      await _pump(tester, const Locale('ms'), items: [_notification()]);
      expect(find.text(_storedTitle), findsOneWidget,
          reason: 'a stored notification title must not be localized');
      expect(find.text(_storedBody), findsOneWidget,
          reason: 'a stored notification body must not be localized');
    });
  });

  group('Notifications — runtime language switch', () {
    testWidgets('switching locale re-resolves the chrome in place',
        (tester) async {
      final items = [_notification()];
      Widget appFor(Locale locale) => ProviderScope(
            overrides: [
              notificationsStreamProvider.overrideWith(
                (ref) => Stream.value(items),
              ),
            ],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const NotificationPage(),
            ),
          );

      await tester.pumpWidget(appFor(const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsOneWidget);

      // No restart, no provider invalidation: the same widget tree rebuilt
      // against the other locale.
      await tester.pumpWidget(appFor(const Locale('ms')));
      await tester.pumpAndSettle();

      expect(find.text('Pemberitahuan'), findsOneWidget);
      expect(find.text('Notifications'), findsNothing);
      // ...and the stored content is untouched by the switch.
      expect(find.text(_storedTitle), findsOneWidget);
      expect(find.text(_storedBody), findsOneWidget);
    });
  });

  group('Notifications — shell', () {
    testWidgets('the Back tooltip is localized under a router', (tester) async {
      await _pumpRouted(tester, const Locale('ms'));
      expect(find.byTooltip('Kembali'), findsOneWidget);

      await _pumpRouted(tester, const Locale('en'));
      expect(find.byTooltip('Back'), findsOneWidget);
    });
  });
}
