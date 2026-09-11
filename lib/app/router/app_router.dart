import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/breakpoints.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/responsive_page.dart';
import '../../features/authentication/domain/entities/user_entity.dart';
import '../../features/members/domain/entities/house_entity.dart';
import '../../features/authentication/presentation/pages/splash_page.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/pages/register_page.dart';
import '../../features/authentication/presentation/pages/forgot_password_page.dart';
import '../../features/authentication/presentation/pages/reset_password_page.dart';
import '../../features/authentication/presentation/providers/auth_provider.dart';
import '../../features/members/presentation/pages/create_house_page.dart';
import '../../features/members/presentation/pages/join_house_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/expenses/presentation/pages/add_expense_page.dart';
import '../../features/expenses/presentation/pages/bill_details_page.dart';
import '../../features/expenses/presentation/pages/deposit_page.dart';
import '../../features/expenses/presentation/pages/direct_payment_page.dart';
import '../../features/expenses/presentation/pages/expense_details_page.dart';
import '../../features/expenses/presentation/pages/expense_list_page.dart';
import '../../features/expenses/presentation/pages/transaction_details_page.dart';
import '../../features/history/presentation/pages/bill_history_page.dart';
import '../../features/history/presentation/pages/history_page.dart';
import '../../features/history/presentation/providers/history_provider.dart';
import '../../features/notifications/presentation/pages/notification_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/profile_page.dart';
import '../../features/members/presentation/pages/member_list_page.dart';
import '../../features/members/presentation/providers/house_provider.dart';

import 'route_names.dart';
import 'reset_deep_link.dart';
import 'auth_guard.dart';

/// Riverpod provider that creates and manages the GoRouter instance.
///
/// Watches auth and house state so the router rebuilds and re-evaluates
/// redirects whenever any of it changes. The house-resolution notifier is part
/// of that set: the guard holds an authenticated user on the splash while their
/// house lookup is unfinished, so the moment resolution completes must reach
/// the router or the hold would never end.
final goRouterProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final houseRepo = ref.watch(houseRepositoryProvider);

  // Activate auth↔house bridge — loads user's house on login.
  ref.watch(houseCoordinatorProvider);

  final notifier = _CombinedListenable([
    authRepo.currentUserNotifier,
    houseRepo.currentHouseNotifier,
    houseRepo.houseResolvedNotifier,
  ]);
  ref.onDispose(() => notifier.dispose());

  return AppRouter._create(
    authRepo.currentUserNotifier,
    houseRepo.currentHouseNotifier,
    houseRepo.houseResolvedNotifier,
  );
});

/// Combines multiple [ValueNotifier]s into a single [Listenable].
class _CombinedListenable extends ChangeNotifier {
  _CombinedListenable(this._notifiers) {
    for (final n in _notifiers) {
      n.addListener(notifyListeners);
    }
  }

  final List<ValueNotifier> _notifiers;

  @override
  void dispose() {
    for (final n in _notifiers) {
      n.removeListener(notifyListeners);
    }
    super.dispose();
  }
}

// ──────────────────────────────────────────────
// Page Transition Helpers
// ──────────────────────────────────────────────

/// A fade-through transition: the current screen fades to black briefly,
/// then the next screen fades in. Per Emil's philosophy, use ease-out
/// for the exit and ease-in for the entrance.
///
/// This is the Flutter equivalent of a native iOS push transition
/// but using opacity instead of slide for a more elegant feel.
Page<T> _fadeTransition<T>(Widget child) {
  return CustomTransitionPage<T>(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation.drive(CurveTween(curve: AppEasing.easeOut)),
        child: child,
      );
    },
    transitionDuration: AppDurations.pageTransition,
    reverseTransitionDuration: AppDurations.standard,
  );
}

/// Slide-up transition for modals and bottom-sheet-like pages.
Page<T> _slideUpTransition<T>(Widget child) {
  return CustomTransitionPage<T>(
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: AppEasing.easeOut)),
        child: FadeTransition(
          opacity: animation.drive(CurveTween(curve: AppEasing.easeOut)),
          child: child,
        ),
      );
    },
    transitionDuration: AppDurations.modal,
    reverseTransitionDuration: AppDurations.standard,
  );
}

