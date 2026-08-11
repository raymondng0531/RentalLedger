/// Firestore collection path constants.
///
/// Centralizes all collection/document paths so they are
/// easy to update and impossible to mistype.
class FirestoreConstants {
  FirestoreConstants._();

  // ───────── Collections ─────────

  static const String users = 'users';
  static const String houses = 'houses';
  static const String houseMembers = 'house_members';
  static const String expenses = 'expenses';
  static const String transactions = 'transactions';
  static const String categories = 'categories';
  static const String notifications = 'notifications';
  static const String appSettings = 'app_settings';

  // ───────── Expense status values ─────────

  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusPaid = 'paid';

  // ───────── Transaction types ─────────

  static const String transactionDeposit = 'Deposit';
  static const String transactionReimbursement = 'Reimbursement';
  static const String transactionDirectPayment = 'Direct Payment';
  static const String transactionAdjustment = 'Adjustment';

  // ───────── Member roles ─────────

  static const String roleTreasurer = 'Treasurer';
  static const String roleMember = 'Member';

  // ───────── Payment sources ─────────

  static const String paymentPersonal = 'personal';
  static const String paymentCentral = 'central';

  // ───────── Notification types ─────────

  static const String notificationExpenseSubmitted = 'Expense Submitted';
  static const String notificationExpenseApproved = 'Expense Approved';
  static const String notificationExpenseRejected = 'Expense Rejected';
  static const String notificationPaymentCompleted = 'Payment Completed';
  static const String notificationDepositRecorded = 'Deposit Recorded';

  /// A member nudging the Treasurer to reimburse an expense they submitted.
  static const String notificationReminder = 'Reimbursement Reminder';
}
