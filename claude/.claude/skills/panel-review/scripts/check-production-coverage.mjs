#!/usr/bin/env node

import { readFileSync } from "node:fs";

const [inventoryPath, reportPath] = process.argv.slice(2);
if (!inventoryPath || !reportPath) {
  console.error("usage: check-production-coverage.mjs <inventory.json> <refactoring-report.json>");
  process.exit(2);
}

let inventory;
let report;
try {
  inventory = JSON.parse(readFileSync(inventoryPath, "utf8"));
  report = JSON.parse(readFileSync(reportPath, "utf8"));
} catch (error) {
  console.error(`cannot read coverage inputs: ${error.message}`);
  process.exit(2);
}

if (!Array.isArray(inventory)) {
  console.error("invalid inventory: expected an array");
  process.exit(2);
}

const expected = inventory.map(item => typeof item === "string" ? item : item?.id);
if (expected.some(id => typeof id !== "string" || id.length === 0)) {
  console.error("invalid inventory: every entry needs a non-empty id");
  process.exit(2);
}

const assessments = Array.isArray(report?.production_assessment)
  ? report.production_assessment
  : [];
const validDispositions = new Set(["keep", "simplify now", "follow-up"]);
const validPriorities = new Set(["Critical", "High", "Nice", "Skip"]);
const invalidAssessments = assessments.flatMap((item, index) => {
  const valid = typeof item?.symbol === "string" && item.symbol.length > 0 &&
    validDispositions.has(item.disposition) &&
    validPriorities.has(item.priority) &&
    typeof item.rationale === "string" && item.rationale.trim().length > 0;
  return valid ? [] : [index];
});
const assessed = new Set(assessments.map(item => item?.symbol));
const assessmentGaps = expected.filter(id => !assessed.has(id));
const auditMissing = !Array.isArray(report?.inventory_omissions);
const inventoryOmissions = auditMissing ? [] : report.inventory_omissions;
const invalidInventoryOmissions = inventoryOmissions.some(
  id => typeof id !== "string" || id.length === 0,
);
const result = {
  assessmentGaps,
  inventoryOmissions,
  auditMissing,
  invalidAssessments,
  invalidInventoryOmissions,
};

console.log(JSON.stringify(result));
if (assessmentGaps.length > 0 || inventoryOmissions.length > 0 || auditMissing ||
    invalidAssessments.length > 0 || invalidInventoryOmissions) {
  process.exit(1);
}
