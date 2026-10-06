/**
 * Bill-reminder decision logic for the daily `sendBillReminders` job.
 *
 * Kept free of firebase-admin / firebase-functions (like membership_index.js)
 * so the day math and the idempotency key can be unit-tested with plain node.
 *
 * ── How a bill's due date is interpreted ──
 * The app stores `dueDate` as a Firestore Timestamp built from a LOCAL
 * DateTime picked on the user's device (midnight local). Comparing raw UTC
 * instants would put a Malaysian "10 Oct" bill on 9 Oct, so every comparison
 * here is done on CALENDAR DATES in the house's time zone.
 *
 * ── Recurring bills ──
 * A recurring bill is a template whose `dueDate` always holds the CURRENT
 * cycle: "Mark Paid" rolls it forward one month and keeps `isPaid: false`
 * (see markBillPaid in expense_remote_datasource.dart). So the stored dueDate
 * is exactly the date to remind about for both one-off and recurring bills,
 * and because the idempotency key includes that due date, next month's cycle
 * gets its own fresh set of reminders after a roll-forward.
 */

/** Days-before-due on which a reminder is sent. */
const REMINDER_DAYS = [7, 3, 2, 1];

/**
 * Time zone used to decide what "today" and a bill's due date are. Houses do
 * not store a time zone; the app's default currency is MYR, so Malaysia time.
 */
const DEFAULT_TIME_ZONE = 'Asia/Kuala_Lumpur';

/** Notification `type` written for a bill reminder. Mirrors
 * FirestoreConstants.notificationBillReminder in the Flutter app. */
const NOTIFICATION_TYPE_BILL_REMINDER = 'Bill Reminder';

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/**
 * The calendar date of [date] in [timeZone], as 'YYYY-MM-DD'.
 * @param {Date} date
 * @param {string} timeZone IANA zone name.
 */
function ymdInZone(date, timeZone = DEFAULT_TIME_ZONE) {
  // en-CA formats as YYYY-MM-DD.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date);
}

/** Whole calendar days from ymd [from] to ymd [to] (negative if [to] is earlier). */
function daysBetweenYmd(from, to) {
  const toUtc = (ymd) => {
    const [y, m, d] = ymd.split('-').map(Number);
    return Date.UTC(y, m - 1, d);
  };
  return Math.round((toUtc(to) - toUtc(from)) / MS_PER_DAY);
}

/**
 * Decides whether [bill] gets a reminder [now], and which one.
 *
 * @param {object} bill raw bill document data (`dueDate` may be a Firestore
 *   Timestamp — anything with `toDate()` — or a Date).
 * @param {Date} now
 * @param {{timeZone?: string, requireReminderFlag?: boolean}} [opts]
 * @returns {{daysBefore: number, dueYmd: string} | null}
 */
function reminderFor(bill, now, opts = {}) {
  const timeZone = opts.timeZone || DEFAULT_TIME_ZONE;
  const requireReminderFlag = opts.requireReminderFlag !== false;

  if (!bill || !bill.houseId) return null;
  if (bill.isActive === false) return null;
  // Paid one-off bills are done. (Recurring bills are never left isPaid:true —
  // paying rolls them forward — so this does not skip a recurring cycle.)
  if (bill.isPaid === true) return null;
  // The bill's existing "Set Reminder" toggle decides whether it is reminded.
  if (requireReminderFlag && bill.reminderEnabled !== true) return null;

  const raw = bill.dueDate;
  const due = raw && typeof raw.toDate === 'function' ? raw.toDate() : raw;
  if (!(due instanceof Date) || Number.isNaN(due.getTime())) return null;

  const dueYmd = ymdInZone(due, timeZone);
  const daysBefore = daysBetweenYmd(ymdInZone(now, timeZone), dueYmd);
  if (!REMINDER_DAYS.includes(daysBefore)) return null;

  return { daysBefore, dueYmd };
}

/**
 * Deterministic notification document id. Creating with this id (Firestore
 * `create()`, which fails if the doc exists) makes a re-run or retried job a
 * no-op instead of a duplicate push. The due date is part of the key so a
 * recurring bill's next cycle is reminded afresh.
 */
function reminderDocId(billId, dueYmd, daysBefore, userId) {
  return `billReminder_${billId}_${dueYmd}_${daysBefore}d_${userId}`;
}

/** Title + body for the reminder. Stored in English, like every other
 * notification the app writes. */
function reminderCopy(bill, daysBefore, dueYmd) {
  const when = daysBefore === 1 ? 'tomorrow' : `in ${daysBefore} days`;
  const [y, m, d] = dueYmd.split('-').map(Number);
  const dueLabel = new Intl.DateTimeFormat('en-GB', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    timeZone: 'UTC',
  }).format(new Date(Date.UTC(y, m - 1, d)));
  const title = bill.title || 'Bill';
  return {
    title: `Bill due ${when}: ${title}`,
    body: `"${title}" is due ${when} (${dueLabel}).`,
  };
}

module.exports = {
  REMINDER_DAYS,
  DEFAULT_TIME_ZONE,
  NOTIFICATION_TYPE_BILL_REMINDER,
  ymdInZone,
  daysBetweenYmd,
  reminderFor,
  reminderDocId,
  reminderCopy,
};
