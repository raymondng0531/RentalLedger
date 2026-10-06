// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Malay (`ms`).
class AppLocalizationsMs extends AppLocalizations {
  AppLocalizationsMs([String locale = 'ms']) : super(locale);

  @override
  String get languageSectionTitle => 'Bahasa';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageMalay => 'Bahasa Melayu';

  @override
  String get navHome => 'Utama';

  @override
  String get navDashboard => 'Papan Pemuka';

  @override
  String get navHistory => 'Sejarah';

  @override
  String get navBillHistory => 'Sejarah Bil';

  @override
  String get navExpenses => 'Perbelanjaan';

  @override
  String get navMembers => 'Ahli';

  @override
  String get navNotifications => 'Pemberitahuan';

  @override
  String get navReports => 'Laporan';

  @override
  String get navSettings => 'Tetapan';

  @override
  String get actionSignOut => 'Log Keluar';

  @override
  String get drawerMyHouses => 'RUMAH SAYA';

  @override
  String get actionDirectPayment => 'Bayaran Terus';

  @override
  String get actionDeposit => 'Deposit';

  @override
  String get actionAddExpense => 'Tambah Perbelanjaan';

  @override
  String get pageNotFoundTitle => 'Halaman tidak dijumpai';

  @override
  String get pageNotFoundMessage => 'Halaman yang anda cari tidak wujud.';

  @override
  String get actionGoHome => 'Ke Utama';

  @override
  String get unableToOpenItem => 'Tidak dapat membuka item ini.';

  @override
  String get errorGenericMessage => 'Sesuatu tidak kena. Sila cuba lagi.';

  @override
  String get actionTryAgain => 'Cuba Lagi';

  @override
  String get centralAccountBalance => 'Baki Akaun Pusat';

  @override
  String get receiptTitle => 'Resit';

  @override
  String get appTagline => 'Kewangan rumah anda, dipermudah';

  @override
  String get timeJustNow => 'Baru sahaja';

  @override
  String timeMinutesAgo(int count) {
    return '$count min lalu';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count jam lalu';
  }

  @override
  String get timeYesterday => 'Semalam';

  @override
  String timeDaysAgo(int count) {
    return '$count hari lalu';
  }

  @override
  String get timeToday => 'Hari ini';

  @override
  String get timeTomorrow => 'Esok';

  @override
  String get periodLast7Days => '7 Hari Lalu';

  @override
  String get periodLast30Days => '30 Hari Lalu';

  @override
  String get periodLast90Days => '90 Hari Lalu';

  @override
  String get periodThisMonth => 'Bulan Ini';

  @override
  String get periodLastMonth => 'Bulan Lepas';

  @override
  String get periodAll => 'Semua';

  @override
  String get periodCustomRange => 'Julat Tersuai';

  @override
  String get billDueToday => 'Bayar Hari Ini';

