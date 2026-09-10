'use strict';
/**
 * The membership-index DERIVATION RULE.
 *
 * One implementation, shared by the two things that write the authorization
 * index:
 *
 *   * functions/index.js              — the live trigger, on every
 *                                       `house_members` write.
 *   * tool/backfill_membership_index.js — the one-off backfill for memberships
 *                                       that predate the index.
 *
 * They MUST agree. If the trigger and the backfill derived different answers,
 * a member's authorization would depend on which one last ran — the kind of bug
 * that shows up as "I was removed but can still see everything", months later,
 * with no obvious cause. So the rule lives here once and both call it.
 *
 * ── WHY IT IS NOT "COPY THE ROW THAT CHANGED" ──
 * A person can hold SEVERAL `house_members` rows for one house. Leave House and
 * Remove Member are both SOFT deletes — `isActive: false`, never a delete — so
 * the old row survives a rejoin and a removed-then-rejoined member has two.
 * Copying whichever row happened to fire last would let a stale soft-deleted
 * row deactivate somebody who is currently an active member. Deriving from the
 * FULL set and OR-ing the active rows is order-independent, idempotent, and
 * self-healing if the index ever drifts.
 *
 * ── DELIBERATELY DEPENDENCY-FREE ──
 * `tool/backfill_membership_index.js` requires this file directly, from a
 * different npm project with a different dependency tree. It must never pull in
 * firebase-admin or firebase-functions.
 */

/** The role string the app uses for the house treasurer. */
const ROLE_TREASURER = 'Treasurer';
/** …and for everyone else. */
const ROLE_MEMBER = 'Member';

/**
 * Derives ONE user's authorization state for ONE house from that pair's
 * `house_members` rows.
 *
 * @param {Array<object>} rows the raw row data for one (houseId, userId) pair.
 *   May be empty, which yields an inactive Member — the correct "not
 *   authorized" answer for somebody who belongs to no house.
 * @returns {{isActive: boolean, role: string, activeRows: number, totalRows: number}}
 */
function summarizeMembership(rows) {
  const list = Array.isArray(rows) ? rows : [];

  let activeRows = 0;
  let hasActiveTreasurer = false;

  for (const row of list) {
    const data = row || {};
    // `isActive` is ABSENT on the oldest records. The app's model defaults it
    // to true, so treat only an explicit `false` as deauthorized — reading a
    // missing field as inactive would lock out every legacy member.
    if (data.isActive === false) continue;
    activeRows++;
    // Only an ACTIVE Treasurer row confers the role: a stale soft-deleted
    // Treasurer row must not keep the role alive after a transfer.
    if (data.role === ROLE_TREASURER) hasActiveTreasurer = true;
  }

  return {
    isActive: activeRows > 0,
    role: hasActiveTreasurer ? ROLE_TREASURER : ROLE_MEMBER,
    activeRows,
    totalRows: list.length,
  };
}

module.exports = { summarizeMembership, ROLE_TREASURER, ROLE_MEMBER };
