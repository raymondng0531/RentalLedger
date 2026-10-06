/**
 * Tests for the daily bill-reminder decision logic.
 *
 * Run:
 *   cd functions && npm test
 */
const assert = require('node:assert');
const { test, describe } = require('node:test');

const {
  ymdInZone,
  daysBetweenYmd,
  reminderFor,
  reminderDocId,
  reminderCopy,
} = require('./bill_reminders');

/** A bill due at local midnight (UTC+8) on [ymd], as the app stores it. */
const dueAtMyMidnight = (ymd) => new Date(`${ymd}T00:00:00+08:00`);
/** A Firestore-Timestamp-like wrapper. */
const ts = (date) => ({ toDate: () => date });

const bill = (dueYmd, extra = {}) => ({
  houseId: 'h1',
  title: 'Electricity',
  dueDate: ts(dueAtMyMidnight(dueYmd)),
  isActive: true,
  isPaid: false,
  isRecurring: false,
  reminderEnabled: true,
  ...extra,
});

// The job runs at 09:00 Malaysia time = 01:00 UTC.
const runAt = (ymd) => new Date(`${ymd}T09:00:00+08:00`);

describe('calendar-day math', () => {
  test('dates are taken in Malaysia time, not UTC', () => {
    // Midnight 10 Oct in MY is 16:00 UTC on 9 Oct.
    assert.strictEqual(ymdInZone(dueAtMyMidnight('2026-10-10')), '2026-10-10');
  });

  test('daysBetweenYmd crosses month and year boundaries', () => {
    assert.strictEqual(daysBetweenYmd('2026-10-31', '2026-11-01'), 1);
    assert.strictEqual(daysBetweenYmd('2026-12-25', '2027-01-01'), 7);
    assert.strictEqual(daysBetweenYmd('2028-02-28', '2028-03-01'), 2); // leap year
    assert.strictEqual(daysBetweenYmd('2026-10-10', '2026-10-09'), -1);
  });
});

describe('reminderFor — which days fire', () => {
  for (const days of [7, 3, 2, 1]) {
    test(`fires ${days} day(s) before`, () => {
      const r = reminderFor(bill('2026-10-20'), runAt(`2026-10-${20 - days}`));
      assert.deepStrictEqual(r, { daysBefore: days, dueYmd: '2026-10-20' });
    });
  }

  for (const days of [0, 4, 5, 6, 8, -1]) {
    test(`does not fire ${days} day(s) before`, () => {
      const ymd = new Date(Date.UTC(2026, 9, 20 - days)).toISOString().slice(0, 10);
      assert.strictEqual(reminderFor(bill('2026-10-20'), runAt(ymd)), null);
    });
  }

  test('late-evening run still uses the Malaysian calendar day', () => {
    // 23:30 MY on 19 Oct is 15:30 UTC on 19 Oct; due 20 Oct → tomorrow.
    const r = reminderFor(bill('2026-10-20'), new Date('2026-10-19T23:30:00+08:00'));
    assert.strictEqual(r.daysBefore, 1);
  });

  test('accepts a plain Date dueDate too', () => {
    const b = bill('2026-10-20', { dueDate: dueAtMyMidnight('2026-10-20') });
    assert.strictEqual(reminderFor(b, runAt('2026-10-13')).daysBefore, 7);
  });
});

describe('reminderFor — which bills are skipped', () => {
  const day = runAt('2026-10-17'); // 3 days before 20 Oct

  test('paid one-off bill', () => {
    assert.strictEqual(reminderFor(bill('2026-10-20', { isPaid: true }), day), null);
  });

  test('inactive bill', () => {
    assert.strictEqual(reminderFor(bill('2026-10-20', { isActive: false }), day), null);
  });

  test('reminder toggle off (or missing) by default', () => {
    assert.strictEqual(reminderFor(bill('2026-10-20', { reminderEnabled: false }), day), null);
    const noFlag = bill('2026-10-20');
    delete noFlag.reminderEnabled;
    assert.strictEqual(reminderFor(noFlag, day), null);
  });

  test('reminder toggle can be ignored via requireReminderFlag:false', () => {
    const r = reminderFor(bill('2026-10-20', { reminderEnabled: false }), day, {
      requireReminderFlag: false,
    });
    assert.strictEqual(r.daysBefore, 3);
  });

  test('missing / malformed due date', () => {
    assert.strictEqual(reminderFor(bill('2026-10-20', { dueDate: null }), day), null);
    assert.strictEqual(reminderFor(bill('2026-10-20', { dueDate: 'x' }), day), null);
    assert.strictEqual(reminderFor({ ...bill('2026-10-20'), houseId: '' }, day), null);
  });
});

describe('recurring bills', () => {
  test('a recurring bill is reminded from its current-cycle due date', () => {
    const b = bill('2026-10-31', { isRecurring: true });
    assert.strictEqual(reminderFor(b, runAt('2026-10-24')).daysBefore, 7);
  });

  test('after Mark Paid rolls it forward, the next cycle is reminded with a new key', () => {
    // October cycle, 1 day before.
    const oct = bill('2026-10-31', { isRecurring: true });
    const r1 = reminderFor(oct, runAt('2026-10-30'));
    // Paid → template rolled to 30 Nov (clamped), still isPaid:false.
    const nov = bill('2026-11-30', { isRecurring: true });
    const r2 = reminderFor(nov, runAt('2026-11-29'));
    assert.strictEqual(r1.daysBefore, 1);
    assert.strictEqual(r2.daysBefore, 1);
    assert.notStrictEqual(
      reminderDocId('b1', r1.dueYmd, r1.daysBefore, 'u1'),
      reminderDocId('b1', r2.dueYmd, r2.daysBefore, 'u1'),
    );
  });
});

describe('idempotency key', () => {
  test('same bill + due date + day + user → same id (a re-run is a no-op)', () => {
    assert.strictEqual(
      reminderDocId('b1', '2026-10-20', 3, 'u1'),
      reminderDocId('b1', '2026-10-20', 3, 'u1'),
    );
  });

  test('each reminder day gets its own id', () => {
    const ids = new Set([7, 3, 2, 1].map((d) => reminderDocId('b1', '2026-10-20', d, 'u1')));
    assert.strictEqual(ids.size, 4);
  });

  test('ids differ by bill and by recipient', () => {
    assert.notStrictEqual(
      reminderDocId('b1', '2026-10-20', 3, 'u1'),
      reminderDocId('b2', '2026-10-20', 3, 'u1'),
    );
    assert.notStrictEqual(
      reminderDocId('b1', '2026-10-20', 3, 'u1'),
      reminderDocId('b1', '2026-10-20', 3, 'u2'),
    );
  });

  test('id contains no characters Firestore forbids', () => {
    assert.ok(!reminderDocId('b1', '2026-10-20', 3, 'u1').includes('/'));
  });
});

describe('copy', () => {
  test('1 day says tomorrow', () => {
    const c = reminderCopy({ title: 'Rent' }, 1, '2026-10-20');
    assert.strictEqual(c.title, 'Bill due tomorrow: Rent');
    assert.strictEqual(c.body, '"Rent" is due tomorrow (20 Oct 2026).');
  });

  test('n days says in n days', () => {
    const c = reminderCopy({ title: 'Water' }, 7, '2026-10-20');
    assert.strictEqual(c.title, 'Bill due in 7 days: Water');
  });
});