  @override
  String billDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hari lagi',
    );
    return '$_temp0';
  }

  @override
  String billOverdueByDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lewat $count hari',
    );
    return '$_temp0';
  }

  @override
  String get reportPeriodAllTime => 'Sepanjang masa';

  @override
  String get reportPeriodThisMonth => 'Bulan ini';

  @override
  String get reportPeriodLast3Months => '3 bulan lepas';

  @override
  String get reportPeriodThisYear => 'Tahun ini';

  @override
  String get reportPeriodCustomRange => 'Julat tersuai';

  @override
  String get authSignInCancelled => 'Log masuk dibatalkan.';

  @override
  String scaffoldGreeting(String name) {
    return 'Helo, $name';
  }

  @override
  String scaffoldItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count item',
      one: '1 item',
      zero: 'Tiada item',
    );
    return '$_temp0';
  }

  @override
  String get statusPending => 'Menunggu';

  @override
  String get statusApproved => 'Diluluskan';

  @override
  String get statusRejected => 'Ditolak';

  @override
  String get statusPaid => 'Dibayar';

  @override
  String get statusSubmitted => 'Dihantar';

  @override
  String get statusCompleted => 'Selesai';

  @override
  String get statusOverdue => 'Lewat';

  @override
  String get txnTypeDeposit => 'Deposit';

  @override
  String get txnTypeReimbursement => 'Bayaran Balik';

  @override
  String get txnTypeDirectPayment => 'Bayaran Terus';

  @override
  String get txnTypeAdjustment => 'Pelarasan';

  @override
  String get txnTypeExpense => 'Perbelanjaan';

  @override
  String get txnTypeBill => 'Bil';

  @override
  String get txnTypeActivity => 'Aktiviti';

  @override
  String get paymentSourcePersonal => 'Peribadi';

  @override
  String get paymentSourceCentral => 'Akaun Pusat';

  @override
  String get paymentSourcePersonalReimbursement => 'Peribadi (bayaran balik)';

  @override
  String get paymentMethodCash => 'Tunai';

  @override
  String get paymentMethodBankTransfer => 'Pindahan Bank';

  @override
  String get paymentMethodEWallet => 'e-Dompet';

  @override
  String get paymentMethodCard => 'Kad';

  @override
  String get categoryRent => 'Sewa';

  @override
  String get categoryUtilities => 'Utiliti';

  @override
  String get categoryFood => 'Makanan';

  @override
  String get categoryHousehold => 'Rumahtangga';

  @override
  String get categoryMaintenance => 'Penyelenggaraan';

  @override
  String get categoryInternet => 'Internet';

  @override
  String get categoryOther => 'Lain-lain';

  @override
  String get categoryAll => 'Semua Kategori';

  @override
  String get categoryNoneAvailable => 'Tiada kategori tersedia.';

  @override
  String get actionBack => 'Kembali';

  @override
  String get actionSave => 'Simpan';

  @override
  String get actionCancel => 'Batal';

  @override
  String get actionDelete => 'Padam';

  @override
  String get actionRemove => 'Buang';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionClose => 'Tutup';

  @override
  String get actionDone => 'Selesai';

  @override
  String get actionApply => 'Guna';

  @override
  String get actionReset => 'Set Semula';

  @override
  String get actionClearAll => 'Kosongkan semua';

  @override
  String get actionAdd => 'Tambah';

  @override
  String get actionViewAll => 'Lihat Semua';

  @override
  String get actionSeeAll => 'Lihat semua';

  @override
  String get actionSeeAllActivity => 'Lihat Semua Aktiviti';

  @override
  String get actionShare => 'Kongsi';

  @override
  String get actionCopy => 'Salin';

  @override
  String get actionCopied => 'Disalin';

  @override
  String get actionYes => 'Ya';

  @override
  String get actionNo => 'Tidak';

  @override
  String get actionPreview => 'Pratonton';

  @override
  String get actionTakePhoto => 'Ambil Gambar';

  @override
  String get actionChoosePhoto => 'Pilih Gambar';

  @override
  String get actionChooseFromGallery => 'Pilih dari Galeri';

  @override
  String get actionShowPassword => 'Tunjukkan kata laluan';

  @override
  String get actionHidePassword => 'Sembunyikan kata laluan';

  @override
  String get actionMarkPaid => 'Tanda Sebagai Dibayar';

  @override
  String get actionApprove => 'Luluskan';

  @override
  String get actionReject => 'Tolak';

  @override
  String get actionExportPdf => 'Eksport PDF';

  @override
  String get actionMarkAllRead => 'Tanda semua sebagai dibaca';

  @override
  String get actionGotIt => 'Faham';

  @override
  String get labelStatus => 'Status';

  @override
  String get labelCategory => 'Kategori';

  @override
  String get labelType => 'Jenis';

  @override
  String get labelPeriod => 'Tempoh';

  @override
  String get labelFilters => 'Penapis';

  @override
  String get labelPaymentMethod => 'Kaedah Bayaran';

  @override
  String get labelPaymentSource => 'Sumber Bayaran';

  @override
  String get labelPaidBy => 'Dibayar oleh';

  @override
  String get labelRecordedBy => 'Direkod oleh';

  @override
  String get labelPerformedBy => 'Dilakukan Oleh';

  @override
  String get labelPurchasedBy => 'Dibeli Oleh';

  @override
  String get labelDueDate => 'Tarikh Akhir';

  @override
  String get labelCreated => 'Dicipta';

  @override
  String get labelDate => 'Tarikh';

  @override
  String get labelPurpose => 'Tujuan';

  @override
  String get labelReceiptProof => 'Resit / Bukti';

  @override
  String get labelReceiptProofRequired => 'Resit / Bukti (wajib)';

  @override
  String get labelMember => 'Ahli';

  @override
  String get labelMembers => 'Ahli';

  @override
  String get labelTreasurer => 'Bendahari';

  @override
  String get labelRole => 'Peranan';

  @override
  String get labelHouse => 'Rumah';

  @override
  String get labelHouseName => 'Nama Rumah';

  @override
  String get labelNotSet => 'Belum ditetapkan';

  @override
  String get labelNoEmail => 'Tiada e-mel';

  @override
  String get labelNet => 'Bersih';

  @override
  String get labelAmount => 'Jumlah';

  @override
  String get labelSupport => 'Sokongan';

  @override
  String get labelAbout => 'Perihal';

  @override
  String get emptyNoResults => 'Tiada hasil ditemui';

  @override
  String get emptyNoActivity => 'Tiada aktiviti lagi';

  @override
  String get emptyNoMembers => 'Tiada ahli lagi';

  @override
  String get emptyNoNotifications => 'Tiada pemberitahuan lagi';

  @override
  String get emptyNoExpenses => 'Tiada perbelanjaan lagi';

  @override
  String get emptyNoBills => 'Tiada bil lagi';

  @override
  String get errorFailedToLoad => 'Gagal memuatkan';

  @override
  String get errorFailedToLoadReceipt => 'Gagal memuatkan resit';

  @override
  String get errorNetwork => 'Tiada sambungan internet.';

  @override
  String get errorOffline => 'Anda di luar talian. Memaparkan data cache.';

  @override
  String get errorPermission => 'Anda tiada kebenaran untuk melakukannya.';

  @override
  String get errorNotFound => 'Kami tidak menjumpai item itu.';

  @override
  String get errorAuthentication => 'Sila log masuk semula.';

  @override
  String get errorUnexpected => 'Sesuatu tidak kena. Sila cuba lagi.';

  @override
  String get errorLoadFailed => 'Kami tidak dapat memuatkannya. Sila cuba lagi.';

  @override
  String get errorSaveFailed => 'Kami tidak dapat menyimpan perubahan anda. Sila cuba lagi.';

  @override
  String get houseAlreadyMember => 'Anda sudah menjadi ahli rumah ini.';

  @override
  String get houseJoinInvalidCode => 'Kod jemputan itu tidak sah.';

  @override
  String get errorActionFailed => 'Kami tidak dapat melengkapkan tindakan itu. Sila cuba lagi.';

  @override
  String get errorExpenseAlreadyReviewed => 'Perbelanjaan ini sudah disemak oleh orang lain. Muat semula untuk melihat keadaan terkini.';

  @override
  String get errorExpenseNotAwaitingReimbursement => 'Perbelanjaan ini tidak menunggu bayaran balik. Muat semula untuk melihat keadaan terkini.';

  @override
  String get errorBillAlreadyPaid => 'Bil ini sudah dibayar untuk tempoh itu. Muat semula untuk melihat keadaan terkini.';

  @override
  String get errorRecordMissing => 'Rekod ini tidak lagi wujud. Muat semula untuk melihat senarai terkini.';

  @override
  String errorInsufficientBalance(String amount, String balance) {
    return 'Baki tidak mencukupi. Bayaran $amount ini melebihi baki Akaun Pusat sebanyak $balance.';
  }

  @override
  String get authEmailLabel => 'E-mel';

  @override
  String get authEmailHint => 'anda@contoh.com';

  @override
  String get authEmailRequired => 'Sila masukkan e-mel anda';

  @override
  String get authEmailInvalid => 'Sila masukkan e-mel yang sah';

  @override
  String get authPasswordLabel => 'Kata Laluan';

  @override
  String get authPasswordRequired => 'Sila masukkan kata laluan anda';

  @override
  String get authCreatePasswordRequired => 'Sila masukkan kata laluan';

  @override
  String authPasswordMinLength(int count) {
    return 'Kata laluan mesti sekurang-kurangnya $count aksara';
  }

  @override
  String get authForgotPassword => 'Lupa Kata Laluan?';

  @override
  String get authSignIn => 'Log Masuk';

  @override
  String get authSignUp => 'Daftar';

  @override
  String get authOrContinueWith => 'atau teruskan dengan';

  @override
  String get authContinueWithGoogle => 'Teruskan dengan Google';

  @override
  String get authContinueWithApple => 'Teruskan dengan Apple';

  @override
  String get authNoAccountPrompt => 'Tiada akaun?';

  @override
  String get authHaveAccountPrompt => 'Sudah ada akaun?';

  @override
  String get authCreateAccount => 'Cipta Akaun';

  @override
  String get authRegisterSubtitle => 'Sertai rumah anda dan mula merekod perbelanjaan.';

  @override
  String get authFullNameLabel => 'Nama Penuh';

  @override
  String get authNameRequired => 'Sila masukkan nama anda';

  @override
  String get authConfirmPasswordLabel => 'Sahkan Kata Laluan';

  @override
  String get authConfirmPasswordRequired => 'Sila sahkan kata laluan anda';

  @override
  String get authPasswordsDoNotMatch => 'Kata laluan tidak sepadan';

  @override
  String get authResetPasswordTitle => 'Set Semula Kata Laluan';

  @override
  String get authResetYourPasswordTitle => 'Set semula kata laluan anda';

  @override
  String get authResetInstructions => 'Masukkan e-mel anda dan kami akan menghantar pautan selamat untuk set semula kata laluan anda.';

  @override
  String get authSending => 'Menghantar...';

  @override
  String get authSendResetLink => 'Hantar Pautan Set Semula';

  @override
  String get authBackToSignIn => 'Kembali ke Log Masuk';

  @override
  String get authEmailSentTitle => 'E-mel Dihantar!';

  @override
  String get authEmailSentBody => 'Semak peti masuk anda untuk pautan set semula kata laluan. Ia mungkin mengambil masa beberapa minit untuk tiba.';

  @override
  String get authVerifyingLink => 'Mengesahkan pautan set semula anda…';

  @override
  String get authResetLinkInvalidTitle => 'Pautan set semula tidak sah';

  @override
  String get authResetLinkInvalidBody => 'Pautan set semula ini tidak sah atau telah tamat tempoh.\nSila minta pautan baharu.';

  @override
  String get authRequestNewLink => 'Minta Pautan Baharu';

  @override
  String get authSetNewPasswordTitle => 'Tetapkan kata laluan baharu';

  @override
  String authSetNewPasswordBody(int count) {
    return 'Masukkan kata laluan baharu untuk akaun anda. Ia mesti sekurang-kurangnya $count aksara.';
  }

  @override
  String get authNewPasswordLabel => 'Kata laluan baharu';

  @override
  String get authNewPasswordRequired => 'Sila masukkan kata laluan baharu';

  @override
  String get authConfirmNewPasswordLabel => 'Sahkan kata laluan baharu';

  @override
  String get authConfirmNewPasswordRequired => 'Sila sahkan kata laluan baharu anda';

  @override
  String get authResetting => 'Menetapkan semula…';

  @override
  String get authPasswordUpdatedTitle => 'Kata Laluan Dikemas Kini!';

  @override
  String get authPasswordUpdatedBody => 'Kata laluan anda telah ditukar. Anda kini boleh log masuk dengan kata laluan baharu anda.';

  @override
  String get authErrorInvalidEmail => 'Alamat e-mel tidak sah.';

  @override
  String get authErrorUserDisabled => 'Akaun ini telah dinyahdayakan.';

  @override
  String get authErrorUserNotFound => 'Tiada akaun ditemui dengan e-mel ini.';

  @override
  String get authErrorInvalidCredentials => 'E-mel atau kata laluan tidak sah.';

  @override
  String get authErrorEmailAlreadyInUse => 'Akaun sudah wujud dengan e-mel ini.';

  @override
  String get authErrorOperationNotAllowed => 'Log masuk e-mel/kata laluan tidak diaktifkan.';

  @override
  String get authErrorTooManyRequests => 'Terlalu banyak percubaan. Sila cuba lagi kemudian.';

  @override
  String get authErrorWeakPassword => 'Kata laluan terlalu lemah.';

  @override
  String get authErrorInvalidActionCode => 'Pautan set semula ini tidak sah. Sila minta pautan baharu.';

  @override
  String get authErrorExpiredActionCode => 'Pautan set semula ini telah tamat tempoh. Sila minta pautan baharu.';

  @override
  String get authErrorNetworkFailed => 'Ralat rangkaian. Sila semak sambungan anda.';

  @override
  String get authErrorRequiresRecentLogin => 'Sila log masuk semula untuk meneruskan.';

  @override
  String get authErrorMissingActionCode => 'Pautan set semula ini tiada kodnya. Sila minta pautan baharu.';

  @override
  String get authErrorVerifyLinkFailed => 'Kami tidak dapat mengesahkan pautan set semula ini. Sila minta pautan baharu.';

  @override
  String get authErrorNotConfigured => 'Firebase tidak dikonfigurasikan.';

  @override
  String get expenseFieldTitle => 'Tajuk';

  @override
  String get expenseFieldTitleHint => 'Apa yang anda beli?';

  @override
  String get expenseFieldAmountRm => 'Jumlah (RM)';

  @override
  String get expenseFieldDescription => 'Keterangan (pilihan)';

  @override
  String get expenseFieldDescriptionHint => 'Tambah butiran lanjut...';

  @override
  String get expenseFieldRequired => 'Wajib';

  @override
  String get expenseFieldInvalidAmount => 'Masukkan jumlah yang sah';

  @override
  String get expenseFieldForMonth => 'Untuk bulan (pilihan)';

  @override
  String get expenseFieldForMonthHint => 'cth. 2026-09';

  @override
  String get expenseCategoriesLoadError => 'Gagal memuatkan kategori';

  @override
  String get expensePhotoError => 'Gagal mengambil gambar. Sila cuba lagi.';

  @override
  String get expenseRemoveReceiptTitle => 'Buang Resit';

  @override
  String get expenseRemoveReceiptMessage => 'Anda pasti mahu buang resit ini?';

  @override
  String get expensePreviewReceipt => 'Pratonton Resit';

  @override
  String get expensePreviewProof => 'Pratonton Bukti';

  @override
  String get expenseRemoveProofTitle => 'Buang Bukti';

  @override
  String get expenseRemoveProofMessage => 'Anda pasti mahu buang bukti ini?';

  @override
  String get expenseSubmit => 'Hantar Perbelanjaan';

  @override
  String get expenseSubmitting => 'Menghantar...';

  @override
  String get expenseSubmitted => 'Perbelanjaan dihantar';

  @override
  String get expensePaymentSourceReimburse => 'Peribadi (bayar balik kepada saya)';

  @override
  String get expensePaymentSourceReimburseInfo => 'Anda akan dibayar balik daripada Akaun Pusat selepas diluluskan.';

  @override
  String get expensePaymentSourceCentralInfo => 'Ini akan dibayar terus daripada Akaun Pusat.';

  @override
  String get expenseMenuTooltip => 'Menu';

  @override
  String get expenseFilterAll => 'Semua';

  @override
  String get expenseListLoadError => 'Gagal memuatkan perbelanjaan.';

  @override
  String get expenseEmptyDescription => 'Hantar perbelanjaan untuk bermula.';

  @override
  String expenseEmptyFiltered(String status) {
    return 'Belum ada perbelanjaan $status.';
  }

  @override
  String get expenseUnknownMember => 'Ahli Tidak Diketahui';

  @override
  String get depositRecordTitle => 'Rekod Deposit';

  @override
  String get depositSubtitle => 'Tambah wang ke Akaun Pusat.';

  @override
  String get depositPurposeLabel => 'Tujuan (pilihan)';

  @override
  String get depositPurposeHint => 'cth. Sewa Bulanan';

  @override
  String get depositNotesLabel => 'Nota (pilihan)';

  @override
  String get depositNotesHint => 'cth. Sewa Sep untuk Ahmad & Mei';

  @override
  String get depositRecorded => 'Deposit direkodkan';

  @override
  String get depositProofRequiredHint => 'Lampirkan resit atau bukti di atas untuk merekod deposit.';

  @override
  String get depositPurposeMonthlyRental => 'Sewa Bulanan';

  @override
  String get depositPurposeHouseContribution => 'Sumbangan Rumah';

  @override
  String get depositPurposeGeneralTopUp => 'Tambahan Am';

  @override
  String get depositPurposeUtilities => 'Utiliti';

  @override
  String get depositPurposeOther => 'Lain-lain';

  @override
  String get directPaymentSubtitle => 'Bayar terus daripada Akaun Pusat.';

  @override
  String get directPaymentTitleHint => 'Untuk apa?';

  @override
  String get directPaymentRecord => 'Rekod Bayaran';

  @override
  String get directPaymentRecorded => 'Bayaran direkodkan';

  @override
  String get directPaymentProofRequiredHint => 'Lampirkan resit atau bukti di atas untuk merekod bayaran.';

  @override
  String get houseCreateTitle => 'Cipta Rumah';

  @override
  String get houseCreateHeading => 'Cipta Rumah Anda';

  @override
  String get houseCreateSubtitle => 'Sediakan akaun rumah kongsi anda.';

  @override
  String get houseNameHint => 'cth. Rumah Taman Ampang';

  @override
  String get houseNameRequired => 'Sila masukkan nama rumah';

  @override
  String get houseCreateTreasurerNotice => 'Anda akan menjadi Bendahari rumah ini.';

  @override
  String get houseCreateAlreadyHave => 'Sudah ada rumah?';

  @override
  String get houseJoinWithCode => 'Sertai dengan Kod';

  @override
  String get houseJoinTitle => 'Sertai Rumah';

  @override
  String get houseJoinHeading => 'Masukkan Kod Jemputan';

  @override
  String get houseJoinSubtitle => 'Minta kod jemputan daripada Bendahari anda.';

  @override
  String get houseInviteCode => 'Kod Jemputan';

  @override
  String get houseInviteCodeRequired => 'Sila masukkan kod jemputan';

  @override
  String houseInviteCodeLength(int count) {
    return 'Kod mesti $count aksara';
  }

  @override
  String get houseJoinNoCode => 'Tiada kod?';

  @override
  String get houseJoinCreateLink => 'Cipta Rumah';

  @override
  String get houseErrorNotAuthenticated => 'Belum log masuk.';

  @override
  String get houseErrorNoActiveHouse => 'Tiada rumah aktif.';

  @override
  String get houseErrorOnlyTreasurerRemove => 'Hanya Bendahari boleh membuang ahli.';

  @override
  String get houseErrorCannotRemoveTreasurer => 'Bendahari tidak boleh dibuang. Pindahkan pemilikan terlebih dahulu.';

  @override
  String get houseErrorUnexpected => 'Ralat tidak dijangka berlaku.';

  @override
  String get houseErrorFirebaseNotConfigured => 'Firebase belum dikonfigurasikan.';

  @override
  String get houseMembersLoadFailed => 'Gagal memuatkan senarai ahli.';

  @override
  String get houseNoMembersDescription => 'Kongsi kod jemputan anda untuk menambah ahli rumah.';

  @override
  String get houseThisMember => 'Ahli ini';

  @override
  String get houseRemoveMemberTitle => 'Buang Ahli';

  @override
  String get houseRemoveMemberTooltip => 'Buang ahli';

  @override
  String houseRemoveMemberBody(String name, String house) {
    return 'Buang $name dari $house?\n\nMereka tidak lagi menjadi sebahagian daripada rumah ini dan tidak boleh mengakses datanya. Akaun serta semua sejarah perbelanjaan dan transaksi mereka akan dikekalkan.';
  }

  @override
  String houseMemberRemoved(String name) {
    return '$name telah dibuang dari rumah.';
  }

  @override
  String get houseTransferTitle => 'Pindah Pemilikan';

  @override
  String houseTransferBody(String name, String house) {
    return 'Jadikan $name Bendahari baharu $house?\n\nAnda akan menjadi Ahli biasa dan tidak lagi boleh meluluskan perbelanjaan, merekod deposit atau menguruskan rumah ini sehingga pemilikan dipindahkan semula kepada anda.';
  }

  @override
  String get houseTransferConfirm => 'Pindah';

  @override
  String houseTransferDone(String name) {
    return '$name kini Bendahari.';
  }

  @override
  String get houseTransferSheetTitle => 'Pindah kepada…';

  @override
  String get houseTransferSheetSubtitle => 'Jadikan ahli ini Bendahari';

  @override
  String get houseLeaveTitle => 'Keluar Rumah';

  @override
  String houseLeaveBody(String house) {
    return 'Keluar dari $house?\n\nAnda tidak lagi boleh melihat rumah ini atau menghantar perbelanjaan sehingga dijemput semula. Akaun dan semua rekod lalu anda akan dikekalkan.';
  }

  @override
  String get houseLeaveConfirm => 'Keluar';

  @override
  String houseLeaveDone(String house) {
    return 'Anda telah keluar dari $house.';
  }

  @override
  String get houseYourMembership => 'Keahlian anda';

  @override
  String get houseTreasurerOnlyMember => 'Anda Bendahari dan pada masa ini satu-satunya ahli. Ahli lain perlu menyertai dahulu sebelum pemilikan boleh dipindahkan.';

  @override
  String get houseTreasurerCanTransfer => 'Anda Bendahari. Pindahkan pemilikan kepada ahli lain sebelum anda boleh keluar dari rumah ini.';

  @override
  String get houseTransferOwnership => 'Pindah pemilikan';

  @override
  String get houseMemberCanLeave => 'Anda seorang Ahli. Anda boleh keluar dari rumah ini pada bila-bila masa; akaun dan rekod lalu anda akan dikekalkan.';

  @override
  String get houseLeaveHouse => 'Keluar rumah';

  @override
  String get houseInviteShareHint => 'Kongsi kod ini dengan ahli rumah untuk menyertai.';

  @override
  String get houseInviteCodeCopied => 'Kod jemputan disalin!';

  @override
  String houseShareMessage(String code) {
    return 'Sertai rumah saya di Rental Ledger!\n\nKod Jemputan: $code';
  }

  @override
  String get houseShareSubject => 'Jemputan Rental Ledger';

  @override
  String houseJoinedOn(String date) {
    return 'Sertai pada $date';
  }

  @override
  String get houseMakeTreasurer => 'Jadikan bendahari';

  @override
  String get actionMenu => 'Menu';

  @override
  String get actionSignOutConfirm => 'Anda pasti mahu log keluar?';

  @override
  String get reportLoadFailed => 'Tidak dapat memuatkan laporan.';

  @override
  String get reportMoneyIn => 'Wang Masuk';

  @override
  String get reportMoneyOut => 'Wang Keluar';

  @override
  String get reportCurrentBalance => 'Baki Semasa';

  @override
  String reportCentralBalanceAllTime(String amount) {
    return 'Baki Akaun Pusat (sepanjang masa): $amount';
  }

  @override
  String get reportInsights => 'Analisis';

  @override
  String get reportWhereMoneyGoes => 'Ke Mana Wang Pergi';

  @override
  String get reportCategoryBreakdown => 'Pecahan Kategori';

  @override
  String get reportMonthlyTrend => 'Trend Bulanan';

  @override
  String get reportEmptyTitle => 'Tiada laporan lagi';

  @override
  String get reportEmptyDescription => 'Deposit dan perbelanjaan akan muncul di sini apabila direkodkan.';

  @override
  String get reportEmptyPeriodTitle => 'Tiada apa-apa dalam tempoh ini';

  @override
  String get reportEmptyPeriodDescription => 'Tiada deposit, tuntutan perbelanjaan atau bayaran balik dalam tempoh yang dipilih.';

  @override
  String get reportShowAllTime => 'Tunjukkan sepanjang masa';

  @override
  String get reportChoosePeriod => 'Pilih tempoh laporan';

  @override
  String get reportHighestExpenseCategory => 'Kategori Perbelanjaan Tertinggi';

  @override
  String get reportLargestExpenseClaim => 'Tuntutan Perbelanjaan Terbesar';

  @override
  String get reportExpenseReimbursements => 'Bayaran Balik Perbelanjaan';

  @override
  String get reportPendingReimbursements => 'Bayaran Balik Menunggu';

  @override
  String get reportAverageMonthlyExpense => 'Purata Perbelanjaan Bulanan';

  @override
  String get reportAverageDeposit => 'Purata Deposit';

  @override
  String get reportLargestDeposit => 'Deposit Terbesar';

  @override
  String get reportBillsPaid => 'Bil Dibayar';

  @override
  String get reportBillsPending => 'Bil Menunggu';

  @override
  String get reportMoneyOutReimbursements => 'Bayaran balik perbelanjaan';

  @override
  String get reportMoneyOutDirectPayments => 'Bayaran terus';

  @override
  String get reportMoneyOutBillPayments => 'Bayaran bil';

  @override
  String get reportMoneyOutAdjustments => 'Pelarasan';

  @override
  String get reportMoneyOutOther => 'Lain-lain';

  @override
  String reportMoneyOutFrom(String amount) {
    return 'Daripada $amount Wang Keluar';
  }

  @override
  String get reportTapSliceHint => 'Ketik hirisan untuk lihat butiran';

  @override
  String get settingsUser => 'Pengguna';

  @override
  String get settingsEditProfile => 'Sunting Profil';

  @override
  String get settingsInviteCode => 'Kod Jemputan';

  @override
  String get settingsInviteCodeCopied => 'Kod jemputan disalin';

  @override
  String get settingsAccount => 'Akaun';

  @override
  String get settingsAppearance => 'Penampilan';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Lalai sistem';

  @override
  String get settingsThemeLight => 'Cerah';

  @override
  String get settingsThemeDark => 'Gelap';

  @override
  String get settingsThemeSystemHint => 'Ikut tetapan peranti atau pelayar anda';

  @override
  String get settingsPushNotifications => 'Pemberitahuan Push';

  @override
  String get settingsNotificationsSubtitle => 'Terima makluman untuk kemas kini perbelanjaan';

  @override
  String get settingsPushThisDevice => 'Peranti ini';

  @override
  String get settingsPushStatusOn => 'Pemberitahuan dihidupkan untuk pelayar ini';

  @override
  String get settingsPushStatusOff => 'Ketik Hidupkan untuk menerima makluman walaupun aplikasi ditutup. Pada iPhone/iPad, tambah aplikasi ini ke Skrin Utama dahulu.';

  @override
  String get settingsPushStatusBlocked => 'Disekat. Benarkan pemberitahuan untuk laman ini dalam tetapan pelayar anda.';

  @override
  String get settingsPushEnable => 'Hidupkan';

  @override
  String get settingsPushEnabledToast => 'Pemberitahuan dihidupkan pada peranti ini';

  @override
  String get settingsPreferences => 'Keutamaan';

  @override
  String get settingsCurrency => 'Mata Wang';

  @override
  String get settingsHelpCenter => 'Pusat Bantuan';

  @override
  String settingsVersion(String version) {
    return 'Versi $version';
  }

  @override
  String get settingsAboutLegalese => 'Aplikasi pengurusan kewangan rumah.';

  @override
  String get settingsHelpIntro => 'Jejak perbelanjaan rumah bersama dengan mudah.';

  @override
  String get settingsHelpSubmitExpenses => 'Hantar Perbelanjaan';

  @override
  String get settingsHelpSubmitExpensesDesc => 'Ketik + untuk tambah tuntutan perbelanjaan baharu dengan resit.';

  @override
  String get settingsHelpTreasurerApproval => 'Kelulusan Bendahari';

  @override
  String get settingsHelpTreasurerApprovalDesc => 'Bendahari menyemak dan meluluskan perbelanjaan.';

  @override
  String get settingsHelpReimbursements => 'Bayaran Balik';

  @override
  String get settingsHelpReimbursementsDesc => 'Setelah diluluskan dan dibayar, anda akan dibayar balik.';

  @override
  String get settingsHelpInviteHousemates => 'Jemput Rakan Serumah';

  @override
  String get settingsHelpInviteHousematesDesc => 'Kongsi kod jemputan anda dari skrin Ahli.';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileChangePhoto => 'Tukar Gambar';

  @override
  String get profilePhotoFailed => 'Tidak dapat mengambil gambar. Sila cuba lagi.';

  @override
  String get profileDisplayName => 'Nama Paparan';

  @override
  String get profileDisplayNameHint => 'Masukkan nama anda';

  @override
  String get profileDisplayNameEmpty => 'Nama paparan tidak boleh kosong.';

  @override
  String get profileEmail => 'E-mel';

  @override
  String get profileHouseAndAccount => 'Rumah & Akaun';

  @override
  String get profileJoined => 'Menyertai';

  @override
  String get profileUpdated => 'Profil dikemas kini';

  @override
  String get profileUpdateFailed => 'Tidak dapat mengemas kini profil anda. Sila cuba lagi.';

  @override
  String get profileSaving => 'Menyimpan…';

  @override
  String get actionConfirm => 'Sahkan';

  @override
  String get actionViewReceipt => 'Lihat Resit';

  @override
  String get actionPreviewReceipt => 'Pratonton Resit';

  @override
  String get actionRemindTreasurer => 'Ingatkan Bendahari';

  @override
  String get actionReminderSent => 'Peringatan dihantar kepada Bendahari';

  @override
  String get billDetailsTitle => 'Butiran Bil';

  @override
  String get billLoadFailed => 'Tidak dapat memuatkan bil.';

  @override
  String get billNotFound => 'Bil tidak ditemui.';

  @override
  String get billStatusUpcoming => 'Bil Akan Datang';

  @override
  String get billRecurring => 'Berulang';

  @override
  String get billRecurringYes => 'Ya — berulang setiap bulan';

  @override
  String get billReminderOnly => 'Peringatan';

  @override
  String get billConfirmPayment => 'Sahkan Bayaran';

  @override
  String billMarkPaidConfirm(String title) {
    return 'Tandakan \"$title\" sebagai dibayar?';
  }

  @override
  String get billRollsToNextMonth => 'Melungsurkan bil ke bulan hadapan.';

  @override
  String get billSettles => 'Menjelaskan bil ini.';

  @override
  String get billPaymentCoversMonth => 'Bayaran meliputi bulan';

  @override
  String get billPaymentCoversMonthHint => 'cth. 2026-09';

  @override
  String get billProofRequired => 'Resit atau bukti diperlukan untuk bil yang mempunyai jumlah.';

  @override
  String get billTreasurerOnlyMarkPaid => 'Hanya Bendahari boleh menandakan bil sebagai dibayar.';

  @override
  String get billMarkPaidFailed => 'Tidak dapat menandakan bil sebagai dibayar. Sila cuba lagi.';

  @override
  String get billMarkedPaid => 'Bil ditandakan sebagai dibayar';

  @override
  String get billDeleteTitle => 'Padam Bil?';

  @override
  String get billDeleted => 'Bil dipadam';

  @override
  String get billUpdated => 'Bil dikemas kini';

  @override
  String billDueOn(String date) {
    return 'Perlu dibayar $date';
  }

  @override
  String billDueDateLabel(String date) {
    return 'Perlu dibayar: $date';
  }

  @override
  String get depositDetailsTitle => 'Butiran Deposit';

  @override
  String get directPaymentDetailsTitle => 'Butiran Bayaran Terus';

  @override
  String txnByPerson(String name) {
    return 'oleh $name';
  }

  @override
  String get txnCoversMonth => 'Meliputi Bulan';

  @override
  String get expenseDetailsTitle => 'Butiran Perbelanjaan';

  @override
  String get expenseLoadFailed => 'Tidak dapat memuatkan perbelanjaan.';

  @override
  String get expenseNotFound => 'Perbelanjaan tidak ditemui.';

  @override
  String expensePurchasedByPerson(String name) {
    return 'Dibeli oleh $name';
  }

  @override
  String get expenseReceiptUnavailable => 'Resit tidak tersedia';

  @override
  String expenseRejectReason(String reason) {
    return 'Sebab: $reason';
  }

  @override
  String get expenseDescriptionSection => 'Keterangan';

  @override
  String get expenseTimeline => 'Garis Masa';

  @override
  String get expenseTreasurerActions => 'Tindakan Bendahari';

  @override
  String expenseMarkPaidConfirm(String title) {
    return 'Tandakan \"$title\" sebagai dibayar balik daripada Akaun Pusat?';
  }

  @override
  String get expenseDeleteTitle => 'Padam Perbelanjaan?';

  @override
  String expenseDeleteConfirm(String title) {
    return 'Padam \"$title\"? Tindakan ini tidak boleh dibatalkan.';
  }

  @override
  String get expenseDeleted => 'Perbelanjaan dipadam';

  @override
  String get expenseRejectTitle => 'Tolak Perbelanjaan';

  @override
  String expenseRejectConfirm(String title) {
    return 'Tolak \"$title\"?';
  }

  @override
  String get expenseRejectReasonLabel => 'Sebab (pilihan)';

  @override
  String get expenseRejectReasonHint => 'cth. Resit kabur, sila muat naik yang lebih jelas.';

  @override
  String get expenseTimelineWaiting => 'Menunggu...';

  @override
  String get expenseRemindOnlySubmitter => 'Hanya penghantar boleh mengingatkan Bendahari.';

  @override
  String get expenseTreasurerNotFound => 'Tidak dapat menjumpai Bendahari.';

  @override
  String get expensePhotoPickFailed => 'Tidak dapat memilih foto. Sila cuba lagi.';

  @override
  String get expenseUpdateFailed => 'Tidak dapat mengemas kini. Sila cuba lagi.';

  @override
  String get expenseEditTitle => 'Sunting Perbelanjaan';

  @override
  String get expenseAmountRm => 'Jumlah (RM)';

  @override
  String get expenseDescriptionOptional => 'Keterangan (pilihan)';

  @override
  String get expenseReceiptNewSelected => 'Resit baharu dipilih — akan menggantikan yang semasa apabila disimpan.';

  @override
  String get expenseReceiptWillRemove => 'Resit akan dibuang apabila disimpan.';

  @override
  String get expenseReceiptCurrent => 'Resit semasa dilampirkan.';

  @override
  String get expenseReceiptNone => 'Tiada resit dilampirkan.';

  @override
  String get expenseRemoveReceipt => 'Buang resit';

  @override
  String get dashboardProfileLabel => 'Profil';

  @override
  String get dashboardLoadError => 'Tidak dapat memuatkan papan pemuka.';

  @override
  String dashboardWelcomeTitle(String appName) {
    return 'Selamat datang ke $appName!';
  }

  @override
  String get dashboardOnboardingDescription => 'Cipta atau sertai rumah untuk mula menjejak perbelanjaan.';

  @override
  String get dashboardCreateHouse => 'Cipta Rumah';

  @override
  String get dashboardJoinWithCode => 'Sertai dengan Kod';

  @override
  String get dashboardMoneyIn => 'Wang Masuk';

  @override
  String get dashboardMoneyOut => 'Wang Keluar';

  @override
  String get dashboardPendingItems => 'Item Menunggu';

  @override
  String get dashboardPendingItemsEmpty => 'Tiada item menunggu';

  @override
  String get dashboardPendingItemsEmptyDescription => 'Perbelanjaan yang dihantar dan diluluskan akan dipaparkan di sini.';

  @override
  String get dashboardWaitingForReimbursement => 'Diluluskan — menunggu bayaran balik';

  @override
  String get dashboardWaitingForApproval => 'Menunggu kelulusan Bendahari';

  @override
  String get dashboardRecentActivity => 'Aktiviti Terkini';

  @override
  String get dashboardRecentActivityEmptyDescription => 'Transaksi, perbelanjaan dan deposit akan dipaparkan di sini.';

  @override
  String get commonUnknownMember => 'Ahli Tidak Dikenali';

  @override
  String get historySearchHint => 'Cari mengikut nama...';

  @override
  String get historyLoadError => 'Tidak dapat memuatkan sejarah.';

  @override
  String get historyNoResultsHint => 'Cuba laraskan carian atau penapis anda.';

  @override
  String get historyEmptyDescription => 'Deposit, perbelanjaan dan bil akan dipaparkan di sini.';

  @override
  String get historyExpenseSubmitted => 'Perbelanjaan Dihantar';

  @override
  String get historyExpenseApproved => 'Perbelanjaan Diluluskan';

  @override
  String get historyExpenseRejected => 'Perbelanjaan Ditolak';

  @override
  String get historyTypeExpensePaid => 'Perbelanjaan Dibayar';

  @override
  String get historyBillCreated => 'Bil Dicipta';

  @override
  String get historyBillPaid => 'Bil Dibayar';

  @override
  String get historyUpcomingBill => 'Bil Akan Datang';

  @override
  String get statusUpcoming => 'Akan Datang';

  @override
  String get billUpcomingBills => 'Bil Akan Datang';

  @override
  String get billAdd => 'Tambah Bil';

  @override
  String get billListLoadFailed => 'Tidak dapat memuatkan bil. Tarik untuk muat semula.';

  @override
  String get billNoneUpcoming => 'Tiada bil akan datang';

  @override
  String get billNoneUpcomingHint => 'Tambah bil berulang untuk menjejaknya di sini.';

  @override
  String get billEditTooltip => 'Sunting bil';

  @override
  String get billDeleteTooltip => 'Padam bil';

  @override
  String get billReminderOn => 'Peringatan Aktif';

  @override
  String get billSetReminder => 'Set Peringatan';

  @override
  String get billMarkPaid => 'Tanda Dibayar';

  @override
  String get billEditTitle => 'Sunting Bil';

  @override
  String get billName => 'Nama bil';

  @override
  String get billAmountRmOptional => 'Jumlah (RM) — pilihan';

  @override
  String get billAmountHint => 'Biarkan kosong untuk peringatan sahaja';

  @override
  String get billRepeatMonthly => 'Ulang setiap bulan';

  @override
  String get billRepeatMonthlyHint => 'Cipta bil seterusnya secara automatik setiap bulan';

  @override
  String get billRollNextMonth => 'Ini akan melungsurkan bil ke bulan hadapan.';

  @override
  String get billWillBeMarkedPaid => 'Bil ini akan ditandakan sebagai dibayar.';

  @override
  String get billHistorySearchHint => 'Cari mengikut tajuk bil...';

  @override
  String get billHistoryLoadFailed => 'Tidak dapat memuatkan sejarah bil.';

  @override
  String get billHistoryEmpty => 'Tiada bil lagi';

  @override
  String get billHistoryEmptyDescription => 'Bil yang ditambah ke rumah ini akan dipaparkan di sini.';

  @override
  String get billHistoryMemberFilterEmpty => 'Bil hanya menyatakan ahli apabila bayaran direkodkan terhadapnya, jadi penapis ini menyembunyikan bil akan datang dan bil yang dijelaskan tanpa rekod bayaran.';

  @override
  String billHistoryCoversPeriod(String period) {
    return 'Meliputi $period';
  }

  @override
  String billHistoryPaymentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bayaran',
    );
    return '$_temp0';
  }

  @override
  String get notifAllMarkedRead => 'Semua ditandakan dibaca';

  @override
  String get notifLoadFailed => 'Tidak dapat memuatkan pemberitahuan.';

  @override
  String get notifEmptyDescription => 'Kemas kini tentang perbelanjaan, bayaran dan kelulusan akan dipaparkan di sini.';

  @override
  String get timeThisWeek => 'Minggu Ini';

  @override
  String get timeEarlier => 'Terdahulu';

  @override
  String get navMenu => 'Menu';

  @override
  String get labelReceipt => 'Resit';

  @override
  String get errorNoHouse => 'Tiada rumah ditemui.';

  @override
  String get errorNotSignedIn => 'Belum log masuk.';

  @override
  String get errorBillCreateFailed => 'Gagal mencipta bil.';

  @override
  String get labelTotal => 'Jumlah Keseluruhan';

  @override
  String get reportPdfSubtitle => 'Laporan Kewangan';

  @override
  String get reportPdfPeriod => 'Tempoh';

  @override
  String reportPdfGeneratedOn(String date) {
    return 'Dijana pada $date';
  }

  @override
  String get reportPdfSummary => 'Ringkasan';

  @override
  String get reportPdfTotalExpenses => 'Jumlah Perbelanjaan';

  @override
  String get reportPdfTotalDeposits => 'Jumlah Deposit';

  @override
  String get reportPdfNetFlow => 'Aliran Bersih';

  @override
  String get reportPdfMonth => 'Bulan';

  @override
  String get reportPdfShare => 'Peratus';

  @override
  String get reportPdfNoData => 'Tiada data laporan untuk tempoh ini.';

  @override
  String get reportPdfFailed => 'Tidak dapat menjana PDF. Sila cuba lagi.';

  @override
  String get errorDepositRequestAlreadyReviewed => 'Deposit ini sudah disemak atau dibatalkan. Muat semula untuk melihat keadaan terkini.';

  @override
  String get actionSubmitDeposit => 'Hantar Deposit';

  @override
  String get depositSubmitSubtitle => 'Rekodkan wang yang anda bayar ke dalam Akaun Pusat. Bendahari akan menyemaknya sebelum ia ditambah ke baki.';

  @override
  String get depositSubmittedForApproval => 'Deposit dihantar untuk kelulusan Bendahari';

  @override
  String get depositSubmitProofRequiredHint => 'Lampirkan resit atau bukti di atas untuk menghantar deposit.';

  @override
  String get depositPaidByYou => 'Anda';

  @override
  String get depositRequestTitle => 'Permohonan Deposit';

  @override
  String get depositRequestWaitingApproval => 'Deposit · menunggu kelulusan Bendahari';

  @override
  String depositRequestSubmittedBy(String name) {
    return 'Dihantar oleh $name';
  }

  @override
  String get depositRequestApproveTitle => 'Luluskan Deposit';

  @override
  String depositRequestApproveConfirm(String amount, String name) {
    return 'Tambah $amount daripada $name ke Akaun Pusat?';
  }

  @override
  String get depositRequestRejectTitle => 'Tolak Deposit';

  @override
  String depositRequestRejectConfirm(String amount, String name) {
    return 'Tolak deposit $amount daripada $name?';
  }

  @override
  String get depositRequestApproved => 'Deposit diluluskan dan ditambah ke baki';

  @override
  String get depositRequestRejected => 'Deposit ditolak';

  @override
  String get actionCancelRequest => 'Batal Permohonan';

  @override
  String get depositRequestCancelTitle => 'Batal Permohonan Deposit';

  @override
  String depositRequestCancelConfirm(String amount) {
    return 'Tarik balik deposit $amount anda yang belum diluluskan? Tindakan ini tidak boleh dibatalkan.';
  }

  @override
  String get depositRequestKeep => 'Simpan';

  @override
  String get depositRequestCancelled => 'Permohonan deposit dibatalkan';

  @override
  String get depositRequestAwaitingReview => 'Menunggu Bendahari menyemak deposit ini.';
}