/// Fallback when a detail route is reached without the expected payload
/// (e.g. a stale deep link) — never crash.
Widget _missingExtraScaffold() {
  return const Scaffold(
    body: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Unable to open this item.'),
      ),
    ),
  );
}

/// No transition — use for instant navigation (e.g., auth redirects).
Page<T> _noTransition<T>(Widget child) {
  return CustomTransitionPage<T>(
    child: child,
    transitionsBuilder:
        (context, animation, secondaryAnimation, child) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}

/// GoRouter configuration for Rental Ledger.
///
/// Routes are protected by [AuthGuard] which redirects
/// unauthenticated users to the login screen.
/// Page transitions follow Emil's design engineering philosophy:
/// - UI animations under 300ms
/// - ease-out for responsiveness
/// - No animation on auth redirects (keyboard-initiated)
class AppRouter {
  AppRouter._();

  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final AuthGuard _authGuard = AuthGuard();

  /// Deep-link initial location when the app was opened from a reset email,
  /// else `null` (the router falls back to the splash screen).
  static String? _deepLinkInitialLocation() =>
      resolveResetDeepLinkLocation(Uri.base);

  /// Creates the GoRouter instance, wired to auth + house notifiers.
  static GoRouter _create(
    ValueNotifier<UserEntity?> authNotifier,
    ValueNotifier<HouseEntity?> houseNotifier,
    ValueNotifier<bool> houseResolvedNotifier,
  ) {
    final initialLocation =
        AppRouter._deepLinkInitialLocation() ?? RouteNames.splash;
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: initialLocation,
      debugLogDiagnostics: true,
      observers: [_FabClosingObserver()],

      refreshListenable: _CombinedListenable([
        authNotifier,
        houseNotifier,
        houseResolvedNotifier,
      ]),

      redirect: (context, state) {
        return _authGuard.handleRedirect(
          context,
          state,
          currentUser: authNotifier.value,
          hasHouse: houseNotifier.value != null,
          isHouseResolved: houseResolvedNotifier.value,
        );
      },

      // ── Routes ──
      routes: [
        // ── Auth flow ──
        GoRoute(
          path: RouteNames.splash,
          name: RouteNames.splash,
          pageBuilder: (context, state) => _noTransition(const SplashPage()),
        ),
        GoRoute(
          path: RouteNames.login,
          name: RouteNames.login,
          pageBuilder: (context, state) => _fadeTransition(const LoginPage()),
        ),
        GoRoute(
          path: RouteNames.register,
          name: RouteNames.register,
          pageBuilder:
              (context, state) => _fadeTransition(const RegisterPage()),
        ),
        GoRoute(
          path: RouteNames.forgotPassword,
          name: RouteNames.forgotPassword,
          pageBuilder:
              (context, state) =>
                  _slideUpTransition(const ForgotPasswordPage()),
        ),
        // Public reset-password deep link. Opened by Firebase's in-app
        // (`handleCodeInApp`) reset email with `mode` + `oobCode` query params.
        GoRoute(
          path: RouteNames.resetPassword,
          name: RouteNames.resetPassword,
          pageBuilder: (context, state) => _fadeTransition(
            ResetPasswordPage(
              oobCode: state.uri.queryParameters['oobCode'] ?? '',
            ),
          ),
        ),

        // ── House onboarding ──
        GoRoute(
          path: RouteNames.createHouse,
          name: RouteNames.createHouse,
          pageBuilder:
              (context, state) => _slideUpTransition(const CreateHousePage()),
        ),
        GoRoute(
          path: RouteNames.joinHouse,
          name: RouteNames.joinHouse,
          pageBuilder:
              (context, state) => _slideUpTransition(const JoinHousePage()),
        ),

        // ── Main app shell (with bottom nav) ──
        ShellRoute(
          builder: (context, state, child) => _buildShell(context, child),
          routes: [
            GoRoute(
              path: RouteNames.dashboard,
              name: RouteNames.dashboard,
              pageBuilder:
                  (context, state) => _fadeTransition(const DashboardPage()),
              routes: [
                GoRoute(
                  path: RouteNames.historyRelative,
                  name: RouteNames.history,
                  pageBuilder:
                      (context, state) => _fadeTransition(const HistoryPage()),
                ),
                GoRoute(
                  path: RouteNames.addExpenseRelative,
                  name: RouteNames.addExpense,
                  pageBuilder:
                      (context, state) =>
                          _slideUpTransition(const AddExpensePage()),
                ),
                GoRoute(
                  path: RouteNames.reportsRelative,
                  name: RouteNames.reports,
                  pageBuilder:
                      (context, state) => _fadeTransition(const ReportsPage()),
                ),
              ],
            ),

            // ── Sub-pages inside the shell (keep bottom bar) ──
            GoRoute(
              path: RouteNames.expenses,
              name: RouteNames.expenses,
              pageBuilder:
                  (context, state) => _fadeTransition(const ExpenseListPage()),
            ),
            GoRoute(
              path: RouteNames.members,
              name: RouteNames.members,
              pageBuilder:
                  (context, state) => _fadeTransition(const MemberListPage()),
            ),
            GoRoute(
              path: RouteNames.notifications,
              name: RouteNames.notifications,
              pageBuilder:
                  (context, state) => _fadeTransition(const NotificationPage()),
            ),
            GoRoute(
              path: RouteNames.settings,
              name: RouteNames.settings,
              pageBuilder:
                  (context, state) => _fadeTransition(const SettingsPage()),
            ),
            GoRoute(
              path: RouteNames.profile,
              name: RouteNames.profile,
              pageBuilder:
                  (context, state) => _fadeTransition(const ProfilePage()),
            ),
            GoRoute(
              path: RouteNames.deposit,
              name: RouteNames.deposit,
              pageBuilder:
                  (context, state) => _fadeTransition(const DepositPage()),
            ),
            GoRoute(
              path: RouteNames.directPayment,
              name: RouteNames.directPayment,
              pageBuilder:
                  (context, state) =>
                      _fadeTransition(const DirectPaymentPage()),
            ),
          ],
        ),

        // ── Full-screen flow routes (hide bottom bar) ──
        GoRoute(
          path: RouteNames.expenseDetails,
          name: RouteNames.expenseDetails,
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final expenseId = state.pathParameters['expenseId'] ?? '';
            return _slideUpTransition(ExpenseDetailsPage(expenseId: expenseId));
          },
        ),
        GoRoute(
          path: RouteNames.depositDetails,
          name: RouteNames.depositDetails,
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final event = state.extra;
            return _slideUpTransition(
              event is HistoryEvent
                  ? DepositDetailsPage(event: event)
                  : _missingExtraScaffold(),
            );
          },
        ),
        GoRoute(
          path: RouteNames.directPaymentDetails,
          name: RouteNames.directPaymentDetails,
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final event = state.extra;
            return _slideUpTransition(
              event is HistoryEvent
                  ? DirectPaymentDetailsPage(event: event)
                  : _missingExtraScaffold(),
            );
          },
        ),
        GoRoute(
          path: RouteNames.billDetails,
          name: RouteNames.billDetails,
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder: (context, state) {
            final billId = state.pathParameters['billId'] ?? '';
            return _slideUpTransition(BillDetailsPage(billId: billId));
          },
        ),
        // Bill History — a pushed sub-page (like the detail routes above), so
        // the AppBar's back button returns to whichever surface opened it
        // (Dashboard's Upcoming Bills, the drawer, or a deep link).
        GoRoute(
          path: RouteNames.billHistory,
          name: RouteNames.billHistory,
          parentNavigatorKey: _rootNavigatorKey,
          pageBuilder:
              (context, state) => _slideUpTransition(const BillHistoryPage()),
        ),
      ],

      // ── Error page ──
      errorBuilder:
          (context, state) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: AppTheme.errorRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Page not found',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The page you are looking for does not exist.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => context.go(RouteNames.dashboard),
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  /// Builds the main app shell with bottom navigation and FAB speed dial.
  static Widget _buildShell(BuildContext context, Widget child) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _navIndexFor(location);

    // Hide the FAB on the Add Expense page so the Submit button
    // is the clear primary action.
    final hideFab = location.contains('add-expense');

    return _AppShell(
      currentIndex: currentIndex,
      showFab: !hideFab,
      child: child,
    );
  }

  /// Maps a route path to a bottom nav index.
  ///
  /// Index 2 is reserved for the center "+" docked FAB (an action, not a tab),
  /// so it never represents a selected route.
  static int _navIndexFor(String location) {
    if (location.startsWith('/dashboard/history') ||
        location.startsWith('/history')) {
      return 1; // History tab
    }
    if (location.startsWith(RouteNames.expenses)) {
      return 3; // Expenses tab
    }
    if (location.startsWith('/dashboard/reports') ||
        location.startsWith('/reports')) {
      return 4; // Reports tab
    }
    return 0; // Home tab (dashboard + sub-pages)
  }
}

