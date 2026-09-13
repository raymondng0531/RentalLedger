import '../../features/expenses/domain/entities/category_entity.dart';
import '../../l10n/generated/app_localizations.dart';

/// Maps **stored** Firestore vocabulary onto localized display labels.
///
/// The stored values themselves are never translated, rewritten or migrated —
/// `pending`, `paid`, `Deposit`, `Cash`, `Rent` and friends keep their exact
/// spelling in Firestore, in every query and in every write. Only the string
/// that reaches the screen is localized here.
///
/// Every lookup below is therefore keyed on the stored value and returns a
/// label from [AppLocalizations]. Anything unrecognised falls back to the
/// stored value verbatim, so user-created data (a renamed category, a custom
/// purpose) is shown exactly as the user typed it.
class VocabularyLabels {
  VocabularyLabels._();

  /// Card/chip label for an expense's milestone.
  ///
  /// Mirrors the wording the app already used before localization: a `pending`
  /// expense reads "Submitted" on a card, because the card describes what the
  /// member did, not what the Treasurer has yet to do.
  static String activityStatus(String? status, AppLocalizations l10n) {
    switch (status) {
      case 'paid':
        return l10n.statusPaid;
      case 'approved':
        return l10n.statusApproved;
      case 'rejected':
        return l10n.statusRejected;
      default:
        return l10n.statusSubmitted;
    }
  }

  /// Label for the status badge on the expense detail page.
  ///
  /// Unlike [activityStatus] this names the state itself, because the badge
  /// sits next to a full workflow timeline.
  static String statusBadge(String? status, AppLocalizations l10n) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return l10n.statusPending;
      case 'approved':
        return l10n.statusApproved;
      case 'rejected':
        return l10n.statusRejected;
      case 'paid':
        return l10n.statusPaid;
      case 'completed':
        return l10n.statusCompleted;
      case 'direct payment':
        return l10n.txnTypeDirectPayment;
      default:
        return status ?? '';
    }
  }

  /// Label for a stored transaction type (`Deposit`, `Reimbursement`,
  /// `Direct Payment`, `Adjustment`).
  static String transactionType(String? type, AppLocalizations l10n) {
    switch (type) {
      case 'Deposit':
        return l10n.txnTypeDeposit;
      case 'Reimbursement':
        return l10n.txnTypeReimbursement;
      case 'Direct Payment':
        return l10n.txnTypeDirectPayment;
      case 'Adjustment':
        return l10n.txnTypeAdjustment;
      default:
        return type ?? '';
    }
  }

  /// Label for a stored payment source (`personal` / `central`).
  static String paymentSource(String? source, AppLocalizations l10n) {
    switch (source) {
      case 'personal':
        return l10n.paymentSourcePersonal;
      case 'central':
        return l10n.paymentSourceCentral;
      default:
        return source ?? '';
    }
  }

  /// Label for a stored payment method (`Cash`, `Bank Transfer`, `e-Wallet`,
  /// `Card`). An unrecognised method is shown exactly as stored.
  static String paymentMethod(String? method, AppLocalizations l10n) {
    switch (method) {
      case 'Cash':
        return l10n.paymentMethodCash;
      case 'Bank Transfer':
        return l10n.paymentMethodBankTransfer;
      case 'e-Wallet':
        return l10n.paymentMethodEWallet;
      case 'Card':
        return l10n.paymentMethodCard;
      default:
        return method ?? '';
    }
  }

  /// Label for a house role (`Treasurer` / `Member`).
  static String role(String? role, AppLocalizations l10n) {
    switch (role) {
      case 'Treasurer':
        return l10n.labelTreasurer;
      case 'Member':
        return l10n.labelMember;
      default:
        return role ?? '';
    }
  }

  /// Display name for an expense category.
  ///
  /// A category that still carries one of the seeded default names is shown
  /// with its localized label; a category the user renamed is shown with the
  /// user's own text, untouched. [categoryId] (when known) is preferred over
  /// [name] because it is the stable identity, but a renamed category is
  /// recognised by its name no longer matching the default for that id.
  static String category({
    required AppLocalizations l10n,
    String? categoryId,
    String? name,
  }) {
    final byId = _defaultCategoryById(categoryId, l10n);
    if (byId != null && (name == null || name == _defaultNameFor(categoryId))) {
      return byId;
    }
    final byName = _defaultCategoryByName(name, l10n);
    if (byName != null) return byName;
    return name ?? categoryId ?? '';
  }

  /// [category] that yields null instead of an empty string.
  static String? categoryOrNull({
    required AppLocalizations l10n,
    String? categoryId,
    String? name,
  }) {
    if (name == null && categoryId == null) return null;
    final label = category(l10n: l10n, categoryId: categoryId, name: name);
    return label.isEmpty ? null : label;
  }

  /// The seeded name for a default category id, or null when [categoryId] is
  /// not one of the defaults.
  static String? _defaultNameFor(String? categoryId) {
    for (final c in CategoryEntity.defaults) {
      if (c.categoryId == categoryId) return c.name;
    }
    return null;
  }

  static String? _defaultCategoryById(String? categoryId, AppLocalizations l10n) {
    switch (categoryId) {
      case 'rent':
        return l10n.categoryRent;
      case 'utilities':
        return l10n.categoryUtilities;
      case 'food':
        return l10n.categoryFood;
      case 'household':
        return l10n.categoryHousehold;
      case 'maintenance':
        return l10n.categoryMaintenance;
      case 'internet':
        return l10n.categoryInternet;
      case 'other':
        return l10n.categoryOther;
      default:
        return null;
    }
  }

  static String? _defaultCategoryByName(String? name, AppLocalizations l10n) {
    switch (name) {
      case 'Rent':
        return l10n.categoryRent;
      case 'Utilities':
        return l10n.categoryUtilities;
      case 'Food':
        return l10n.categoryFood;
      case 'Household':
        return l10n.categoryHousehold;
      case 'Maintenance':
        return l10n.categoryMaintenance;
      case 'Internet':
        return l10n.categoryInternet;
      case 'Other':
        return l10n.categoryOther;
      default:
        return null;
    }
  }
}
