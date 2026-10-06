/// Centralized route path constants.
class RouteNames {
  RouteNames._();

  // ───── Auth routes ─────
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // ───── Main shell routes ─────
  static const String dashboard = '/dashboard';
  static const String historyRelative = 'history';
  static const String history = '/dashboard/history';
  static const String addExpenseRelative = 'add-expense';
  static const String addExpense = '/dashboard/add-expense';
  static const String reportsRelative = 'reports';
  static const String reports = '/dashboard/reports';

  // ───── Detail routes ─────
  static const String expenses = '/expenses';
  static const String expenseDetails = '/expenses/:expenseId';
  static const String depositDetails = '/deposit-details';
  static const String directPaymentDetails = '/direct-payment-details';
  static const String depositRequestDetails = '/deposit-requests/:requestId';
  static const String billDetails = '/bill-details/:billId';
  static const String billHistory = '/bill-history';
  static const String members = '/members';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String profile = '/profile';

  // ───── House routes ─────
  static const String createHouse = '/house/create';
  static const String joinHouse = '/house/join';

  // ───── Financial action routes ─────
  static const String deposit = '/deposit';
  static const String directPayment = '/direct-payment';

  /// A member submits a deposit they paid, for the Treasurer to approve.
  static const String submitDeposit = '/submit-deposit';
}
