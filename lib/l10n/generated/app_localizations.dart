import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ms.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ms')
  ];

  /// Section header for the language picker in Settings.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageSectionTitle;

  /// Name of the English language option in the picker.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Name of the Malay language option in the picker. Language names are written in their own language, so this is identical in both ARB files.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Melayu'**
  String get languageMalay;

  /// Bottom navigation label for the dashboard/home tab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Navigation drawer label for the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// Navigation label for the transaction history screen.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// Navigation drawer label for the bill history screen.
  ///
  /// In en, this message translates to:
  /// **'Bill History'**
  String get navBillHistory;

  /// Navigation label for the expense list screen.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get navExpenses;

  /// Navigation drawer label for the household members screen.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get navMembers;

  /// Navigation drawer label for the notifications screen.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// Navigation label for the reports screen.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// Navigation drawer label for the settings screen.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Drawer action that ends the session.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get actionSignOut;

  /// Header above the house switcher in the navigation drawer. Shipped in upper case as a styled section label; keep the target translation upper case too.
  ///
  /// In en, this message translates to:
  /// **'MY HOUSES'**
  String get drawerMyHouses;

  /// Speed-dial action for recording a payment made directly between members. This is a UI label only — the value stored on a transaction is a separate, untranslated Firestore constant.
  ///
  /// In en, this message translates to:
  /// **'Direct Payment'**
  String get actionDirectPayment;

  /// Speed-dial action for depositing into the Central Account.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get actionDeposit;

  /// Speed-dial action for submitting a new expense claim.
  ///
  /// In en, this message translates to:
  /// **'Add Expense'**
  String get actionAddExpense;

  /// Heading on the router's 404 error page.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFoundTitle;

  /// Body text on the router's 404 error page.
  ///
  /// In en, this message translates to:
  /// **'The page you are looking for does not exist.'**
  String get pageNotFoundMessage;

  /// Button on the 404 page that returns to the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get actionGoHome;

  /// Fallback shown when a detail route is opened without its payload, e.g. a stale deep link.
  ///
  /// In en, this message translates to:
  /// **'Unable to open this item.'**
  String get unableToOpenItem;

  /// Default message on the shared ErrorDisplay widget when the caller supplies none.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGenericMessage;

  /// Retry button on the shared ErrorDisplay widget.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get actionTryAgain;

  /// Default label on the shared BalanceCard when the caller supplies none.
  ///
  /// In en, this message translates to:
  /// **'Central Account Balance'**
  String get centralAccountBalance;

  /// Default title on the shared full-screen ReceiptViewer when the caller supplies none.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// Product tagline shown under the app name on the shared AppLogo. The app name itself is a product name and is never translated.
  ///
  /// In en, this message translates to:
  /// **'Your household finances, simplified'**
  String get appTagline;

  /// Relative timestamp for something that happened less than a minute ago.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// Relative timestamp in minutes. The 'm' is the shipped abbreviation; Malay spells the unit out.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String timeMinutesAgo(int count);

  /// Relative timestamp in hours, for anything between one hour and one day old.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String timeHoursAgo(int count);

  /// Relative timestamp for exactly one day ago. Also the label of the Yesterday date-filter preset — same word, same meaning.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get timeYesterday;

  /// Relative timestamp in days, for anything two to six days old.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String timeDaysAgo(int count);

  /// The current day. Used both as a relative timestamp and as the label of the Today date-filter preset.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get timeToday;

  /// The day after today, shown on a bill that falls due tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get timeTomorrow;

  /// Date-filter preset covering today and the six days before it.
  ///
  /// In en, this message translates to:
  /// **'Last 7 Days'**
  String get periodLast7Days;

  /// Date-filter preset covering today and the twenty-nine days before it.
  ///
  /// In en, this message translates to:
  /// **'Last 30 Days'**
  String get periodLast30Days;

  /// Date-filter preset covering today and the eighty-nine days before it.
  ///
  /// In en, this message translates to:
  /// **'Last 90 Days'**
  String get periodLast90Days;

  /// Date-filter preset covering the current calendar month.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get periodThisMonth;

  /// Date-filter preset covering the previous calendar month.
  ///
  /// In en, this message translates to:
  /// **'Last Month'**
  String get periodLastMonth;

  /// Label for 'no date filtering' on the active-filter chip.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get periodAll;

  /// Label for an explicit start/end date range on the active-filter chip.
  ///
  /// In en, this message translates to:
  /// **'Custom Range'**
  String get periodCustomRange;

  /// Countdown label on a bill that falls due today.
  ///
  /// In en, this message translates to:
  /// **'Due Today'**
  String get billDueToday;

  /// Countdown label on a bill that is still in the future. Malay has no plural form, so its translation uses a single `other` branch.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day left} other{{count} days left}}'**
  String billDaysLeft(int count);

  /// Countdown label on a bill whose due date has passed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Overdue by 1 day} other{Overdue by {count} days}}'**
  String billOverdueByDays(int count);

  /// Reports date filter covering the whole ledger, with no lower bound.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get reportPeriodAllTime;

  /// Reports date filter covering the current calendar month. Sentence case, unlike the History chip's periodThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get reportPeriodThisMonth;

  /// Reports date filter covering the current month and the two before it.
  ///
  /// In en, this message translates to:
  /// **'Last 3 months'**
  String get reportPeriodLast3Months;

  /// Reports date filter covering the current calendar year.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get reportPeriodThisYear;

  /// Reports date filter for an explicit start/end range. Sentence case, unlike the History chip's periodCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get reportPeriodCustomRange;

  /// Shown when the user dismisses the Google sign-in sheet. NOTE: the code never compares against this text — the cancellation is detected by the stable `cancelled` failure code (see AuthErrorCodes), so translating it cannot break the flow.
  ///
  /// In en, this message translates to:
  /// **'Sign in cancelled.'**
  String get authSignInCancelled;

  /// SCAFFOLD ONLY — proves placeholder interpolation generates and resolves. Delete once the real string migration lands; the `scaffold` prefix marks keys that are not part of the shipped UI.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String scaffoldGreeting(String name);

  /// SCAFFOLD ONLY — proves ICU pluralisation generates and resolves per locale. Delete once the real string migration lands.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No items} =1{1 item} other{{count} items}}'**
  String scaffoldItemCount(int count);

  /// Expense or bill awaiting Treasurer review.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// Expense approved by the Treasurer and awaiting payment.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get statusApproved;

  /// Expense declined by the Treasurer.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// Expense reimbursed, or bill settled.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get statusPaid;

  /// Expense submitted by a member and awaiting review.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get statusSubmitted;

  /// Generic finished state for a record.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// A bill whose due date has passed.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get statusOverdue;

  /// Money paid into the central house account.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get txnTypeDeposit;

  /// Money paid out to reimburse a member.
  ///
  /// In en, this message translates to:
  /// **'Reimbursement'**
  String get txnTypeReimbursement;

  /// Money paid straight out of the central account.
  ///
  /// In en, this message translates to:
  /// **'Direct Payment'**
  String get txnTypeDirectPayment;

  /// Manual correction to the central account balance.
  ///
  /// In en, this message translates to:
  /// **'Adjustment'**
  String get txnTypeAdjustment;

  /// Generic label for an expense record.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get txnTypeExpense;

  /// Generic label for a recurring or one-off bill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get txnTypeBill;

  /// Fallback title when an activity item has no description.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get txnTypeActivity;

  /// The member paid out of their own pocket and is owed a reimbursement.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get paymentSourcePersonal;

  /// The money came out of the shared house account.
  ///
  /// In en, this message translates to:
  /// **'Central Account'**
  String get paymentSourceCentral;

  /// Expanded personal-source label on the expense detail page.
  ///
  /// In en, this message translates to:
  /// **'Personal (reimbursement)'**
  String get paymentSourcePersonalReimbursement;

  /// Display label for the stored payment method "Cash".
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// Display label for the stored payment method "Bank Transfer".
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get paymentMethodBankTransfer;

  /// Display label for the stored payment method "e-Wallet".
  ///
  /// In en, this message translates to:
  /// **'e-Wallet'**
  String get paymentMethodEWallet;

  /// Display label for the stored payment method "Card".
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get paymentMethodCard;

  /// Display label for the default "Rent" category.
  ///
  /// In en, this message translates to:
  /// **'Rent'**
  String get categoryRent;

  /// Display label for the default "Utilities" category.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get categoryUtilities;

  /// Display label for the default "Food" category.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get categoryFood;

  /// Display label for the default "Household" category.
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get categoryHousehold;

  /// Display label for the default "Maintenance" category.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get categoryMaintenance;

  /// Display label for the default "Internet" category.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get categoryInternet;

  /// Display label for the default "Other" category.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// Filter chip that clears the category filter.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get categoryAll;

  /// Shown when a house has no categories to pick from.
  ///
  /// In en, this message translates to:
  /// **'No categories available.'**
  String get categoryNoneAvailable;

  /// App bar back button.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// Save button.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// Dismiss a dialog without applying changes.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// Delete button.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// Remove an attachment, member or item.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// Edit button.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// Close a sheet or dialog.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// Finish a step or dialog.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// Apply the selected filters.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// Clear every filter back to its default.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get actionReset;

  /// Clear every active filter or search term.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get actionClearAll;

  /// Add button.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// Open the full list behind a dashboard section.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get actionViewAll;

  /// Open the full list behind a dashboard section.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get actionSeeAll;

  /// Open the full history timeline from the dashboard.
  ///
  /// In en, this message translates to:
  /// **'See All Activity'**
  String get actionSeeAllActivity;

  /// Share the house invite code.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// Copy the house invite code to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// Confirmation after copying to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get actionCopied;

  /// Affirmative answer in a confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get actionYes;

  /// Negative answer in a confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get actionNo;

  /// Open an image full screen.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get actionPreview;

  /// Capture a photo with the camera.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get actionTakePhoto;

  /// Pick a photo from the device.
  ///
  /// In en, this message translates to:
  /// **'Choose Photo'**
  String get actionChoosePhoto;

  /// Pick a profile photo from the device.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get actionChooseFromGallery;

  /// Reveal the password field contents.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get actionShowPassword;

  /// Mask the password field contents.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get actionHidePassword;

  /// Settle an approved expense or a bill.
  ///
  /// In en, this message translates to:
  /// **'Mark as Paid'**
  String get actionMarkPaid;

  /// Treasurer approves an expense.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get actionApprove;

  /// Treasurer rejects an expense.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get actionReject;

  /// Export the current report as a PDF file.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get actionExportPdf;

  /// Mark every notification as read.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get actionMarkAllRead;

  /// Dismiss an informational dialog.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get actionGotIt;

  /// Status field label.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get labelStatus;

  /// Category field label.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get labelCategory;

  /// Transaction type field label.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get labelType;

  /// Period covered by a payment.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get labelPeriod;

  /// Filter sheet title.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get labelFilters;

  /// How the money moved.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get labelPaymentMethod;

  /// Whether the money was personal or central.
  ///
  /// In en, this message translates to:
  /// **'Payment Source'**
  String get labelPaymentSource;

  /// Who physically handed over the money.
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get labelPaidBy;

  /// Who entered the record.
  ///
  /// In en, this message translates to:
  /// **'Recorded by'**
  String get labelRecordedBy;

  /// Who carried out the transaction.
  ///
  /// In en, this message translates to:
  /// **'Performed By'**
  String get labelPerformedBy;

  /// Who bought the item.
  ///
  /// In en, this message translates to:
  /// **'Purchased By'**
  String get labelPurchasedBy;

  /// Date a bill must be paid by.
  ///
  /// In en, this message translates to:
  /// **'Due Date'**
  String get labelDueDate;

  /// Date a record was created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get labelCreated;

  /// Date field label.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get labelDate;

  /// Why the money moved.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get labelPurpose;

  /// Receipt or proof of payment attachment.
  ///
  /// In en, this message translates to:
  /// **'Receipt / Proof'**
  String get labelReceiptProof;

  /// Attachment field that must be filled before submitting.
  ///
  /// In en, this message translates to:
  /// **'Receipt / Proof (required)'**
  String get labelReceiptProofRequired;

  /// A single house member.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get labelMember;

  /// The house member list.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get labelMembers;

  /// House member who manages the account.
  ///
  /// In en, this message translates to:
  /// **'Treasurer'**
  String get labelTreasurer;

  /// The part a member plays in the house.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get labelRole;

  /// The house a member belongs to.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get labelHouse;

  /// Name of the house.
  ///
  /// In en, this message translates to:
  /// **'House Name'**
  String get labelHouseName;

  /// Placeholder when a profile field is empty.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get labelNotSet;

  /// Placeholder when an account has no email address.
  ///
  /// In en, this message translates to:
  /// **'No email'**
  String get labelNoEmail;

  /// Net money in minus money out.
  ///
  /// In en, this message translates to:
  /// **'Net'**
  String get labelNet;

  /// A money amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get labelAmount;

  /// Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get labelSupport;

  /// Settings section heading.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get labelAbout;

  /// Shown when a search or filter matches nothing.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get emptyNoResults;

  /// Shown on an empty history timeline.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get emptyNoActivity;

  /// Shown on an empty member list.
  ///
  /// In en, this message translates to:
  /// **'No members yet'**
  String get emptyNoMembers;

  /// Shown on an empty notification list.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get emptyNoNotifications;

  /// Shown on an empty expense list.
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get emptyNoExpenses;

  /// Shown on an empty bill list.
  ///
  /// In en, this message translates to:
  /// **'No bills yet'**
  String get emptyNoBills;

  /// Generic load failure heading.
  ///
  /// In en, this message translates to:
  /// **'Failed to load'**
  String get errorFailedToLoad;

  /// Shown when a receipt image cannot be displayed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load receipt'**
  String get errorFailedToLoadReceipt;

  /// Shown when a request fails because the device is offline.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get errorNetwork;

  /// Shown when the app falls back to cached data.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Showing cached data.'**
  String get errorOffline;

  /// Shown when an action is refused by the security rules.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to do that.'**
  String get errorPermission;

  /// Shown when the requested record no longer exists.
  ///
  /// In en, this message translates to:
  /// **'We could not find that item.'**
  String get errorNotFound;

  /// Shown when the session is no longer valid.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get errorAuthentication;

  /// Generic fallback for an error with no more specific message.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorUnexpected;

  /// Shown when a list or page fails to load.
  ///
  /// In en, this message translates to:
  /// **'We could not load this. Please try again.'**
  String get errorLoadFailed;

  /// Shown when a write or update fails.
  ///
  /// In en, this message translates to:
  /// **'We could not save your changes. Please try again.'**
  String get errorSaveFailed;

  /// Shown when a join code resolves to a house the user already belongs to.
  ///
  /// In en, this message translates to:
  /// **'You are already a member of this house.'**
  String get houseAlreadyMember;

  /// Shown when a join code matches no house.
  ///
  /// In en, this message translates to:
  /// **'That invite code is not valid.'**
  String get houseJoinInvalidCode;

  /// Generic message for a refused financial transition (approve, reject, mark paid).
  ///
  /// In en, this message translates to:
  /// **'We could not complete that action. Please try again.'**
  String get errorActionFailed;

  /// Shown when an approve or reject loses a race against another Treasurer.
  ///
  /// In en, this message translates to:
  /// **'This expense has already been reviewed by someone else. Refresh to see its current state.'**
  String get errorExpenseAlreadyReviewed;

  /// Shown when Mark Paid is used on an expense that is not in the approved state.
  ///
  /// In en, this message translates to:
  /// **'This expense is not awaiting reimbursement. Refresh to see its current state.'**
  String get errorExpenseNotAwaitingReimbursement;

  /// Shown when a bill payment is submitted twice for the same due date.
  ///
  /// In en, this message translates to:
  /// **'This bill has already been paid for that period. Refresh to see its current state.'**
  String get errorBillAlreadyPaid;

  /// Shown when the record a user is acting on was deleted in another session.
  ///
  /// In en, this message translates to:
  /// **'This record no longer exists. Refresh to see the current list.'**
  String get errorRecordMissing;

  /// Refusal shown when an outflow would overdraw the Central Account. Both figures are formatted for the current locale.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance. This payment of {amount} exceeds the Central Account balance of {balance}.'**
  String errorInsufficientBalance(String amount, String balance);

  /// Label of the email field on the sign-in, register and forgot-password forms.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// Greyed-out example address inside the forgot-password email field.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get authEmailHint;

  /// Validation error when the email field is left empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get authEmailRequired;

  /// Validation error when the email field has no @ sign.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get authEmailInvalid;

  /// Label of the password field on the sign-in and register forms.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// Validation error when the sign-in password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get authPasswordRequired;

  /// Validation error when the register password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get authCreatePasswordRequired;

  /// Validation error when a password is shorter than the minimum length.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least {count} characters'**
  String authPasswordMinLength(int count);

  /// Link on the sign-in page that opens the password-reset request page.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get authForgotPassword;

  /// Primary button on the sign-in page, and the link back to it from the register page.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get authSignIn;

  /// Link on the sign-in page that opens the registration page.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// Divider caption above the social sign-in buttons.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get authOrContinueWith;

  /// Google sign-in button label.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// Apple sign-in button label (iOS/macOS only).
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authContinueWithApple;

  /// Caption before the Sign Up link on the sign-in page.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccountPrompt;

  /// Caption before the Sign In link on the register page.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHaveAccountPrompt;

  /// Heading and primary button label on the register page.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// Sub-heading on the register page.
  ///
  /// In en, this message translates to:
  /// **'Join your house and start tracking expenses.'**
  String get authRegisterSubtitle;

  /// Label of the name field on the register form.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get authFullNameLabel;

  /// Validation error when the register name field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get authNameRequired;

  /// Label of the confirm-password field on the register form.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPasswordLabel;

  /// Validation error when the register confirm-password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get authConfirmPasswordRequired;

  /// Validation error when the two password fields differ.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDoNotMatch;

  /// App bar title on the forgot-password and reset-password pages, and the reset form's submit button.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authResetPasswordTitle;

  /// Heading on the forgot-password form.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get authResetYourPasswordTitle;

  /// Body text under the forgot-password heading.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a secure link to reset your password.'**
  String get authResetInstructions;

  /// Send-reset-link button label while the email is being sent.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get authSending;

  /// Send-reset-link button label at rest.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get authSendResetLink;

  /// Link back to the sign-in page from the password-reset pages.
  ///
  /// In en, this message translates to:
  /// **'Back to Sign In'**
  String get authBackToSignIn;

  /// Success heading after the reset email is sent.
  ///
  /// In en, this message translates to:
  /// **'Email Sent!'**
  String get authEmailSentTitle;

  /// Success body text after the reset email is sent.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox for the password reset link. It may take a few minutes to arrive.'**
  String get authEmailSentBody;

  /// Spinner caption while the Firebase action code is validated.
  ///
  /// In en, this message translates to:
  /// **'Verifying your reset link…'**
  String get authVerifyingLink;

  /// Heading shown when the reset link is missing, invalid or expired.
  ///
  /// In en, this message translates to:
  /// **'Reset link not valid'**
  String get authResetLinkInvalidTitle;

  /// Body shown when the reset link is invalid or expired and no more specific reason is available.
  ///
  /// In en, this message translates to:
  /// **'This reset link is invalid or has expired.\nPlease request a new one.'**
  String get authResetLinkInvalidBody;

  /// Button on the invalid-reset-link state that opens the forgot-password page.
  ///
  /// In en, this message translates to:
  /// **'Request a New Link'**
  String get authRequestNewLink;

  /// Heading on the new-password form of the reset page.
  ///
  /// In en, this message translates to:
  /// **'Set a new password'**
  String get authSetNewPasswordTitle;

  /// Body text above the new-password form, stating the minimum length.
  ///
  /// In en, this message translates to:
  /// **'Enter a new password for your account. It must be at least {count} characters.'**
  String authSetNewPasswordBody(int count);

  /// Label of the new-password field on the reset form.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPasswordLabel;

  /// Validation error when the new-password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a new password'**
  String get authNewPasswordRequired;

  /// Label of the confirm field on the reset form.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get authConfirmNewPasswordLabel;

  /// Validation error when the reset confirm-password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your new password'**
  String get authConfirmNewPasswordRequired;

  /// Submit button label while the new password is being saved.
  ///
  /// In en, this message translates to:
  /// **'Resetting…'**
  String get authResetting;

  /// Success heading after the password has been changed.
  ///
  /// In en, this message translates to:
  /// **'Password Updated!'**
  String get authPasswordUpdatedTitle;

  /// Success body text after the password has been changed.
  ///
  /// In en, this message translates to:
  /// **'Your password has been changed. You can now sign in with your new password.'**
  String get authPasswordUpdatedBody;

  /// Sign-in/register error for Firebase code invalid-email.
  ///
  /// In en, this message translates to:
  /// **'Invalid email address.'**
  String get authErrorInvalidEmail;

  /// Sign-in error for Firebase code user-disabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled.'**
  String get authErrorUserDisabled;

  /// Sign-in error for Firebase code user-not-found.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email.'**
  String get authErrorUserNotFound;

  /// Sign-in error for the wrong-password and invalid-credential codes.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get authErrorInvalidCredentials;

  /// Registration error for Firebase code email-already-in-use.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with this email.'**
  String get authErrorEmailAlreadyInUse;

  /// Error for Firebase code operation-not-allowed.
  ///
  /// In en, this message translates to:
  /// **'Email/password sign-in is not enabled.'**
  String get authErrorOperationNotAllowed;

  /// Error for Firebase code too-many-requests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later.'**
  String get authErrorTooManyRequests;

  /// Registration/reset error for Firebase code weak-password.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak.'**
  String get authErrorWeakPassword;

  /// Reset error for Firebase code invalid-action-code.
  ///
  /// In en, this message translates to:
  /// **'This reset link is invalid. Please request a new one.'**
  String get authErrorInvalidActionCode;

  /// Reset error for Firebase code expired-action-code.
  ///
  /// In en, this message translates to:
  /// **'This reset link has expired. Please request a new one.'**
  String get authErrorExpiredActionCode;

  /// Error for Firebase code network-request-failed.
  ///
  /// In en, this message translates to:
  /// **'Network error. Please check your connection.'**
  String get authErrorNetworkFailed;

  /// Error for Firebase code requires-recent-login.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again to continue.'**
  String get authErrorRequiresRecentLogin;

  /// Reset page opened without an action code in the link.
  ///
  /// In en, this message translates to:
  /// **'This reset link is missing its code. Please request a new one.'**
  String get authErrorMissingActionCode;

  /// Unexpected failure while validating the reset action code.
  ///
  /// In en, this message translates to:
  /// **'We could not verify this reset link. Please request a new one.'**
  String get authErrorVerifyLinkFailed;

  /// Shown when the app runs without a Firebase configuration, so auth cannot work.
  ///
  /// In en, this message translates to:
  /// **'Firebase is not configured.'**
  String get authErrorNotConfigured;

  /// Label of the expense-title field on Add Expense and Direct Payment.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get expenseFieldTitle;

  /// Hint inside the title field on Add Expense.
  ///
  /// In en, this message translates to:
  /// **'What did you buy?'**
  String get expenseFieldTitleHint;

  /// Label of the amount field. The currency code RM is a currency code and is never translated.
  ///
  /// In en, this message translates to:
  /// **'Amount (RM)'**
  String get expenseFieldAmountRm;

  /// Label of the optional description field on Add Expense.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get expenseFieldDescription;

  /// Hint inside the optional description field on Add Expense.
  ///
  /// In en, this message translates to:
  /// **'Add more details...'**
  String get expenseFieldDescriptionHint;

  /// Validation error under an empty required field.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get expenseFieldRequired;

  /// Validation error when the amount is not a positive number.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get expenseFieldInvalidAmount;

  /// Label of the optional month/period field on Deposit and Direct Payment.
  ///
  /// In en, this message translates to:
  /// **'For month (optional)'**
  String get expenseFieldForMonth;

  /// Hint inside the optional month/period field, showing the expected year-month format. The example digits stay the same in both locales.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2026-09'**
  String get expenseFieldForMonthHint;

  /// Shown in place of the category picker when the category list fails to load.
  ///
  /// In en, this message translates to:
  /// **'Could not load categories'**
  String get expenseCategoriesLoadError;

  /// Error snackbar when the camera or gallery picker throws.
  ///
  /// In en, this message translates to:
  /// **'Could not take a photo. Please try again.'**
  String get expensePhotoError;

  /// Title of the dialog that confirms removing an attached receipt on Add Expense.
  ///
  /// In en, this message translates to:
  /// **'Remove Receipt'**
  String get expenseRemoveReceiptTitle;

  /// Body of the dialog that confirms removing an attached receipt on Add Expense.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this receipt?'**
  String get expenseRemoveReceiptMessage;

  /// Button that opens the attached receipt full screen on Add Expense.
  ///
  /// In en, this message translates to:
  /// **'Preview Receipt'**
  String get expensePreviewReceipt;

  /// Button that opens the attached proof image full screen in the shared ProofPicker.
  ///
  /// In en, this message translates to:
  /// **'Preview Proof'**
  String get expensePreviewProof;

  /// Title of the dialog that confirms removing an attached proof image in the shared ProofPicker.
  ///
  /// In en, this message translates to:
  /// **'Remove Proof'**
  String get expenseRemoveProofTitle;

  /// Body of the dialog that confirms removing an attached proof image in the shared ProofPicker.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this proof?'**
  String get expenseRemoveProofMessage;

  /// Primary button that submits a new expense claim.
  ///
  /// In en, this message translates to:
  /// **'Submit Expense'**
  String get expenseSubmit;

  /// Label on the submit button while the expense claim is being written.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get expenseSubmitting;

  /// Success snackbar after an expense claim is submitted.
  ///
  /// In en, this message translates to:
  /// **'Expense submitted'**
  String get expenseSubmitted;

  /// Payment-source choice meaning the member paid out of their own pocket and wants reimbursing. This is a UI label only — the stored value is the separate, untranslated constant `personal`.
  ///
  /// In en, this message translates to:
  /// **'Personal (reimburse me)'**
  String get expensePaymentSourceReimburse;

  /// Info banner under the payment-source chips when the personal source is selected.
  ///
  /// In en, this message translates to:
  /// **'You will be reimbursed from the Central Account after approval.'**
  String get expensePaymentSourceReimburseInfo;

  /// Info banner under the payment-source chips when the central source is selected.
  ///
  /// In en, this message translates to:
  /// **'This will be paid directly from the Central Account.'**
  String get expensePaymentSourceCentralInfo;

  /// Tooltip on the Expenses app-bar button that opens the navigation drawer. "Menu" is the ordinary Malay word, so the two locales are identical by design.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get expenseMenuTooltip;

  /// The status filter tab that clears the status filter on the expense list.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get expenseFilterAll;

  /// Fallback error on the expense list when the failure carries no message of its own.
  ///
  /// In en, this message translates to:
  /// **'Could not load expenses.'**
  String get expenseListLoadError;

  /// Body of the empty state on the expense list when no status filter is active.
  ///
  /// In en, this message translates to:
  /// **'Submit an expense to get started.'**
  String get expenseEmptyDescription;

  /// Body of the empty state on the expense list while a status filter is active. The {status} placeholder carries an already-localized status label.
  ///
  /// In en, this message translates to:
  /// **'No {status} expenses yet.'**
  String expenseEmptyFiltered(String status);

  /// Fallback shown in place of a purchaser's name when it cannot be resolved. Never a real member name.
  ///
  /// In en, this message translates to:
  /// **'Unknown Member'**
  String get expenseUnknownMember;

  /// Title of the Record Deposit screen, and the label of its submit button.
  ///
  /// In en, this message translates to:
  /// **'Record Deposit'**
  String get depositRecordTitle;

  /// Explanatory line under the icon on the Record Deposit screen.
  ///
  /// In en, this message translates to:
  /// **'Add money to the Central Account.'**
  String get depositSubtitle;

  /// Label of the optional purpose dropdown on the Record Deposit screen.
  ///
  /// In en, this message translates to:
  /// **'Purpose (optional)'**
  String get depositPurposeLabel;

  /// Hint inside the optional purpose dropdown; it names one of the seeded purposes, so it matches that purpose's localized label.
  ///
  /// In en, this message translates to:
  /// **'e.g. Monthly Rental'**
  String get depositPurposeHint;

  /// Label of the optional notes field on the Record Deposit screen.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get depositNotesLabel;

  /// Hint inside the optional notes field. The sample member names are illustrative user data and are left as-is in both locales.
  ///
  /// In en, this message translates to:
  /// **'e.g. Sep rent for Ahmad & Mei'**
  String get depositNotesHint;

  /// Success snackbar after a deposit is recorded.
  ///
  /// In en, this message translates to:
  /// **'Deposit recorded'**
  String get depositRecorded;

  /// Shown under the disabled submit button on the Record Deposit screen until a proof image is attached.
  ///
  /// In en, this message translates to:
  /// **'Attach a receipt or proof above to record the deposit.'**
  String get depositProofRequiredHint;

  /// Display label for the stored deposit purpose "Monthly Rental". The stored value itself is never translated.
  ///
  /// In en, this message translates to:
  /// **'Monthly Rental'**
  String get depositPurposeMonthlyRental;

  /// Display label for the stored deposit purpose "House Contribution". The stored value itself is never translated.
  ///
  /// In en, this message translates to:
  /// **'House Contribution'**
  String get depositPurposeHouseContribution;

  /// Display label for the stored deposit purpose "General Top-up". The stored value itself is never translated.
  ///
  /// In en, this message translates to:
  /// **'General Top-up'**
  String get depositPurposeGeneralTopUp;

  /// Display label for the stored deposit purpose "Utilities". The stored value itself is never translated.
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get depositPurposeUtilities;

  /// Display label for the stored deposit purpose "Other". The stored value itself is never translated.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get depositPurposeOther;

  /// Explanatory line under the icon on the Direct Payment screen.
  ///
  /// In en, this message translates to:
  /// **'Pay directly from the Central Account.'**
  String get directPaymentSubtitle;

  /// Hint inside the title field on the Direct Payment screen.
  ///
  /// In en, this message translates to:
  /// **'What was it for?'**
  String get directPaymentTitleHint;

  /// Primary button that records a direct payment.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get directPaymentRecord;

  /// Success snackbar after a direct payment is recorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get directPaymentRecorded;

  /// Shown under the disabled submit button on the Direct Payment screen until a proof image is attached.
  ///
  /// In en, this message translates to:
  /// **'Attach a receipt or proof above to record the payment.'**
  String get directPaymentProofRequiredHint;

  /// App bar title of the Create House onboarding page, and the label of its submit button.
  ///
  /// In en, this message translates to:
  /// **'Create House'**
  String get houseCreateTitle;

  /// Large heading above the Create House form.
  ///
  /// In en, this message translates to:
  /// **'Create Your House'**
  String get houseCreateHeading;

  /// Supporting line under the Create House heading.
  ///
  /// In en, this message translates to:
  /// **'Set up your shared household account.'**
  String get houseCreateSubtitle;

  /// Placeholder example inside the House Name field. An illustrative sample only — never a real house name.
  ///
  /// In en, this message translates to:
  /// **'e.g. Jalan Ampang Homestead'**
  String get houseNameHint;

  /// Validation error under the House Name field when it is left empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a house name'**
  String get houseNameRequired;

  /// Informational note on the Create House form explaining the creator's role.
  ///
  /// In en, this message translates to:
  /// **'You will become the Treasurer of this house.'**
  String get houseCreateTreasurerNotice;

  /// Lead-in text next to the link that opens the Join House page.
  ///
  /// In en, this message translates to:
  /// **'Already have a house?'**
  String get houseCreateAlreadyHave;

  /// Link on the Create House page that opens the Join House page.
  ///
  /// In en, this message translates to:
  /// **'Join with Code'**
  String get houseJoinWithCode;

  /// App bar title of the Join House onboarding page, and the label of its submit button.
  ///
  /// In en, this message translates to:
  /// **'Join House'**
  String get houseJoinTitle;

  /// Large heading above the Join House invite-code field.
  ///
  /// In en, this message translates to:
  /// **'Enter Invite Code'**
  String get houseJoinHeading;

  /// Supporting line under the Join House heading.
  ///
  /// In en, this message translates to:
  /// **'Ask your Treasurer for the invite code.'**
  String get houseJoinSubtitle;

  /// Field label on the Join House page, and the heading of the invite-code card on the member list. The code value itself is user data and is never translated.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get houseInviteCode;

  /// Validation error when the invite-code field is left empty.
  ///
  /// In en, this message translates to:
  /// **'Please enter an invite code'**
  String get houseInviteCodeRequired;

  /// Validation error when the invite code is shorter than the required length.
  ///
  /// In en, this message translates to:
  /// **'Code must be {count} characters'**
  String houseInviteCodeLength(int count);

  /// Lead-in text next to the link that opens the Create House page.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have a code?'**
  String get houseJoinNoCode;

  /// Link on the Join House page that opens the Create House page.
  ///
  /// In en, this message translates to:
  /// **'Create a House'**
  String get houseJoinCreateLink;

  /// SnackBar shown when a house action runs without a signed-in user.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated.'**
  String get houseErrorNotAuthenticated;

  /// SnackBar shown when a house action runs with no active house selected.
  ///
  /// In en, this message translates to:
  /// **'No active house.'**
  String get houseErrorNoActiveHouse;

  /// SnackBar shown when a non-Treasurer attempts to remove a member.
  ///
  /// In en, this message translates to:
  /// **'Only the Treasurer can remove a member.'**
  String get houseErrorOnlyTreasurerRemove;

  /// SnackBar shown when a Treasurer tries to remove themselves instead of transferring ownership.
  ///
  /// In en, this message translates to:
  /// **'The Treasurer cannot be removed. Transfer ownership first.'**
  String get houseErrorCannotRemoveTreasurer;

  /// Fallback SnackBar for an unclassified house-action failure.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get houseErrorUnexpected;

  /// SnackBar shown when a house action runs while Firebase failed to initialise.
  ///
  /// In en, this message translates to:
  /// **'Firebase is not configured.'**
  String get houseErrorFirebaseNotConfigured;

  /// Error state on the member list when the members could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Could not load members.'**
  String get houseMembersLoadFailed;

  /// Supporting text under the empty member list heading.
  ///
  /// In en, this message translates to:
  /// **'Share your invite code to add housemates.'**
  String get houseNoMembersDescription;

  /// Placeholder used in member dialogs when a member has neither a display name nor an email address.
  ///
  /// In en, this message translates to:
  /// **'This member'**
  String get houseThisMember;

  /// Title of the confirm dialog for removing a member from the house.
  ///
  /// In en, this message translates to:
  /// **'Remove Member'**
  String get houseRemoveMemberTitle;

  /// Tooltip on the remove icon in a member tile's trailing actions.
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get houseRemoveMemberTooltip;

  /// Body of the confirm dialog for removing a member. {name} is the member's name and {house} the house name — both user data, inserted verbatim.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from {house}?\n\nThey will no longer be part of this house or be able to access its data. Their account and all past expense and transaction history will be kept.'**
  String houseRemoveMemberBody(String name, String house);

  /// Success SnackBar after a member is removed. {name} is user data.
  ///
  /// In en, this message translates to:
  /// **'{name} removed from the house.'**
  String houseMemberRemoved(String name);

  /// Title of the confirm dialog for handing the Treasurer role to another member.
  ///
  /// In en, this message translates to:
  /// **'Transfer Ownership'**
  String get houseTransferTitle;

  /// Body of the transfer-ownership confirm dialog. {name} and {house} are user data.
  ///
  /// In en, this message translates to:
  /// **'Make {name} the new Treasurer of {house}?\n\nYou will become a regular Member and will no longer be able to approve expenses, record deposits or manage the house until ownership is transferred back to you.'**
  String houseTransferBody(String name, String house);

  /// Confirming button in the transfer-ownership dialog.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get houseTransferConfirm;

  /// Success SnackBar after ownership is transferred. {name} is user data.
  ///
  /// In en, this message translates to:
  /// **'{name} is now the Treasurer.'**
  String houseTransferDone(String name);

  /// Title of the bottom sheet that lists the members ownership can be transferred to.
  ///
  /// In en, this message translates to:
  /// **'Transfer to…'**
  String get houseTransferSheetTitle;

  /// Subtitle on each row of the transfer-target bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'Make this member the Treasurer'**
  String get houseTransferSheetSubtitle;

  /// Title of the confirm dialog for leaving the house.
  ///
  /// In en, this message translates to:
  /// **'Leave House'**
  String get houseLeaveTitle;

  /// Body of the confirm dialog for leaving the house. {house} is user data.
  ///
  /// In en, this message translates to:
  /// **'Leave {house}?\n\nYou will no longer be able to view this house or submit expenses until you are invited back. Your account and all past records are kept.'**
  String houseLeaveBody(String house);

  /// Confirming button in the leave-house dialog.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get houseLeaveConfirm;

  /// Success SnackBar after leaving the house. {house} is user data.
  ///
  /// In en, this message translates to:
  /// **'You left {house}.'**
  String houseLeaveDone(String house);

  /// Heading of the card describing the viewer's own membership in the house.
  ///
  /// In en, this message translates to:
  /// **'Your membership'**
  String get houseYourMembership;

  /// Membership-card explanation for a Treasurer who is the only member, so ownership cannot be transferred yet.
  ///
  /// In en, this message translates to:
  /// **'You are the Treasurer and currently the only member. Another member must join before ownership can be transferred.'**
  String get houseTreasurerOnlyMember;

  /// Membership-card explanation for a Treasurer who still has to transfer ownership before leaving.
  ///
  /// In en, this message translates to:
  /// **'You are the Treasurer. Transfer ownership to another member before you can leave this house.'**
  String get houseTreasurerCanTransfer;

  /// Membership-card button that opens the transfer-ownership flow.
  ///
  /// In en, this message translates to:
  /// **'Transfer ownership'**
  String get houseTransferOwnership;

  /// Membership-card explanation for a regular Member.
  ///
  /// In en, this message translates to:
  /// **'You are a Member. You can leave this house at any time; your account and past records are kept.'**
  String get houseMemberCanLeave;

  /// Membership-card button that starts the leave-house flow.
  ///
  /// In en, this message translates to:
  /// **'Leave house'**
  String get houseLeaveHouse;

  /// Hint under the invite code on the member list.
  ///
  /// In en, this message translates to:
  /// **'Share this code with housemates to join.'**
  String get houseInviteShareHint;

  /// Confirmation SnackBar after copying the invite code to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied!'**
  String get houseInviteCodeCopied;

  /// Body of the platform share sheet for the invite code. 'Rental Ledger' is the product name and is never translated; {code} is user data inserted verbatim.
  ///
  /// In en, this message translates to:
  /// **'Join my house on Rental Ledger!\n\nInvite Code: {code}'**
  String houseShareMessage(String code);

  /// Subject line of the platform share sheet for the invite code. 'Rental Ledger' is the product name and is never translated.
  ///
  /// In en, this message translates to:
  /// **'Rental Ledger Invite'**
  String get houseShareSubject;

  /// Join date shown under a member's name on a member tile. {date} is already formatted for the active locale.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String houseJoinedOn(String date);

  /// Tooltip on the transfer-ownership icon in a member tile's trailing actions.
  ///
  /// In en, this message translates to:
  /// **'Make treasurer'**
  String get houseMakeTreasurer;

  /// Tooltip on the app-bar hamburger button that opens the navigation drawer (shared with the other list screens).
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get actionMenu;

  /// Confirmation body in the sign-out dialog, on the Settings and Profile screens.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get actionSignOutConfirm;

  /// Error display on the Reports screen when the report fails to load and no domain failure message is available.
  ///
  /// In en, this message translates to:
  /// **'Could not load reports.'**
  String get reportLoadFailed;

  /// Reports summary box and monthly-trend legend: every positive transaction in scope.
  ///
  /// In en, this message translates to:
  /// **'Money In'**
  String get reportMoneyIn;

  /// Reports summary box and monthly-trend legend: every negative transaction in scope.
  ///
  /// In en, this message translates to:
  /// **'Money Out'**
  String get reportMoneyOut;

  /// Third summary box on the all-time report, where In minus Out is the real account balance.
  ///
  /// In en, this message translates to:
  /// **'Current Balance'**
  String get reportCurrentBalance;

  /// Note under the summary row while a period filter is active, so the filtered figures are not mistaken for the account balance. {amount} is an already-formatted currency string.
  ///
  /// In en, this message translates to:
  /// **'Central Account balance (all time): {amount}'**
  String reportCentralBalanceAllTime(String amount);

  /// Section heading above the reports insight cards.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get reportInsights;

  /// Section heading for the breakdown of what makes up Money Out.
  ///
  /// In en, this message translates to:
  /// **'Where the Money Goes'**
  String get reportWhereMoneyGoes;

  /// Section heading above the donut chart of spending by category.
  ///
  /// In en, this message translates to:
  /// **'Category Breakdown'**
  String get reportCategoryBreakdown;

  /// Section heading above the monthly Money In / Money Out bar chart.
  ///
  /// In en, this message translates to:
  /// **'Monthly Trend'**
  String get reportMonthlyTrend;

  /// Empty state on the Reports screen when the house has no money movement at all.
  ///
  /// In en, this message translates to:
  /// **'No reports yet'**
  String get reportEmptyTitle;

  /// Body of the Reports empty state.
  ///
  /// In en, this message translates to:
  /// **'Deposits and expenses will appear here as they are recorded.'**
  String get reportEmptyDescription;

  /// Empty state on the Reports screen when the selected period contains no activity.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this period'**
  String get reportEmptyPeriodTitle;

  /// Body of the Reports empty state for a period filter that matches nothing.
  ///
  /// In en, this message translates to:
  /// **'No deposits, expense claims, or reimbursements fell inside the selected period.'**
  String get reportEmptyPeriodDescription;

  /// Action on the empty-period state that clears the Reports date filter.
  ///
  /// In en, this message translates to:
  /// **'Show all time'**
  String get reportShowAllTime;

  /// Help text at the top of the Reports date-range picker.
  ///
  /// In en, this message translates to:
  /// **'Choose a report period'**
  String get reportChoosePeriod;

  /// Insight card title naming the category with the most spending.
  ///
  /// In en, this message translates to:
  /// **'Highest Expense Category'**
  String get reportHighestExpenseCategory;

  /// Insight card title for the single biggest paid expense claim.
  ///
  /// In en, this message translates to:
  /// **'Largest Expense Claim'**
  String get reportLargestExpenseClaim;

  /// Insight card title for the total of reimbursed expense claims.
  ///
  /// In en, this message translates to:
  /// **'Expense Reimbursements'**
  String get reportExpenseReimbursements;

  /// Insight card title for approved expenses not yet paid out.
  ///
  /// In en, this message translates to:
  /// **'Pending Reimbursements'**
  String get reportPendingReimbursements;

  /// Insight card title for average spending per active month.
  ///
  /// In en, this message translates to:
  /// **'Average Monthly Expense'**
  String get reportAverageMonthlyExpense;

  /// Insight card title for the mean deposit amount.
  ///
  /// In en, this message translates to:
  /// **'Average Deposit'**
  String get reportAverageDeposit;

  /// Insight card title for the single biggest deposit.
  ///
  /// In en, this message translates to:
  /// **'Largest Deposit'**
  String get reportLargestDeposit;

  /// Insight card title showing a count of settled bills.
  ///
  /// In en, this message translates to:
  /// **'Bills Paid'**
  String get reportBillsPaid;

  /// Insight card title showing a count of bills still outstanding.
  ///
  /// In en, this message translates to:
  /// **'Bills Pending'**
  String get reportBillsPending;

  /// Legend row in the Money Out breakdown covering reimbursed expense claims.
  ///
  /// In en, this message translates to:
  /// **'Expense reimbursements'**
  String get reportMoneyOutReimbursements;

  /// Legend row in the Money Out breakdown covering direct payments that are not bill payments.
  ///
  /// In en, this message translates to:
  /// **'Direct payments'**
  String get reportMoneyOutDirectPayments;

  /// Legend row in the Money Out breakdown covering bills settled from the central account.
  ///
  /// In en, this message translates to:
  /// **'Bill payments'**
  String get reportMoneyOutBillPayments;

  /// Legend row in the Money Out breakdown covering negative balance adjustments.
  ///
  /// In en, this message translates to:
  /// **'Adjustments'**
  String get reportMoneyOutAdjustments;

  /// Legend row in the Money Out breakdown covering any remaining outgoing money.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportMoneyOutOther;

  /// Intro line above the Money Out breakdown, stating the total being split. {amount} is an already-formatted currency string.
  ///
  /// In en, this message translates to:
  /// **'From {amount} of Money Out'**
  String reportMoneyOutFrom(String amount);

  /// Hint under the category donut chart when no slice is selected.
  ///
  /// In en, this message translates to:
  /// **'Tap a slice to see details'**
  String get reportTapSliceHint;

  /// Placeholder in the Settings profile header when the account has no display name. The name itself is user data and is never translated.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get settingsUser;

  /// Settings row and header button that open the profile editor.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get settingsEditProfile;

  /// Settings row label for the house invite code. The code itself is a stored value.
  ///
  /// In en, this message translates to:
  /// **'Invite Code'**
  String get settingsInviteCode;

  /// Confirmation after copying the house invite code to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Invite code copied'**
  String get settingsInviteCodeCopied;

  /// Settings section heading covering the account/profile row.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// Settings section heading and the theme picker's sheet title.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Settings row that opens the appearance-mode picker.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// Appearance option that follows the device or browser theme.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsThemeSystem;

  /// Explicit light appearance option.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Explicit dark appearance option.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// Subtitle under the system-default appearance option.
  ///
  /// In en, this message translates to:
  /// **'Follow your device or browser'**
  String get settingsThemeSystemHint;

  /// Settings switch that turns device notifications on or off.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get settingsPushNotifications;

  /// Subtitle under the push-notification switch.
  ///
  /// In en, this message translates to:
  /// **'Receive alerts for expense updates'**
  String get settingsNotificationsSubtitle;

  /// Web only: title of the Settings row that registers this browser for push notifications.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get settingsPushThisDevice;

  /// Web only: this browser has granted notification permission.
  ///
  /// In en, this message translates to:
  /// **'Notifications are on for this browser'**
  String get settingsPushStatusOn;

  /// Web only: notification permission not yet granted; includes the iOS Home Screen requirement.
  ///
  /// In en, this message translates to:
  /// **'Tap Enable to get alerts when the app is closed. On iPhone/iPad, add this app to your Home Screen first.'**
  String get settingsPushStatusOff;

  /// Web only: the browser has denied notification permission for this site.
  ///
  /// In en, this message translates to:
  /// **'Blocked. Allow notifications for this site in your browser settings.'**
  String get settingsPushStatusBlocked;

  /// Web only: button that asks the browser for notification permission.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get settingsPushEnable;

  /// Web only: confirmation after notification permission was granted.
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled on this device'**
  String get settingsPushEnabledToast;

  /// Settings section heading covering language and currency.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferences;

  /// Settings row and the currency picker's sheet title. The currency codes themselves are stored values and stay untranslated.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get settingsCurrency;

  /// Settings row that opens the help dialog.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get settingsHelpCenter;

  /// Subtitle under the About row. {version} is the build version, a technical value that is not translated.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// Legalese line in the About dialog.
  ///
  /// In en, this message translates to:
  /// **'A household finance management app.'**
  String get settingsAboutLegalese;

  /// One-line introduction under the product name in the help dialog.
  ///
  /// In en, this message translates to:
  /// **'Track shared household expenses with ease.'**
  String get settingsHelpIntro;

  /// Help dialog item title explaining how to file a claim.
  ///
  /// In en, this message translates to:
  /// **'Submit Expenses'**
  String get settingsHelpSubmitExpenses;

  /// Help dialog item describing how to file a claim.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a new expense claim with receipt.'**
  String get settingsHelpSubmitExpensesDesc;

  /// Help dialog item title explaining the Treasurer's review step.
  ///
  /// In en, this message translates to:
  /// **'Treasurer Approval'**
  String get settingsHelpTreasurerApproval;

  /// Help dialog item describing the Treasurer's review step.
  ///
  /// In en, this message translates to:
  /// **'The Treasurer reviews and approves expenses.'**
  String get settingsHelpTreasurerApprovalDesc;

  /// Help dialog item title explaining how members get paid back.
  ///
  /// In en, this message translates to:
  /// **'Reimbursements'**
  String get settingsHelpReimbursements;

  /// Help dialog item describing how members get paid back.
  ///
  /// In en, this message translates to:
  /// **'Once approved and paid, you get reimbursed.'**
  String get settingsHelpReimbursementsDesc;

  /// Help dialog item title explaining house invitations.
  ///
  /// In en, this message translates to:
  /// **'Invite Housemates'**
  String get settingsHelpInviteHousemates;

  /// Help dialog item describing house invitations.
  ///
  /// In en, this message translates to:
  /// **'Share your invite code from the Members screen.'**
  String get settingsHelpInviteHousematesDesc;

  /// App-bar title of the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Button under the avatar and the sheet title for the photo-source picker.
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get profileChangePhoto;

  /// Error shown when the camera or gallery picker fails.
  ///
  /// In en, this message translates to:
  /// **'Could not take a photo. Please try again.'**
  String get profilePhotoFailed;

  /// Label on the profile name field. The name the user types is their own data and is never translated.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get profileDisplayName;

  /// Placeholder inside the profile name field.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get profileDisplayNameHint;

  /// Validation message when the profile name field is blank on save.
  ///
  /// In en, this message translates to:
  /// **'Display name cannot be empty.'**
  String get profileDisplayNameEmpty;

  /// Label for the read-only email row on the profile screen. The address itself is user data.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// Section heading above the house, role and join-date rows.
  ///
  /// In en, this message translates to:
  /// **'House & Account'**
  String get profileHouseAndAccount;

  /// Label for the row showing the date the member joined the house.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get profileJoined;

  /// Confirmation after the profile change is saved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// Error shown when saving the profile fails.
  ///
  /// In en, this message translates to:
  /// **'Could not update your profile. Please try again.'**
  String get profileUpdateFailed;

  /// Save button label while the profile change is being written.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get profileSaving;

  /// Confirm button in a generic confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get actionConfirm;

  /// Button that opens the attached receipt in the full-screen viewer.
  ///
  /// In en, this message translates to:
  /// **'View Receipt'**
  String get actionViewReceipt;

  /// Button that opens a receipt preview before it is saved.
  ///
  /// In en, this message translates to:
  /// **'Preview Receipt'**
  String get actionPreviewReceipt;

  /// Member action that nudges the Treasurer about a bill.
  ///
  /// In en, this message translates to:
  /// **'Remind Treasurer'**
  String get actionRemindTreasurer;

  /// Confirmation after a bill reminder notification is sent.
  ///
  /// In en, this message translates to:
  /// **'Reminder sent to Treasurer'**
  String get actionReminderSent;

  /// App-bar title of the bill details screen.
  ///
  /// In en, this message translates to:
  /// **'Bill Details'**
  String get billDetailsTitle;

  /// Shown on the bill details screen when the bill cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Could not load bill.'**
  String get billLoadFailed;

  /// Shown when the bill details screen is opened for a bill that no longer exists.
  ///
  /// In en, this message translates to:
  /// **'Bill not found.'**
  String get billNotFound;

  /// Status label on a bill details page for a bill that has not been paid yet.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Bill'**
  String get billStatusUpcoming;

  /// Field label telling whether a bill repeats every month.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get billRecurring;

  /// Value shown for a bill that repeats every month.
  ///
  /// In en, this message translates to:
  /// **'Yes — rolls monthly'**
  String get billRecurringYes;

  /// Shown in place of an amount for a bill that only reminds and carries no money.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get billReminderOnly;

  /// Confirm button on the bill payment sheet.
  ///
  /// In en, this message translates to:
  /// **'Confirm Payment'**
  String get billConfirmPayment;

  /// Confirmation dialog question before a bill is marked paid. The bill title is user-entered and is inserted verbatim.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{title}\" as paid?'**
  String billMarkPaidConfirm(String title);

  /// Dialog body explaining what marking a recurring bill paid will do.
  ///
  /// In en, this message translates to:
  /// **'Rolls the bill to next month.'**
  String get billRollsToNextMonth;

  /// Dialog body explaining what marking a one-off bill paid will do.
  ///
  /// In en, this message translates to:
  /// **'Settles this bill.'**
  String get billSettles;

  /// Field label for the month a bill payment applies to.
  ///
  /// In en, this message translates to:
  /// **'Payment covers month'**
  String get billPaymentCoversMonth;

  /// Format example under the month field, showing the year-month shape.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2026-09'**
  String get billPaymentCoversMonthHint;

  /// Refusal shown when a bill that carries an amount is paid without attaching a receipt.
  ///
  /// In en, this message translates to:
  /// **'A receipt or proof is required for a bill with an amount.'**
  String get billProofRequired;

  /// Refusal shown to a member who attempts to record a bill payment.
  ///
  /// In en, this message translates to:
  /// **'Only the Treasurer can mark a bill as paid.'**
  String get billTreasurerOnlyMarkPaid;

  /// Shown when recording a bill payment fails for an unexpected reason.
  ///
  /// In en, this message translates to:
  /// **'Could not mark the bill as paid. Please try again.'**
  String get billMarkPaidFailed;

  /// Confirmation after a bill payment is recorded.
  ///
  /// In en, this message translates to:
  /// **'Bill marked as paid'**
  String get billMarkedPaid;

  /// Confirmation dialog title before a bill is deleted.
  ///
  /// In en, this message translates to:
  /// **'Delete Bill?'**
  String get billDeleteTitle;

  /// Confirmation after a bill is deleted.
  ///
  /// In en, this message translates to:
  /// **'Bill deleted'**
  String get billDeleted;

  /// Confirmation after an existing bill is edited and saved.
  ///
  /// In en, this message translates to:
  /// **'Bill updated'**
  String get billUpdated;

  /// Compact due-date line on a bill card. The date is already formatted for the active locale.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String billDueOn(String date);

  /// Field label for the due date in the add/edit bill form. The date is already formatted for the active locale.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String billDueDateLabel(String date);

  /// App-bar title of the transaction details screen for a deposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit Details'**
  String get depositDetailsTitle;

  /// App-bar title of the transaction details screen for a direct payment.
  ///
  /// In en, this message translates to:
  /// **'Direct Payment Details'**
  String get directPaymentDetailsTitle;

  /// Subtitle naming who performed a transaction. The member name is user data and is inserted verbatim.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String txnByPerson(String name);

  /// Field label for the period a transaction applies to, such as a bill payment's month.
  ///
  /// In en, this message translates to:
  /// **'Covers Month'**
  String get txnCoversMonth;

  /// App-bar title of the expense details screen.
  ///
  /// In en, this message translates to:
  /// **'Expense Details'**
  String get expenseDetailsTitle;

  /// Shown on the expense details screen when the expense cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Could not load expense.'**
  String get expenseLoadFailed;

  /// Shown when the expense details screen is opened for an expense that no longer exists.
  ///
  /// In en, this message translates to:
  /// **'Expense not found.'**
  String get expenseNotFound;

  /// Line naming who paid for a purchase. The member name is user data and is inserted verbatim.
  ///
  /// In en, this message translates to:
  /// **'Purchased by {name}'**
  String expensePurchasedByPerson(String name);

  /// Shown instead of a receipt thumbnail when the stored image cannot be loaded.
  ///
  /// In en, this message translates to:
  /// **'Receipt unavailable'**
  String get expenseReceiptUnavailable;

  /// Line showing the Treasurer's rejection reason. The reason is user-entered text and is inserted verbatim.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String expenseRejectReason(String reason);

  /// Section heading above an expense's description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get expenseDescriptionSection;

  /// Section heading above an expense's approval timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get expenseTimeline;

  /// Section heading above the approve/reject/mark-paid controls, shown only to the Treasurer.
  ///
  /// In en, this message translates to:
  /// **'Treasurer Actions'**
  String get expenseTreasurerActions;

  /// Confirmation dialog question before a reimbursement is paid out. The expense title is user-entered and is inserted verbatim.
  ///
  /// In en, this message translates to:
  /// **'Mark \"{title}\" as reimbursed from the Central Account?'**
  String expenseMarkPaidConfirm(String title);

  /// Confirmation dialog title before a member deletes their own pending expense.
  ///
  /// In en, this message translates to:
  /// **'Delete Expense?'**
  String get expenseDeleteTitle;

  /// Confirmation dialog body before an expense is deleted. The expense title is user-entered and is inserted verbatim.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? This cannot be undone.'**
  String expenseDeleteConfirm(String title);

  /// Confirmation after a member deletes their own pending expense.
  ///
  /// In en, this message translates to:
  /// **'Expense deleted'**
  String get expenseDeleted;

  /// Title of the dialog in which the Treasurer rejects a claim.
  ///
  /// In en, this message translates to:
  /// **'Reject Expense'**
  String get expenseRejectTitle;

  /// Question at the top of the reject dialog. The expense title is user-entered and is inserted verbatim.
  ///
  /// In en, this message translates to:
  /// **'Reject \"{title}\"?'**
  String expenseRejectConfirm(String title);

  /// Field label for the Treasurer's rejection reason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get expenseRejectReasonLabel;

  /// Example text under the rejection reason field.
  ///
  /// In en, this message translates to:
  /// **'e.g. Receipt is blurry, please upload a clearer one.'**
  String get expenseRejectReasonHint;

  /// Placeholder in a timeline step that has not happened yet.
  ///
  /// In en, this message translates to:
  /// **'Waiting...'**
  String get expenseTimelineWaiting;

  /// Refusal shown to anyone other than the claim's submitter who tries to send a reminder.
  ///
  /// In en, this message translates to:
  /// **'Only the submitter can remind the Treasurer.'**
  String get expenseRemindOnlySubmitter;

  /// Shown when a reminder cannot be addressed because the house has no Treasurer on record.
  ///
  /// In en, this message translates to:
  /// **'Could not find the Treasurer.'**
  String get expenseTreasurerNotFound;

  /// Shown when the camera or gallery picker returns no image.
  ///
  /// In en, this message translates to:
  /// **'Could not pick a photo. Please try again.'**
  String get expensePhotoPickFailed;

  /// Shown when saving an edited expense fails.
  ///
  /// In en, this message translates to:
  /// **'Could not update. Please try again.'**
  String get expenseUpdateFailed;

  /// App-bar title of the expense edit screen.
  ///
  /// In en, this message translates to:
  /// **'Edit Expense'**
  String get expenseEditTitle;

  /// Field label above the amount, naming the currency in use.
  ///
  /// In en, this message translates to:
  /// **'Amount (RM)'**
  String get expenseAmountRm;

  /// Field label for an expense's description.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get expenseDescriptionOptional;

  /// Status line in the expense edit form after a replacement receipt is chosen.
  ///
  /// In en, this message translates to:
  /// **'New receipt selected — will replace the current one on save.'**
  String get expenseReceiptNewSelected;

  /// Status line in the expense edit form after the receipt is marked for removal.
  ///
  /// In en, this message translates to:
  /// **'Receipt will be removed on save.'**
  String get expenseReceiptWillRemove;

  /// Status line in the expense edit form when the existing receipt is kept.
  ///
  /// In en, this message translates to:
  /// **'Current receipt attached.'**
  String get expenseReceiptCurrent;

  /// Status line in the expense edit form when there is no receipt.
  ///
  /// In en, this message translates to:
  /// **'No receipt attached.'**
  String get expenseReceiptNone;

  /// Button that marks the attached receipt for removal when the expense is saved.
  ///
  /// In en, this message translates to:
  /// **'Remove receipt'**
  String get expenseRemoveReceipt;

  /// Screen-reader label on the dashboard's profile button.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get dashboardProfileLabel;

  /// Shown on the dashboard when the summary fails to load and the error is not a recognized failure.
  ///
  /// In en, this message translates to:
  /// **'Could not load dashboard.'**
  String get dashboardLoadError;

  /// Onboarding heading shown before the user belongs to a house. The product name is injected so it is never translated.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {appName}!'**
  String dashboardWelcomeTitle(String appName);

  /// Onboarding body text shown before the user belongs to a house.
  ///
  /// In en, this message translates to:
  /// **'Create or join a house to start tracking expenses.'**
  String get dashboardOnboardingDescription;

  /// Onboarding button that opens the create-house form.
  ///
  /// In en, this message translates to:
  /// **'Create a House'**
  String get dashboardCreateHouse;

  /// Onboarding button that opens the join-house form.
  ///
  /// In en, this message translates to:
  /// **'Join with Code'**
  String get dashboardJoinWithCode;

  /// Summary card label for deposits recorded this month.
  ///
  /// In en, this message translates to:
  /// **'Money In'**
  String get dashboardMoneyIn;

  /// Summary card label for money paid out this month.
  ///
  /// In en, this message translates to:
  /// **'Money Out'**
  String get dashboardMoneyOut;

  /// Heading of the dashboard section listing open expense claims.
  ///
  /// In en, this message translates to:
  /// **'Pending Items'**
  String get dashboardPendingItems;

  /// Empty-state title in the dashboard's pending-items section.
  ///
  /// In en, this message translates to:
  /// **'No pending items'**
  String get dashboardPendingItemsEmpty;

  /// Empty-state description in the dashboard's pending-items section.
  ///
  /// In en, this message translates to:
  /// **'Submitted and approved expenses will appear here.'**
  String get dashboardPendingItemsEmptyDescription;

  /// Sub-label under an approved claim that has not been paid out yet. Chosen from the stored status value, never from text.
  ///
  /// In en, this message translates to:
  /// **'Approved — waiting for reimbursement'**
  String get dashboardWaitingForReimbursement;

  /// Sub-label under a pending claim. Chosen from the stored status value, never from text.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Treasurer approval'**
  String get dashboardWaitingForApproval;

  /// Heading of the dashboard's recent-activity section.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get dashboardRecentActivity;

  /// Empty-state description in the dashboard's recent-activity section.
  ///
  /// In en, this message translates to:
  /// **'Transactions, expenses, and deposits will appear here.'**
  String get dashboardRecentActivityEmptyDescription;

  /// Stand-in shown for a transaction whose member name could not be resolved. Never replaces a real member name.
  ///
  /// In en, this message translates to:
  /// **'Unknown Member'**
  String get commonUnknownMember;

  /// Placeholder in the History screen's search field.
  ///
  /// In en, this message translates to:
  /// **'Search by name...'**
  String get historySearchHint;

  /// Shown on the History screen when the load fails and the error is not a recognized failure.
  ///
  /// In en, this message translates to:
  /// **'Could not load history.'**
  String get historyLoadError;

  /// Empty-state description when filters or a search exclude every event.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search or filters.'**
  String get historyNoResultsHint;

  /// Empty-state description when a house has no recorded activity yet.
  ///
  /// In en, this message translates to:
  /// **'Deposits, expenses, and bills will appear here.'**
  String get historyEmptyDescription;

  /// History event label for an expense entering review. Derived from an internal event type, never from a stored value.
  ///
  /// In en, this message translates to:
  /// **'Expense Submitted'**
  String get historyExpenseSubmitted;

  /// History event label for an approved claim. Derived from an internal event type, never from a stored value.
  ///
  /// In en, this message translates to:
  /// **'Expense Approved'**
  String get historyExpenseApproved;

  /// History event label for a rejected claim. Derived from an internal event type, never from a stored value.
  ///
  /// In en, this message translates to:
  /// **'Expense Rejected'**
  String get historyExpenseRejected;

  /// History event label for a reimbursed claim, and the matching entry in the History type filter.
  ///
  /// In en, this message translates to:
  /// **'Expense Paid'**
  String get historyTypeExpensePaid;

  /// History event label for a bill being added.
  ///
  /// In en, this message translates to:
  /// **'Bill Created'**
  String get historyBillCreated;

  /// History event label for a bill payment.
  ///
  /// In en, this message translates to:
  /// **'Bill Paid'**
  String get historyBillPaid;

  /// Status chip on a history entry for a bill that has not been paid yet.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Bill'**
  String get historyUpcomingBill;

  /// Status label for a bill whose due date is still ahead. The status is derived, so it is never a stored value.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get statusUpcoming;

  /// Heading of the dashboard section listing bills that are due.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Bills'**
  String get billUpcomingBills;

  /// Button that opens the add-bill form, and the title of that form.
  ///
  /// In en, this message translates to:
  /// **'Add Bill'**
  String get billAdd;

  /// Shown in the bills section when the list cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Could not load bills. Pull to refresh.'**
  String get billListLoadFailed;

  /// Empty-state title in the dashboard bills section.
  ///
  /// In en, this message translates to:
  /// **'No upcoming bills'**
  String get billNoneUpcoming;

  /// Empty-state description in the dashboard bills section.
  ///
  /// In en, this message translates to:
  /// **'Add recurring bills to track them here.'**
  String get billNoneUpcomingHint;

  /// Tooltip on the edit action of a bill card.
  ///
  /// In en, this message translates to:
  /// **'Edit bill'**
  String get billEditTooltip;

  /// Tooltip on the delete action of a bill card.
  ///
  /// In en, this message translates to:
  /// **'Delete bill'**
  String get billDeleteTooltip;

  /// State label for a bill whose reminder is enabled.
  ///
  /// In en, this message translates to:
  /// **'Reminder On'**
  String get billReminderOn;

  /// Action that turns on a bill reminder.
  ///
  /// In en, this message translates to:
  /// **'Set Reminder'**
  String get billSetReminder;

  /// Button that records a bill payment.
  ///
  /// In en, this message translates to:
  /// **'Mark Paid'**
  String get billMarkPaid;

  /// Title of the form for editing an existing bill.
  ///
  /// In en, this message translates to:
  /// **'Edit Bill'**
  String get billEditTitle;

  /// Field label for a bill name in the add/edit bill form.
  ///
  /// In en, this message translates to:
  /// **'Bill name'**
  String get billName;

  /// Field label for a bill amount. Blank makes the bill a reminder only.
  ///
  /// In en, this message translates to:
  /// **'Amount (RM) — optional'**
  String get billAmountRmOptional;

  /// Hint under the bill amount field explaining that a blank amount is allowed.
  ///
  /// In en, this message translates to:
  /// **'Leave blank for reminder only'**
  String get billAmountHint;

  /// Switch label that makes a bill recur monthly.
  ///
  /// In en, this message translates to:
  /// **'Repeat every month'**
  String get billRepeatMonthly;

  /// Sub-label under the repeat-monthly switch.
  ///
  /// In en, this message translates to:
  /// **'Auto-create the next bill each month'**
  String get billRepeatMonthlyHint;

  /// Dialog body shown when marking a recurring bill paid.
  ///
  /// In en, this message translates to:
  /// **'This will roll the bill to next month.'**
  String get billRollNextMonth;

  /// Dialog body shown when marking a one-off bill paid.
  ///
  /// In en, this message translates to:
  /// **'This bill will be marked as paid.'**
  String get billWillBeMarkedPaid;

  /// Placeholder in the Bill History search field.
  ///
  /// In en, this message translates to:
  /// **'Search by bill title...'**
  String get billHistorySearchHint;

  /// Shown on the Bill History screen when the list cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Could not load bill history.'**
  String get billHistoryLoadFailed;

  /// Empty-state title on Bill History when the house has recorded no bills.
  ///
  /// In en, this message translates to:
  /// **'No bills yet'**
  String get billHistoryEmpty;

  /// Empty-state description on Bill History when no filter is active.
  ///
  /// In en, this message translates to:
  /// **'Bills added to this house will appear here.'**
  String get billHistoryEmptyDescription;

  /// Empty-state description on Bill History when a member filter hides every row. Explains the structural reason rather than telling the user to adjust filters.
  ///
  /// In en, this message translates to:
  /// **'Bills name a member only when a payment was recorded against them, so this filter hides upcoming bills and bills settled without a payment record.'**
  String get billHistoryMemberFilterEmpty;

  /// Chip on a bill payment naming the month it paid for. The period is a stored value such as 2026-08 and is shown verbatim.
  ///
  /// In en, this message translates to:
  /// **'Covers {period}'**
  String billHistoryCoversPeriod(String period);

  /// Chip counting how many settlements a rolling recurring bill holds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 payment} other{{count} payments}}'**
  String billHistoryPaymentCount(int count);

  /// Confirmation toast after marking every notification read.
  ///
  /// In en, this message translates to:
  /// **'All marked as read'**
  String get notifAllMarkedRead;

  /// Error state when the notifications stream fails.
  ///
  /// In en, this message translates to:
  /// **'Could not load notifications.'**
  String get notifLoadFailed;

  /// Description under the empty notifications state.
  ///
  /// In en, this message translates to:
  /// **'Updates about expenses, payments, and approvals will appear here.'**
  String get notifEmptyDescription;

  /// Notification group header for items from the last seven days.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get timeThisWeek;

  /// Notification group header for items older than a week.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get timeEarlier;

  /// Accessibility tooltip for the button that opens the navigation drawer. The word is the same in Malaysian Malay, which is why both locales match.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get navMenu;

  /// Short chip label linking to a stored receipt image.
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get labelReceipt;

  /// Guard shown when an action needs an active house but none is loaded.
  ///
  /// In en, this message translates to:
  /// **'No house found.'**
  String get errorNoHouse;

  /// Guard shown when an action needs a signed-in user but there is none.
  ///
  /// In en, this message translates to:
  /// **'Not authenticated.'**
  String get errorNotSignedIn;

  /// Guard shown when a bill could not be created at all.
  ///
  /// In en, this message translates to:
  /// **'Failed to create bill.'**
  String get errorBillCreateFailed;

  /// Row label for a total line in a summary table.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get labelTotal;

  /// Subtitle printed under the product name on an exported PDF report.
  ///
  /// In en, this message translates to:
  /// **'Financial Report'**
  String get reportPdfSubtitle;

  /// Label for the reporting period shown on an exported PDF report.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get reportPdfPeriod;

  /// When an exported PDF report was generated. {date} is a formatted date and time.
  ///
  /// In en, this message translates to:
  /// **'Generated {date}'**
  String reportPdfGeneratedOn(String date);

  /// Section heading for the summary table on an exported PDF report.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get reportPdfSummary;

  /// Summary row label for the total of paid expense claims, on an exported PDF report.
  ///
  /// In en, this message translates to:
  /// **'Total Expenses'**
  String get reportPdfTotalExpenses;

  /// Summary row label for the total of deposits, on an exported PDF report.
  ///
  /// In en, this message translates to:
  /// **'Total Deposits'**
  String get reportPdfTotalDeposits;

  /// Summary row label for deposits minus paid expenses, on an exported PDF report.
  ///
  /// In en, this message translates to:
  /// **'Net Flow'**
  String get reportPdfNetFlow;

  /// Column header for the month name in the monthly trend table of an exported PDF report.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get reportPdfMonth;

  /// Column header for a row's percentage share of the total, on an exported PDF report.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get reportPdfShare;

  /// Shown in an exported PDF report when the selected period has no financial activity.
  ///
  /// In en, this message translates to:
  /// **'No report data for this period.'**
  String get reportPdfNoData;

  /// Error shown when generating or opening the report PDF failed.
  ///
  /// In en, this message translates to:
  /// **'Could not generate the PDF. Please try again.'**
  String get reportPdfFailed;

  /// Shown when a deposit request was approved, rejected or cancelled by someone else before this action ran.
  ///
  /// In en, this message translates to:
  /// **'This deposit has already been reviewed or cancelled. Refresh to see its current state.'**
  String get errorDepositRequestAlreadyReviewed;

  /// Member action (speed dial, screen title and button) to submit a deposit they paid for Treasurer approval.
  ///
  /// In en, this message translates to:
  /// **'Submit Deposit'**
  String get actionSubmitDeposit;

  /// Intro text on the member Submit Deposit screen.
  ///
  /// In en, this message translates to:
  /// **'Record money you paid into the Central Account. The Treasurer will review it before it is added to the balance.'**
  String get depositSubmitSubtitle;

  /// Success toast after a member submits a deposit request.
  ///
  /// In en, this message translates to:
  /// **'Deposit submitted for Treasurer approval'**
  String get depositSubmittedForApproval;

  /// Hint under the disabled Submit Deposit button while no proof is attached.
  ///
  /// In en, this message translates to:
  /// **'Attach a receipt or proof above to submit the deposit.'**
  String get depositSubmitProofRequiredHint;

  /// Read-only Paid by value on the member Submit Deposit screen: the member always deposits for themselves.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get depositPaidByYou;

  /// App-bar title of the deposit request details screen.
  ///
  /// In en, this message translates to:
  /// **'Deposit Request'**
  String get depositRequestTitle;

  /// Label under a pending member deposit request on the dashboard.
  ///
  /// In en, this message translates to:
  /// **'Deposit · waiting for Treasurer approval'**
  String get depositRequestWaitingApproval;

  /// Names the member who submitted a deposit request. The name is user data inserted verbatim.
  ///
  /// In en, this message translates to:
  /// **'Submitted by {name}'**
  String depositRequestSubmittedBy(String name);

  /// Title of the dialog confirming approval of a member deposit request.
  ///
  /// In en, this message translates to:
  /// **'Approve Deposit'**
  String get depositRequestApproveTitle;

  /// Body of the approve-deposit dialog. amount is a formatted currency figure; name is the member.
  ///
  /// In en, this message translates to:
  /// **'Add {amount} from {name} to the Central Account?'**
  String depositRequestApproveConfirm(String amount, String name);

  /// Title of the dialog rejecting a member deposit request.
  ///
  /// In en, this message translates to:
  /// **'Reject Deposit'**
  String get depositRequestRejectTitle;

  /// Body of the reject-deposit dialog. amount is a formatted currency figure; name is the member.
  ///
  /// In en, this message translates to:
  /// **'Reject the deposit of {amount} from {name}?'**
  String depositRequestRejectConfirm(String amount, String name);

  /// Success toast after the Treasurer approves a deposit request.
  ///
  /// In en, this message translates to:
  /// **'Deposit approved and added to the balance'**
  String get depositRequestApproved;

  /// Success toast after the Treasurer rejects a deposit request.
  ///
  /// In en, this message translates to:
  /// **'Deposit rejected'**
  String get depositRequestRejected;

  /// Member action to withdraw their own pending deposit request.
  ///
  /// In en, this message translates to:
  /// **'Cancel Request'**
  String get actionCancelRequest;

  /// Title of the dialog confirming a member withdraws their pending deposit request.
  ///
  /// In en, this message translates to:
  /// **'Cancel Deposit Request'**
  String get depositRequestCancelTitle;

  /// Body of the cancel-deposit-request dialog. amount is a formatted currency figure.
  ///
  /// In en, this message translates to:
  /// **'Withdraw your pending deposit of {amount}? This cannot be undone.'**
  String depositRequestCancelConfirm(String amount);

  /// Dismisses the cancel-deposit-request dialog without cancelling.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get depositRequestKeep;

  /// Success toast after a member cancels their pending deposit request.
  ///
  /// In en, this message translates to:
  /// **'Deposit request cancelled'**
  String get depositRequestCancelled;

  /// Shown on a pending deposit request to a member who cannot review it.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the Treasurer to review this deposit.'**
  String get depositRequestAwaitingReview;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ms'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ms': return AppLocalizationsMs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