/// Collapses the speed-dial on every navigation event (push/pop/replace), so
/// an open "+" menu can never survive a route change — including full-screen
/// detail pushes that leave the shell subtree untouched.
class _FabClosingObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _AppShell.collapseSpeedDial?.call();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _AppShell.collapseSpeedDial?.call();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _AppShell.collapseSpeedDial?.call();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _AppShell.collapseSpeedDial?.call();
  }
}

/// Main app shell with bottom navigation and FAB speed dial.
class _AppShell extends ConsumerStatefulWidget {
  const _AppShell({
    required this.currentIndex,
    required this.child,
    this.showFab = true,
  });
  final int currentIndex;
  final Widget child;
  final bool showFab;

  /// Static hook the router-level observer uses to collapse the speed-dial on
  /// any route change. Only one shell instance exists at a time, and the
  /// active shell (re)registers it on init — so this is a safe single slot.
  static VoidCallback? collapseSpeedDial;

  @override
  ConsumerState<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<_AppShell>
    with SingleTickerProviderStateMixin {
  bool _fabExpanded = false;

  @override
  void initState() {
    super.initState();
    // Let the router observer close the speed-dial on any push/pop.
    _AppShell.collapseSpeedDial = _closeFab;
  }

  @override
  void dispose() {
    if (_AppShell.collapseSpeedDial == _closeFab) {
      _AppShell.collapseSpeedDial = null;
    }
    super.dispose();
  }

  void _onNavTap(int index) {
    final context = this.context;
    if (index == 2) {
      // Center "+" — the docked FAB handles the tap itself. Defensive:
      // toggle the action menu if this branch is ever hit directly.
      _toggleFab();
      return;
    }
    // Any other tab selection is navigation — close the speed-dial first so
    // a stale open menu never survives the switch.
    _closeFab();
    switch (index) {
      case 0:
        context.go(RouteNames.dashboard);
        break;
      case 1:
        context.go(RouteNames.history);
        break;
      case 3:
        context.go(RouteNames.expenses);
        break;
      case 4:
        context.go(RouteNames.reports);
        break;
    }
  }

  void _toggleFab() {
    setState(() => _fabExpanded = !_fabExpanded);
  }

  /// Collapses the speed-dial (no-op if already closed).
  void _closeFab() {
    if (_fabExpanded) setState(() => _fabExpanded = false);
  }

  @override
  void didUpdateWidget(covariant _AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shell wrapper is rebuilt on every navigation (fresh child), so this
    // is the reliable hook to close the speed-dial after ANY route change —
    // bottom-nav tab, drawer item, header-icon push, or Android back.
    _closeFab();
  }

  void _navigateTo(String route) {
    setState(() => _fabExpanded = false);
    // Push so the back button works on the opened page.
    context.push(route);
  }

  /// Builds the "My Houses" section in the drawer — lets users switch houses.
  Widget _buildHouseSwitcher(BuildContext context) {
    final housesAsync = ref.watch(userHousesProvider);
    final currentHouse = ref.watch(currentHouseProvider);

    return housesAsync.when(
      loading:
          () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      error: (_, __) => const SizedBox.shrink(),
      data: (houses) {
        if (houses.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'MY HOUSES',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            ...houses.map((house) {
              final isActive = house.houseId == currentHouse?.houseId;
              return ListTile(
                dense: true,
                leading: Icon(
                  isActive ? Icons.home_rounded : Icons.home_outlined,
                  color:
                      isActive ? AppTheme.primaryGreen : AppTheme.textSecondary,
                  size: 20,
                ),
                title: Text(
                  house.houseName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color:
                        isActive ? AppTheme.primaryGreen : AppTheme.textPrimary,
                  ),
                ),
                trailing:
                    isActive
                        ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.primaryGreen,
                          size: 18,
                        )
                        : null,
                onTap:
                    isActive
                        ? null
                        : () async {
                          Navigator.pop(context);
                          await ref
                              .read(switchHouseProvider.notifier)
                              .switchTo(house.houseId);
                          if (context.mounted) {
                            context.go(RouteNames.dashboard);
                          }
                        },
              );
            }),
          ],
        );
      },
    );
  }

  /// Builds the navigation drawer with app-wide links.
  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ── Drawer header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: theme.colorScheme.primary,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.home_rounded, color: Colors.white, size: 36),
                  SizedBox(height: 8),
                  Text(
                    'Rental Ledger',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── House Switcher ──
            _buildHouseSwitcher(context),

            const Divider(),

            _DrawerItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              onTap: () {
                Navigator.pop(context);
                context.go(RouteNames.dashboard);
              },
            ),
            _DrawerItem(
              icon: Icons.history_outlined,
              label: 'History',
              onTap: () {
                Navigator.pop(context);
                context.go(RouteNames.history);
              },
            ),
            _DrawerItem(
              icon: Icons.event_note_outlined,
              label: 'Bill History',
              // Sub-page — push (like Members/Notifications) so Back returns
              // to where the drawer was opened from.
              onTap: () {
                Navigator.pop(context);
                context.push(RouteNames.billHistory);
              },
            ),
            _DrawerItem(
              icon: Icons.receipt_long_outlined,
              label: 'Expenses',
              onTap: () {
                Navigator.pop(context);
                context.go(RouteNames.expenses);
              },
            ),
            _DrawerItem(
              icon: Icons.people_outlined,
              label: 'Members',
              // Sub-page — push (not go) so the AppBar back button has a
              // previous page to pop back to. Tabs above use go() because
              // they're root destinations where back-stacking is wrong.
              onTap: () {
                Navigator.pop(context);
                context.push(RouteNames.members);
              },
            ),
            _DrawerItem(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () {
                Navigator.pop(context);
                context.push(RouteNames.notifications);
              },
            ),
            _DrawerItem(
              icon: Icons.bar_chart_outlined,
              label: 'Reports',
              onTap: () {
                Navigator.pop(context);
                context.go(RouteNames.reports);
              },
            ),
            const Divider(),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () {
                Navigator.pop(context);
                context.push(RouteNames.settings);
              },
            ),
            const Spacer(),
            _DrawerItem(
              icon: Icons.logout_outlined,
              label: 'Sign Out',
              color: AppTheme.errorRed,
              onTap: () async {
                Navigator.pop(context);
                await ref.read(logoutProvider.notifier).logout();
                if (context.mounted) {
                  context.go(RouteNames.login);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // When the speed-dial is open, Android back collapses it instead of
      // navigating away — the user must tap back again to leave the page.
      canPop: !_fabExpanded,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _fabExpanded) _closeFab();
      },
      child: Scaffold(
        body: widget.child,
        drawer: _buildDrawer(context),
        bottomNavigationBar: _buildBottomBar(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: widget.showFab ? _buildFab(context) : null,
      ),
    );
  }

  /// Builds the 5-slot bottom bar: Home | History | (+) | Expenses | Reports.
  ///
  /// A [BottomAppBar] with a center notch hosts the circular "+" FAB, so the
  /// primary creation action stays visually distinct and never overlaps an
  /// item. Each item is equal-width so 5 items fit on narrow screens without
  /// clipping or overflow; the whole bar is safe-area aware.
  Widget _buildBottomBar(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      shape: widget.showFab ? const CircularNotchedRectangle() : null,
      notchMargin: 6,
      padding: EdgeInsets.zero,
      child: ResponsivePage(
        // Cap the bottom-nav items to a centered column on wide viewports so
        // they never stretch across a large monitor; below the cap this is a
        // strict no-op, so phones/tablets keep the current full-width bar.
        // The "+" slot stays at the bar's centre, which lines up with the
        // docked FAB (also screen-centred).
        maxWidth: AppContentWidth.dashboard,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                _BottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  selected: widget.currentIndex == 0,
                  onTap: () => _onNavTap(0),
                ),
                _BottomNavItem(
                  icon: Icons.history_outlined,
                  activeIcon: Icons.history_rounded,
                  label: 'History',
                  selected: widget.currentIndex == 1,
                  onTap: () => _onNavTap(1),
                ),
                // Reserved space so the docked "+" never covers an item.
                const SizedBox(width: 56),
                _BottomNavItem(
                  icon: Icons.receipt_long_outlined,
                  activeIcon: Icons.receipt_long_rounded,
                  label: 'Expenses',
                  selected: widget.currentIndex == 3,
                  onTap: () => _onNavTap(3),
                ),
                _BottomNavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Reports',
                  selected: widget.currentIndex == 4,
                  onTap: () => _onNavTap(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the center "+" action. Collapsed it's the circular elevated FAB;
  /// expanded it shows the speed-dial menu (Direct Payment, Deposit,
  /// Add Expense) above it — the same actions as before, just docked centre.
  Widget _buildFab(BuildContext context) {
    final theme = Theme.of(context);
    // Deposit and Direct Payment move money in/out of the Central Account, so
    // the speed-dial only offers them to the house Treasurer. Add Expense is
    // available to every member (they claim against the account; the Treasurer
    // still approves/reimburses).
    final house = ref.watch(currentHouseProvider);
    final user = ref.watch(currentUserProvider);
    final isTreasurer =
        house != null && user != null && house.treasurerId == user.uid;

    if (!_fabExpanded) {
      return PressScale(
        child: FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: theme.colorScheme.primary,
          child: const Icon(Icons.add_rounded, color: Colors.white),
        ),
      );
    }

    return TapRegion(
      // Any tap outside the speed-dial (body, bottom nav, drawer) collapses
      // the menu — no stale open "+" after the user moves on.
      onTapOutside: (_) => _closeFab(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Treasurer-only: moving money in/out of the Central Account.
          if (isTreasurer) ...[
            _SpeedDialItem(
              icon: Icons.payment_outlined,
              label: 'Direct Payment',
              color: AppTheme.statusDirectPayment,
              onTap: () => _navigateTo(RouteNames.directPayment),
            ),
            const SizedBox(height: 8),
            _SpeedDialItem(
              icon: Icons.arrow_downward_rounded,
              label: 'Deposit',
              color: AppTheme.successGreen,
              onTap: () => _navigateTo(RouteNames.deposit),
            ),
            const SizedBox(height: 8),
          ],
          _SpeedDialItem(
            icon: Icons.receipt_long_outlined,
            label: 'Add Expense',
            color: theme.colorScheme.primary,
            onTap: () => _navigateTo(RouteNames.addExpense),
          ),
          const SizedBox(height: 16),
          PressScale(
            child: FloatingActionButton(
              onPressed: _toggleFab,
              backgroundColor: AppTheme.textSecondary,
              child: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single item in the bottom navigation bar.
class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Teal primary for the active tab, muted gray for inactive ones.
    final color = selected ? AppTheme.primaryGreen : AppTheme.textHint;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedDialItem extends StatelessWidget {
  const _SpeedDialItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          // Fixed width so all speed-dial items align perfectly.
          constraints: const BoxConstraints(minWidth: 180, minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            // Left-aligned (Row's default) inside the fixed-width chip so every
            // item shows a uniform `[icon] Label` — centering made the icon
            // drift with the label length.
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single item in the navigation drawer.
class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = color ?? theme.colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(label, style: TextStyle(color: iconColor)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
