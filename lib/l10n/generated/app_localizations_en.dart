// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageSectionTitle => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMalay => 'Bahasa Melayu';

  @override
  String get navHome => 'Home';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navHistory => 'History';

  @override
  String get navBillHistory => 'Bill History';

  @override
  String get navExpenses => 'Expenses';

  @override
  String get navMembers => 'Members';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navReports => 'Reports';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionSignOut => 'Sign Out';

  @override
  String get drawerMyHouses => 'MY HOUSES';

  @override
  String get actionDirectPayment => 'Direct Payment';

  @override
  String get actionDeposit => 'Deposit';

  @override
  String get actionAddExpense => 'Add Expense';

  @override
  String get pageNotFoundTitle => 'Page not found';

  @override
  String get pageNotFoundMessage => 'The page you are looking for does not exist.';

  @override
  String get actionGoHome => 'Go Home';

  @override
  String get unableToOpenItem => 'Unable to open this item.';

  @override
  String get errorGenericMessage => 'Something went wrong. Please try again.';

  @override
  String get actionTryAgain => 'Try Again';

  @override
  String get centralAccountBalance => 'Central Account Balance';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get appTagline => 'Your household finances, simplified';

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String timeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get timeToday => 'Today';

  @override
  String get timeTomorrow => 'Tomorrow';

  @override
  String get periodLast7Days => 'Last 7 Days';

  @override
  String get periodLast30Days => 'Last 30 Days';

  @override
  String get periodLast90Days => 'Last 90 Days';

  @override
  String get periodThisMonth => 'This Month';

  @override
  String get periodLastMonth => 'Last Month';

  @override
  String get periodAll => 'All';

  @override
  String get periodCustomRange => 'Custom Range';

  @override
  String get billDueToday => 'Due Today';

  @override
  String billDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String billOverdueByDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Overdue by $count days',
      one: 'Overdue by 1 day',
    );
    return '$_temp0';
  }

  @override
  String get reportPeriodAllTime => 'All time';

  @override
  String get reportPeriodThisMonth => 'This month';

  @override
  String get reportPeriodLast3Months => 'Last 3 months';

  @override
  String get reportPeriodThisYear => 'This year';

  @override
  String get reportPeriodCustomRange => 'Custom range';

  @override
  String get authSignInCancelled => 'Sign in cancelled.';

  @override
  String scaffoldGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String scaffoldItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String get statusPending => 'Pending';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusSubmitted => 'Submitted';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusOverdue => 'Overdue';

  @override
  String get txnTypeDeposit => 'Deposit';

  @override
  String get txnTypeReimbursement => 'Reimbursement';

  @override
  String get txnTypeDirectPayment => 'Direct Payment';

  @override
  String get txnTypeAdjustment => 'Adjustment';

  @override
  String get txnTypeExpense => 'Expense';

  @override
  String get txnTypeBill => 'Bill';

  @override
  String get txnTypeActivity => 'Activity';

  @override
  String get paymentSourcePersonal => 'Personal';

  @override
  String get paymentSourceCentral => 'Central Account';

  @override
  String get paymentSourcePersonalReimbursement => 'Personal (reimbursement)';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodBankTransfer => 'Bank Transfer';

  @override
  String get paymentMethodEWallet => 'e-Wallet';

  @override
  String get paymentMethodCard => 'Card';

  @override
  String get categoryRent => 'Rent';

  @override
  String get categoryUtilities => 'Utilities';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryHousehold => 'Household';

  @override
  String get categoryMaintenance => 'Maintenance';

  @override
  String get categoryInternet => 'Internet';

  @override
  String get categoryOther => 'Other';

  @override
  String get categoryAll => 'All Categories';

  @override
  String get categoryNoneAvailable => 'No categories available.';

  @override
  String get actionBack => 'Back';

  @override
  String get actionSave => 'Save';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRemove => 'Remove';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionClose => 'Close';

  @override
  String get actionDone => 'Done';

  @override
  String get actionApply => 'Apply';

  @override
  String get actionReset => 'Reset';

  @override
  String get actionClearAll => 'Clear all';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionViewAll => 'View All';

  @override
  String get actionSeeAll => 'See all';

  @override
  String get actionSeeAllActivity => 'See All Activity';

  @override
  String get actionShare => 'Share';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionCopied => 'Copied';

  @override
  String get actionYes => 'Yes';

  @override
  String get actionNo => 'No';

  @override
  String get actionPreview => 'Preview';

  @override
  String get actionTakePhoto => 'Take Photo';

  @override
  String get actionChoosePhoto => 'Choose Photo';

  @override
  String get actionChooseFromGallery => 'Choose from Gallery';

  @override
  String get actionShowPassword => 'Show password';

  @override
  String get actionHidePassword => 'Hide password';

  @override
  String get actionMarkPaid => 'Mark as Paid';

  @override
  String get actionApprove => 'Approve';

  @override
  String get actionReject => 'Reject';

  @override
  String get actionExportPdf => 'Export PDF';

  @override
  String get actionMarkAllRead => 'Mark all as read';

  @override
  String get actionGotIt => 'Got it';

  @override
  String get labelStatus => 'Status';

  @override
  String get labelCategory => 'Category';

  @override
  String get labelType => 'Type';

  @override
  String get labelPeriod => 'Period';

  @override
  String get labelFilters => 'Filters';

  @override
  String get labelPaymentMethod => 'Payment Method';

  @override
  String get labelPaymentSource => 'Payment Source';

  @override
  String get labelPaidBy => 'Paid by';

  @override
  String get labelRecordedBy => 'Recorded by';

  @override
  String get labelPerformedBy => 'Performed By';

  @override
  String get labelPurchasedBy => 'Purchased By';

  @override
  String get labelDueDate => 'Due Date';

  @override
  String get labelCreated => 'Created';

  @override
  String get labelDate => 'Date';

  @override
  String get labelPurpose => 'Purpose';

  @override
  String get labelReceiptProof => 'Receipt / Proof';

  @override
  String get labelReceiptProofRequired => 'Receipt / Proof (required)';

  @override
  String get labelMember => 'Member';

  @override
  String get labelMembers => 'Members';

  @override
  String get labelTreasurer => 'Treasurer';

  @override
  String get labelRole => 'Role';

  @override
  String get labelHouse => 'House';

  @override
  String get labelHouseName => 'House Name';

  @override
  String get labelNotSet => 'Not set';

  @override
  String get labelNoEmail => 'No email';

  @override
  String get labelNet => 'Net';

  @override
  String get labelAmount => 'Amount';

  @override
  String get labelSupport => 'Support';

  @override
  String get labelAbout => 'About';

  @override
  String get emptyNoResults => 'No results found';

  @override
  String get emptyNoActivity => 'No activity yet';

  @override
  String get emptyNoMembers => 'No members yet';

  @override
  String get emptyNoNotifications => 'No notifications yet';

  @override
  String get emptyNoExpenses => 'No expenses yet';

  @override
  String get emptyNoBills => 'No bills yet';

  @override
  String get errorFailedToLoad => 'Failed to load';

  @override
  String get errorFailedToLoadReceipt => 'Failed to load receipt';

  @override
  String get errorNetwork => 'No internet connection.';

  @override
  String get errorOffline => 'You are offline. Showing cached data.';

  @override
  String get errorPermission => 'You do not have permission to do that.';

  @override
  String get errorNotFound => 'We could not find that item.';

  @override
  String get errorAuthentication => 'Please sign in again.';

  @override
  String get errorUnexpected => 'Something went wrong. Please try again.';

  @override
  String get errorLoadFailed => 'We could not load this. Please try again.';

  @override
  String get errorSaveFailed => 'We could not save your changes. Please try again.';

  @override
  String get houseAlreadyMember => 'You are already a member of this house.';

  @override
  String get houseJoinInvalidCode => 'That invite code is not valid.';

  @override
  String get errorActionFailed => 'We could not complete that action. Please try again.';

  @override
  String get errorExpenseAlreadyReviewed => 'This expense has already been reviewed by someone else. Refresh to see its current state.';

  @override
  String get errorExpenseNotAwaitingReimbursement => 'This expense is not awaiting reimbursement. Refresh to see its current state.';

  @override
  String get errorBillAlreadyPaid => 'This bill has already been paid for that period. Refresh to see its current state.';

  @override
  String get errorRecordMissing => 'This record no longer exists. Refresh to see the current list.';

  @override
  String errorInsufficientBalance(String amount, String balance) {
    return 'Insufficient balance. This payment of $amount exceeds the Central Account balance of $balance.';
  }

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHint => 'you@example.com';

  @override
  String get authEmailRequired => 'Please enter your email';

  @override
  String get authEmailInvalid => 'Please enter a valid email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordRequired => 'Please enter your password';

  @override
  String get authCreatePasswordRequired => 'Please enter a password';

  @override
  String authPasswordMinLength(int count) {
    return 'Password must be at least $count characters';
  }

  @override
  String get authForgotPassword => 'Forgot Password?';

  @override
  String get authSignIn => 'Sign In';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get authOrContinueWith => 'or continue with';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get authNoAccountPrompt => 'Don\'t have an account?';

  @override
  String get authHaveAccountPrompt => 'Already have an account?';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authRegisterSubtitle => 'Join your house and start tracking expenses.';

  @override
  String get authFullNameLabel => 'Full Name';

  @override
  String get authNameRequired => 'Please enter your name';

  @override
  String get authConfirmPasswordLabel => 'Confirm Password';

  @override
  String get authConfirmPasswordRequired => 'Please confirm your password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get authResetPasswordTitle => 'Reset Password';

  @override
  String get authResetYourPasswordTitle => 'Reset your password';

  @override
  String get authResetInstructions => 'Enter your email and we\'ll send you a secure link to reset your password.';

  @override
  String get authSending => 'Sending...';

  @override
  String get authSendResetLink => 'Send Reset Link';

  @override
  String get authBackToSignIn => 'Back to Sign In';

  @override
  String get authEmailSentTitle => 'Email Sent!';

  @override
  String get authEmailSentBody => 'Check your inbox for the password reset link. It may take a few minutes to arrive.';

  @override
  String get authVerifyingLink => 'Verifying your reset link…';

  @override
  String get authResetLinkInvalidTitle => 'Reset link not valid';

  @override
  String get authResetLinkInvalidBody => 'This reset link is invalid or has expired.\nPlease request a new one.';

  @override
  String get authRequestNewLink => 'Request a New Link';

  @override
  String get authSetNewPasswordTitle => 'Set a new password';

  @override
  String authSetNewPasswordBody(int count) {
    return 'Enter a new password for your account. It must be at least $count characters.';
  }

  @override
  String get authNewPasswordLabel => 'New password';

  @override
  String get authNewPasswordRequired => 'Please enter a new password';

  @override
  String get authConfirmNewPasswordLabel => 'Confirm new password';

  @override
  String get authConfirmNewPasswordRequired => 'Please confirm your new password';

  @override
  String get authResetting => 'Resetting…';

  @override
  String get authPasswordUpdatedTitle => 'Password Updated!';

  @override
  String get authPasswordUpdatedBody => 'Your password has been changed. You can now sign in with your new password.';

  @override
  String get authErrorInvalidEmail => 'Invalid email address.';

  @override
  String get authErrorUserDisabled => 'This account has been disabled.';

  @override
  String get authErrorUserNotFound => 'No account found with this email.';

  @override
  String get authErrorInvalidCredentials => 'Invalid email or password.';

  @override
  String get authErrorEmailAlreadyInUse => 'An account already exists with this email.';

  @override
  String get authErrorOperationNotAllowed => 'Email/password sign-in is not enabled.';

  @override
  String get authErrorTooManyRequests => 'Too many attempts. Please try again later.';

  @override
  String get authErrorWeakPassword => 'Password is too weak.';

  @override
  String get authErrorInvalidActionCode => 'This reset link is invalid. Please request a new one.';

  @override
  String get authErrorExpiredActionCode => 'This reset link has expired. Please request a new one.';

  @override
  String get authErrorNetworkFailed => 'Network error. Please check your connection.';

  @override
  String get authErrorRequiresRecentLogin => 'Please sign in again to continue.';

  @override
  String get authErrorMissingActionCode => 'This reset link is missing its code. Please request a new one.';

  @override
  String get authErrorVerifyLinkFailed => 'We could not verify this reset link. Please request a new one.';

  @override
  String get authErrorNotConfigured => 'Firebase is not configured.';

  @override
  String get expenseFieldTitle => 'Title';

  @override
  String get expenseFieldTitleHint => 'What did you buy?';

  @override
  String get expenseFieldAmountRm => 'Amount (RM)';

  @override
  String get expenseFieldDescription => 'Description (optional)';

  @override
  String get expenseFieldDescriptionHint => 'Add more details...';

  @override
  String get expenseFieldRequired => 'Required';

  @override
  String get expenseFieldInvalidAmount => 'Enter a valid amount';

  @override
  String get expenseFieldForMonth => 'For month (optional)';

  @override
  String get expenseFieldForMonthHint => 'e.g. 2026-09';

  @override
  String get expenseCategoriesLoadError => 'Could not load categories';

  @override
  String get expensePhotoError => 'Could not take a photo. Please try again.';

  @override
  String get expenseRemoveReceiptTitle => 'Remove Receipt';

  @override
  String get expenseRemoveReceiptMessage => 'Are you sure you want to remove this receipt?';

  @override
  String get expensePreviewReceipt => 'Preview Receipt';

  @override
  String get expensePreviewProof => 'Preview Proof';

  @override
  String get expenseRemoveProofTitle => 'Remove Proof';

  @override
  String get expenseRemoveProofMessage => 'Are you sure you want to remove this proof?';

  @override
  String get expenseSubmit => 'Submit Expense';

  @override
  String get expenseSubmitting => 'Submitting...';

  @override
  String get expenseSubmitted => 'Expense submitted';

  @override
  String get expensePaymentSourceReimburse => 'Personal (reimburse me)';

  @override
  String get expensePaymentSourceReimburseInfo => 'You will be reimbursed from the Central Account after approval.';

  @override
  String get expensePaymentSourceCentralInfo => 'This will be paid directly from the Central Account.';

  @override
  String get expenseMenuTooltip => 'Menu';

  @override
  String get expenseFilterAll => 'All';

  @override
  String get expenseListLoadError => 'Could not load expenses.';

  @override
  String get expenseEmptyDescription => 'Submit an expense to get started.';

  @override
  String expenseEmptyFiltered(String status) {
    return 'No $status expenses yet.';
  }

  @override
  String get expenseUnknownMember => 'Unknown Member';

  @override
  String get depositRecordTitle => 'Record Deposit';

  @override
  String get depositSubtitle => 'Add money to the Central Account.';

  @override
  String get depositPurposeLabel => 'Purpose (optional)';

  @override
  String get depositPurposeHint => 'e.g. Monthly Rental';

  @override
  String get depositNotesLabel => 'Notes (optional)';

  @override
  String get depositNotesHint => 'e.g. Sep rent for Ahmad & Mei';

  @override
  String get depositRecorded => 'Deposit recorded';

  @override
  String get depositProofRequiredHint => 'Attach a receipt or proof above to record the deposit.';

  @override
  String get depositPurposeMonthlyRental => 'Monthly Rental';

  @override
  String get depositPurposeHouseContribution => 'House Contribution';

  @override
  String get depositPurposeGeneralTopUp => 'General Top-up';

  @override
  String get depositPurposeUtilities => 'Utilities';

  @override
  String get depositPurposeOther => 'Other';

  @override
  String get directPaymentSubtitle => 'Pay directly from the Central Account.';

  @override
  String get directPaymentTitleHint => 'What was it for?';

  @override
  String get directPaymentRecord => 'Record Payment';

  @override
  String get directPaymentRecorded => 'Payment recorded';

  @override
  String get directPaymentProofRequiredHint => 'Attach a receipt or proof above to record the payment.';

  @override
  String get houseCreateTitle => 'Create House';

  @override
  String get houseCreateHeading => 'Create Your House';

  @override
  String get houseCreateSubtitle => 'Set up your shared household account.';

  @override
  String get houseNameHint => 'e.g. Jalan Ampang Homestead';

  @override
  String get houseNameRequired => 'Please enter a house name';

  @override
  String get houseCreateTreasurerNotice => 'You will become the Treasurer of this house.';

  @override
  String get houseCreateAlreadyHave => 'Already have a house?';

  @override
  String get houseJoinWithCode => 'Join with Code';

  @override
  String get houseJoinTitle => 'Join House';

  @override
  String get houseJoinHeading => 'Enter Invite Code';

  @override
  String get houseJoinSubtitle => 'Ask your Treasurer for the invite code.';

  @override
  String get houseInviteCode => 'Invite Code';

  @override
  String get houseInviteCodeRequired => 'Please enter an invite code';

  @override
  String houseInviteCodeLength(int count) {
    return 'Code must be $count characters';
  }

  @override
  String get houseJoinNoCode => 'Don\'t have a code?';

  @override
  String get houseJoinCreateLink => 'Create a House';

  @override
  String get houseErrorNotAuthenticated => 'Not authenticated.';

  @override
  String get houseErrorNoActiveHouse => 'No active house.';

  @override
  String get houseErrorOnlyTreasurerRemove => 'Only the Treasurer can remove a member.';

  @override
  String get houseErrorCannotRemoveTreasurer => 'The Treasurer cannot be removed. Transfer ownership first.';

  @override
  String get houseErrorUnexpected => 'An unexpected error occurred.';

  @override
  String get houseErrorFirebaseNotConfigured => 'Firebase is not configured.';

  @override
  String get houseMembersLoadFailed => 'Could not load members.';

  @override
  String get houseNoMembersDescription => 'Share your invite code to add housemates.';

  @override
  String get houseThisMember => 'This member';

  @override
  String get houseRemoveMemberTitle => 'Remove Member';

  @override
  String get houseRemoveMemberTooltip => 'Remove member';

  @override
  String houseRemoveMemberBody(String name, String house) {
    return 'Remove $name from $house?\n\nThey will no longer be part of this house or be able to access its data. Their account and all past expense and transaction history will be kept.';
  }

  @override
  String houseMemberRemoved(String name) {
    return '$name removed from the house.';
  }

  @override
  String get houseTransferTitle => 'Transfer Ownership';

  @override
  String houseTransferBody(String name, String house) {
    return 'Make $name the new Treasurer of $house?\n\nYou will become a regular Member and will no longer be able to approve expenses, record deposits or manage the house until ownership is transferred back to you.';
  }

  @override
  String get houseTransferConfirm => 'Transfer';

  @override
  String houseTransferDone(String name) {
    return '$name is now the Treasurer.';
  }

  @override
  String get houseTransferSheetTitle => 'Transfer to…';

  @override
  String get houseTransferSheetSubtitle => 'Make this member the Treasurer';

  @override
  String get houseLeaveTitle => 'Leave House';

  @override
  String houseLeaveBody(String house) {
    return 'Leave $house?\n\nYou will no longer be able to view this house or submit expenses until you are invited back. Your account and all past records are kept.';
  }

  @override
  String get houseLeaveConfirm => 'Leave';

  @override
  String houseLeaveDone(String house) {
    return 'You left $house.';
  }

  @override
  String get houseYourMembership => 'Your membership';

  @override
  String get houseTreasurerOnlyMember => 'You are the Treasurer and currently the only member. Another member must join before ownership can be transferred.';

  @override
  String get houseTreasurerCanTransfer => 'You are the Treasurer. Transfer ownership to another member before you can leave this house.';

  @override
  String get houseTransferOwnership => 'Transfer ownership';

  @override
  String get houseMemberCanLeave => 'You are a Member. You can leave this house at any time; your account and past records are kept.';

  @override
  String get houseLeaveHouse => 'Leave house';

  @override
  String get houseInviteShareHint => 'Share this code with housemates to join.';

  @override
  String get houseInviteCodeCopied => 'Invite code copied!';

  @override
  String houseShareMessage(String code) {
    return 'Join my house on Rental Ledger!\n\nInvite Code: $code';
  }

  @override
  String get houseShareSubject => 'Rental Ledger Invite';

  @override
  String houseJoinedOn(String date) {
    return 'Joined $date';
  }

  @override
  String get houseMakeTreasurer => 'Make treasurer';

  @override
  String get actionMenu => 'Menu';

  @override
  String get actionSignOutConfirm => 'Are you sure you want to sign out?';

  @override
  String get reportLoadFailed => 'Could not load reports.';

  @override
  String get reportMoneyIn => 'Money In';

  @override
  String get reportMoneyOut => 'Money Out';

  @override
  String get reportCurrentBalance => 'Current Balance';

  @override
  String reportCentralBalanceAllTime(String amount) {
    return 'Central Account balance (all time): $amount';
  }

  @override
  String get reportInsights => 'Insights';

  @override
  String get reportWhereMoneyGoes => 'Where the Money Goes';

  @override
  String get reportCategoryBreakdown => 'Category Breakdown';

  @override
  String get reportMonthlyTrend => 'Monthly Trend';

  @override
  String get reportEmptyTitle => 'No reports yet';

  @override
  String get reportEmptyDescription => 'Deposits and expenses will appear here as they are recorded.';

  @override
  String get reportEmptyPeriodTitle => 'Nothing in this period';

  @override
  String get reportEmptyPeriodDescription => 'No deposits, expense claims, or reimbursements fell inside the selected period.';

  @override
  String get reportShowAllTime => 'Show all time';

  @override
  String get reportChoosePeriod => 'Choose a report period';

  @override
  String get reportHighestExpenseCategory => 'Highest Expense Category';

  @override
  String get reportLargestExpenseClaim => 'Largest Expense Claim';

  @override
  String get reportExpenseReimbursements => 'Expense Reimbursements';

  @override
  String get reportPendingReimbursements => 'Pending Reimbursements';

  @override
  String get reportAverageMonthlyExpense => 'Average Monthly Expense';

  @override
  String get reportAverageDeposit => 'Average Deposit';

  @override
  String get reportLargestDeposit => 'Largest Deposit';

  @override
  String get reportBillsPaid => 'Bills Paid';

  @override
  String get reportBillsPending => 'Bills Pending';

  @override
  String get reportMoneyOutReimbursements => 'Expense reimbursements';

  @override
  String get reportMoneyOutDirectPayments => 'Direct payments';

  @override
  String get reportMoneyOutBillPayments => 'Bill payments';

  @override
  String get reportMoneyOutAdjustments => 'Adjustments';

  @override
  String get reportMoneyOutOther => 'Other';

  @override
  String reportMoneyOutFrom(String amount) {
    return 'From $amount of Money Out';
  }

  @override
  String get reportTapSliceHint => 'Tap a slice to see details';

  @override
  String get settingsUser => 'User';

  @override
  String get settingsEditProfile => 'Edit Profile';

  @override
  String get settingsInviteCode => 'Invite Code';

  @override
  String get settingsInviteCodeCopied => 'Invite code copied';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System default';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystemHint => 'Follow your device or browser';

  @override
  String get settingsPushNotifications => 'Push Notifications';

  @override
  String get settingsNotificationsSubtitle => 'Receive alerts for expense updates';

  @override
  String get settingsPreferences => 'Preferences';

  @override
  String get settingsCurrency => 'Currency';

  @override
  String get settingsHelpCenter => 'Help Center';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsAboutLegalese => 'A household finance management app.';

  @override
  String get settingsHelpIntro => 'Track shared household expenses with ease.';

  @override
  String get settingsHelpSubmitExpenses => 'Submit Expenses';

  @override
  String get settingsHelpSubmitExpensesDesc => 'Tap + to add a new expense claim with receipt.';

  @override
  String get settingsHelpTreasurerApproval => 'Treasurer Approval';

  @override
  String get settingsHelpTreasurerApprovalDesc => 'The Treasurer reviews and approves expenses.';

  @override
  String get settingsHelpReimbursements => 'Reimbursements';

  @override
  String get settingsHelpReimbursementsDesc => 'Once approved and paid, you get reimbursed.';

  @override
  String get settingsHelpInviteHousemates => 'Invite Housemates';

  @override
  String get settingsHelpInviteHousematesDesc => 'Share your invite code from the Members screen.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileChangePhoto => 'Change Photo';

  @override
  String get profilePhotoFailed => 'Could not take a photo. Please try again.';

  @override
  String get profileDisplayName => 'Display Name';

  @override
  String get profileDisplayNameHint => 'Enter your name';

  @override
  String get profileDisplayNameEmpty => 'Display name cannot be empty.';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileHouseAndAccount => 'House & Account';

  @override
  String get profileJoined => 'Joined';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get profileUpdateFailed => 'Could not update your profile. Please try again.';

  @override
  String get profileSaving => 'Saving…';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionViewReceipt => 'View Receipt';

  @override
  String get actionPreviewReceipt => 'Preview Receipt';

  @override
  String get actionRemindTreasurer => 'Remind Treasurer';

  @override
  String get actionReminderSent => 'Reminder sent to Treasurer';

  @override
  String get billDetailsTitle => 'Bill Details';

  @override
  String get billLoadFailed => 'Could not load bill.';

  @override
  String get billNotFound => 'Bill not found.';

  @override
  String get billStatusUpcoming => 'Upcoming Bill';

  @override
  String get billRecurring => 'Recurring';

  @override
  String get billRecurringYes => 'Yes — rolls monthly';

  @override
  String get billReminderOnly => 'Reminder';

  @override
  String get billConfirmPayment => 'Confirm Payment';

  @override
  String billMarkPaidConfirm(String title) {
    return 'Mark \"$title\" as paid?';
  }

  @override
  String get billRollsToNextMonth => 'Rolls the bill to next month.';

  @override
  String get billSettles => 'Settles this bill.';

  @override
  String get billPaymentCoversMonth => 'Payment covers month';

  @override
  String get billPaymentCoversMonthHint => 'e.g. 2026-09';

  @override
  String get billProofRequired => 'A receipt or proof is required for a bill with an amount.';

  @override
  String get billTreasurerOnlyMarkPaid => 'Only the Treasurer can mark a bill as paid.';

  @override
  String get billMarkPaidFailed => 'Could not mark the bill as paid. Please try again.';

  @override
  String get billMarkedPaid => 'Bill marked as paid';

  @override
  String get billDeleteTitle => 'Delete Bill?';

  @override
  String get billDeleted => 'Bill deleted';

  @override
  String get billUpdated => 'Bill updated';

  @override
  String billDueOn(String date) {
    return 'Due $date';
  }

  @override
  String billDueDateLabel(String date) {
    return 'Due: $date';
  }

  @override
  String get depositDetailsTitle => 'Deposit Details';

  @override
  String get directPaymentDetailsTitle => 'Direct Payment Details';

  @override
  String txnByPerson(String name) {
    return 'by $name';
  }

  @override
  String get txnCoversMonth => 'Covers Month';

  @override
  String get expenseDetailsTitle => 'Expense Details';

  @override
  String get expenseLoadFailed => 'Could not load expense.';

  @override
  String get expenseNotFound => 'Expense not found.';

  @override
  String expensePurchasedByPerson(String name) {
    return 'Purchased by $name';
  }

  @override
  String get expenseReceiptUnavailable => 'Receipt unavailable';

  @override
  String expenseRejectReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get expenseDescriptionSection => 'Description';

  @override
  String get expenseTimeline => 'Timeline';

  @override
  String get expenseTreasurerActions => 'Treasurer Actions';

  @override
  String expenseMarkPaidConfirm(String title) {
    return 'Mark \"$title\" as reimbursed from the Central Account?';
  }

  @override
  String get expenseDeleteTitle => 'Delete Expense?';

  @override
  String expenseDeleteConfirm(String title) {
    return 'Delete \"$title\"? This cannot be undone.';
  }

  @override
  String get expenseDeleted => 'Expense deleted';

  @override
  String get expenseRejectTitle => 'Reject Expense';

  @override
  String expenseRejectConfirm(String title) {
    return 'Reject \"$title\"?';
  }

  @override
  String get expenseRejectReasonLabel => 'Reason (optional)';

  @override
  String get expenseRejectReasonHint => 'e.g. Receipt is blurry, please upload a clearer one.';

  @override
  String get expenseTimelineWaiting => 'Waiting...';

  @override
  String get expenseRemindOnlySubmitter => 'Only the submitter can remind the Treasurer.';

  @override
  String get expenseTreasurerNotFound => 'Could not find the Treasurer.';

  @override
  String get expensePhotoPickFailed => 'Could not pick a photo. Please try again.';

  @override
  String get expenseUpdateFailed => 'Could not update. Please try again.';

  @override
  String get expenseEditTitle => 'Edit Expense';

  @override
  String get expenseAmountRm => 'Amount (RM)';

  @override
  String get expenseDescriptionOptional => 'Description (optional)';

  @override
  String get expenseReceiptNewSelected => 'New receipt selected — will replace the current one on save.';

  @override
  String get expenseReceiptWillRemove => 'Receipt will be removed on save.';

  @override
  String get expenseReceiptCurrent => 'Current receipt attached.';

  @override
  String get expenseReceiptNone => 'No receipt attached.';

  @override
  String get expenseRemoveReceipt => 'Remove receipt';

  @override
  String get dashboardProfileLabel => 'Profile';

  @override
  String get dashboardLoadError => 'Could not load dashboard.';

  @override
  String dashboardWelcomeTitle(String appName) {
    return 'Welcome to $appName!';
  }

  @override
  String get dashboardOnboardingDescription => 'Create or join a house to start tracking expenses.';

  @override
  String get dashboardCreateHouse => 'Create a House';

  @override
  String get dashboardJoinWithCode => 'Join with Code';

  @override
  String get dashboardMoneyIn => 'Money In';

  @override
  String get dashboardMoneyOut => 'Money Out';

  @override
  String get dashboardPendingItems => 'Pending Items';

  @override
  String get dashboardPendingItemsEmpty => 'No pending items';

  @override
  String get dashboardPendingItemsEmptyDescription => 'Submitted and approved expenses will appear here.';

  @override
  String get dashboardWaitingForReimbursement => 'Approved — waiting for reimbursement';

  @override
  String get dashboardWaitingForApproval => 'Waiting for Treasurer approval';

  @override
  String get dashboardRecentActivity => 'Recent Activity';

  @override
  String get dashboardRecentActivityEmptyDescription => 'Transactions, expenses, and deposits will appear here.';

  @override
  String get commonUnknownMember => 'Unknown Member';

  @override
  String get historySearchHint => 'Search by name...';

  @override
  String get historyLoadError => 'Could not load history.';

  @override
  String get historyNoResultsHint => 'Try adjusting your search or filters.';

  @override
  String get historyEmptyDescription => 'Deposits, expenses, and bills will appear here.';

  @override
  String get historyExpenseSubmitted => 'Expense Submitted';

  @override
  String get historyExpenseApproved => 'Expense Approved';

  @override
  String get historyExpenseRejected => 'Expense Rejected';

  @override
  String get historyTypeExpensePaid => 'Expense Paid';

  @override
  String get historyBillCreated => 'Bill Created';

  @override
  String get historyBillPaid => 'Bill Paid';

  @override
  String get historyUpcomingBill => 'Upcoming Bill';

  @override
  String get statusUpcoming => 'Upcoming';

  @override
  String get billUpcomingBills => 'Upcoming Bills';

  @override
  String get billAdd => 'Add Bill';

  @override
  String get billListLoadFailed => 'Could not load bills. Pull to refresh.';

  @override
  String get billNoneUpcoming => 'No upcoming bills';

  @override
  String get billNoneUpcomingHint => 'Add recurring bills to track them here.';

  @override
  String get billEditTooltip => 'Edit bill';

  @override
  String get billDeleteTooltip => 'Delete bill';

  @override
  String get billReminderOn => 'Reminder On';

  @override
  String get billSetReminder => 'Set Reminder';

  @override
  String get billMarkPaid => 'Mark Paid';

  @override
  String get billEditTitle => 'Edit Bill';

  @override
  String get billName => 'Bill name';

  @override
  String get billAmountRmOptional => 'Amount (RM) — optional';

  @override
  String get billAmountHint => 'Leave blank for reminder only';

  @override
  String get billRepeatMonthly => 'Repeat every month';

  @override
  String get billRepeatMonthlyHint => 'Auto-create the next bill each month';

  @override
  String get billRollNextMonth => 'This will roll the bill to next month.';

  @override
  String get billWillBeMarkedPaid => 'This bill will be marked as paid.';

  @override
  String get billHistorySearchHint => 'Search by bill title...';

  @override
  String get billHistoryLoadFailed => 'Could not load bill history.';

  @override
  String get billHistoryEmpty => 'No bills yet';

  @override
  String get billHistoryEmptyDescription => 'Bills added to this house will appear here.';

  @override
  String get billHistoryMemberFilterEmpty => 'Bills name a member only when a payment was recorded against them, so this filter hides upcoming bills and bills settled without a payment record.';

  @override
  String billHistoryCoversPeriod(String period) {
    return 'Covers $period';
  }

  @override
  String billHistoryPaymentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count payments',
      one: '1 payment',
    );
    return '$_temp0';
  }

  @override
  String get notifAllMarkedRead => 'All marked as read';

  @override
  String get notifLoadFailed => 'Could not load notifications.';

  @override
  String get notifEmptyDescription => 'Updates about expenses, payments, and approvals will appear here.';

  @override
  String get timeThisWeek => 'This Week';

  @override
  String get timeEarlier => 'Earlier';

  @override
  String get navMenu => 'Menu';

  @override
  String get labelReceipt => 'Receipt';

  @override
  String get errorNoHouse => 'No house found.';

  @override
  String get errorNotSignedIn => 'Not authenticated.';

  @override
  String get errorBillCreateFailed => 'Failed to create bill.';

  @override
  String get labelTotal => 'Total';

  @override
  String get reportPdfSubtitle => 'Financial Report';

  @override
  String get reportPdfPeriod => 'Period';

  @override
  String reportPdfGeneratedOn(String date) {
    return 'Generated $date';
  }

  @override
  String get reportPdfSummary => 'Summary';

  @override
  String get reportPdfTotalExpenses => 'Total Expenses';

  @override
  String get reportPdfTotalDeposits => 'Total Deposits';

  @override
  String get reportPdfNetFlow => 'Net Flow';

  @override
  String get reportPdfMonth => 'Month';

  @override
  String get reportPdfShare => 'Share';

  @override
  String get reportPdfNoData => 'No report data for this period.';

  @override
  String get reportPdfFailed => 'Could not generate the PDF. Please try again.';
}
