// src/airtable.js
import Airtable from "airtable";

const required = ["AIRTABLE_TOKEN", "AIRTABLE_BASE_ID", "AIRTABLE_TABLE"];
for (const k of required) {
  if (!process.env[k]) throw new Error(`Missing env var: ${k}`);
}
console.log("AIRTABLE_TOKEN length:", (process.env.AIRTABLE_TOKEN || "").length);

Airtable.configure({ apiKey: process.env.AIRTABLE_TOKEN });

export const atBase = Airtable.base(process.env.AIRTABLE_BASE_ID);
export const atTable = atBase(process.env.AIRTABLE_TABLE);
