// src/userStore.js
import { atTable } from "./airtable.js";
import crypto from "node:crypto";

/**
 * Airtable field names MUST match your table column headers exactly.
 * Your table:
 * - Name
 * - googleSub
 * - email
 * - createdAt
 *
 * Add these columns:
 * - deviceId
 * - phoneKey
 * - callNumber (optional)
 */
const FIELDS = {
  name: "Name",
  googleSub: "googleSub",
  email: "email",
  createdAt: "createdAt",
  deviceId: "deviceId",
  phoneKey: "phoneKey",
  callNumber: "callNumber",
};

// Escape strings used in Airtable formulas
function escFormulaStr(s) {
  return String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

// Short, URL-safe random id
function randId(bytes = 9) {
  // 9 bytes => 12 chars base64url-ish after stripping
  return crypto.randomBytes(bytes).toString("base64url");
}

function recordToUser(rec) {
  const f = rec.fields || {};
  return {
    id: rec.id, // Airtable record id = local user id (session)
    google_sub: f[FIELDS.googleSub] ?? null,
    email: f[FIELDS.email] ?? null,
    name: f[FIELDS.name] ?? null,
    created_at: f[FIELDS.createdAt] ?? null,

    // "phone identity" fields
    deviceId: f[FIELDS.deviceId] ?? null,
    phoneKey: f[FIELDS.phoneKey] ?? null,
    callNumber: f[FIELDS.callNumber] ?? 0,
  };
}

export async function findUserByGoogleSub(googleSub) {
  const formula = `{${FIELDS.googleSub}} = "${escFormulaStr(googleSub)}"`;
  const records = await atTable
    .select({ maxRecords: 1, filterByFormula: formula })
    .firstPage();

  return records.length ? recordToUser(records[0]) : null;
}

export async function findUserByEmail(email) {
  if (!email) return null;
  const formula = `{${FIELDS.email}} = "${escFormulaStr(email)}"`;
  const records = await atTable
    .select({ maxRecords: 1, filterByFormula: formula })
    .firstPage();

  return records.length ? recordToUser(records[0]) : null;
}

export async function createUser({ googleSub, email, name }) {
  const rec = await atTable.create({
    [FIELDS.googleSub]: googleSub,
    [FIELDS.email]: email ?? "",
    [FIELDS.name]: name ?? "",
    [FIELDS.createdAt]: new Date().toISOString(),

    // generate at creation
    [FIELDS.deviceId]: `dev_${randId(9)}`,
    [FIELDS.phoneKey]: `pk_${randId(18)}`,
    [FIELDS.callNumber]: 0,
  });

  return recordToUser(rec);
}

export async function linkGoogleSubToUser(recordId, googleSub, name) {
  const rec = await atTable.update(recordId, {
    [FIELDS.googleSub]: googleSub,
    [FIELDS.name]: name ?? "",
  });

  return recordToUser(rec);
}

export async function updateUser(recordId, { email, name }) {
  const fields = {};
  if (email) fields[FIELDS.email] = email;
  if (name) fields[FIELDS.name] = name;

  if (!Object.keys(fields).length) return getUserById(recordId);

  const rec = await atTable.update(recordId, fields);
  return recordToUser(rec);
}

export async function getUserById(recordId) {
  const rec = await atTable.find(recordId);
  return recordToUser(rec);
}

/**
 * Ensure phone identity exists (deviceId + phoneKey).
 * If missing, generate and store them.
 */
export async function ensurePhoneIdentity(recordId) {
  const current = await getUserById(recordId);

  const fields = {};
  if (!current.deviceId) fields[FIELDS.deviceId] = `dev_${randId(9)}`;
  if (!current.phoneKey) fields[FIELDS.phoneKey] = `pk_${randId(18)}`;

  // Ensure callNumber exists (optional)
  if (current.callNumber == null) fields[FIELDS.callNumber] = 0;

  if (!Object.keys(fields).length) return current;

  const rec = await atTable.update(recordId, fields);
  return recordToUser(rec);
}
