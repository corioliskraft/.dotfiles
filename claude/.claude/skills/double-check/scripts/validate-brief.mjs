#!/usr/bin/env node

import { readFileSync } from "node:fs";

const briefPath = process.argv[2];

if (!briefPath) {
  console.error("usage: validate-brief.mjs <brief-path>");
  process.exit(2);
}

let brief;
try {
  brief = readFileSync(briefPath, "utf8");
} catch (error) {
  console.error(`cannot read brief: ${error.message}`);
  process.exit(2);
}

const requiredHeadings = [
  "## Your role",
  "## The task",
  "## The original scope",
  "## The claim being checked",
  "## The work — and where it lives",
  "## Context you need",
  "## Validation evidence",
  "## What to scrutinize hardest",
  "## Touched production inventory",
  "## Scope fidelity — mandatory checks",
  "## Touched-production-code simplification — mandatory check",
  "## How to respond",
];

const requiredSections = new Map([
  ["## The task", "{{TASK}}"],
  ["## The original scope", "{{ORIGINAL_SCOPE}}"],
  ["## The claim being checked", "{{CLAIM}}"],
  ["## The work — and where it lives", "{{WORK_LOCATION}}"],
  ["## Context you need", "{{CONTEXT}}"],
  ["## Validation evidence", "{{VALIDATION}}"],
  ["## What to scrutinize hardest", "{{RISKS}}"],
  ["## Touched production inventory", "{{PRODUCTION_SYMBOLS}}"],
]);

const requiredContracts = [
  "Unrequested additions",
  "Unrequested removals",
  "Removed or weakened tests",
  "diff the test files yourself",
  "unrequested behavior change pass silently as a `blocker`",
  "inventory every changed production function or",
  "expressed more directly",
  "current APIs and constraints",
  "Touched production code — missed valuable simplifications:",
  "VERDICT: no-issues",
  "VERDICT: issues-found",
];

const failures = [];
let previousIndex = -1;
const sectionBody = heading => {
  const start = brief.indexOf(heading) + heading.length;
  const nextHeading = brief.indexOf("\n## ", start);
  return brief.slice(start, nextHeading === -1 ? brief.length : nextHeading);
};

for (const heading of requiredHeadings) {
  const matches = [...brief.matchAll(new RegExp(`^${heading.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`, "gm"))];
  if (matches.length !== 1) {
    failures.push(`${heading}: expected exactly once, found ${matches.length}`);
    continue;
  }
  if (matches[0].index < previousIndex) {
    failures.push(`${heading}: appears out of canonical order`);
  }
  previousIndex = matches[0].index;
}

for (const contract of requiredContracts) {
  if (!brief.includes(contract)) failures.push(`missing mandatory contract: ${contract}`);
}

const reviewMode = /^Review mode: \*\*(.+)\*\*$/m.exec(brief)?.[1];
const allowedReviewModes = new Set([
  "cross-provider independent review",
  "same-provider fresh-context fallback",
]);
if (!allowedReviewModes.has(reviewMode)) {
  failures.push(`invalid review mode: ${reviewMode ?? "missing"}`);
}

for (const [heading, token] of requiredSections) {
  const firstContentLine = sectionBody(heading)
    .split("\n")
    .map(line => line.trim())
    .find(line => line.length > 0);
  if (!firstContentLine || firstContentLine === token || firstContentLine.startsWith("(")) {
    failures.push(`${heading}: required content is empty`);
  }
}

const rawInventoryLines = sectionBody("## Touched production inventory")
  .split("\n")
  .map(line => line.trim())
  .filter(line => line.length > 0);
const guidanceStart = rawInventoryLines.findIndex(line => line.startsWith("("));
const inventoryLines = rawInventoryLines
  .slice(0, guidanceStart === -1 ? rawInventoryLines.length : guidanceStart)
  .map(line => line.replace(/^[-*+]\s+/, "").replace(/^`|`$/g, ""));
const noProductionMarker = "N/A — no production code changed";
const usesNoProductionMarker = inventoryLines.includes(noProductionMarker);
const stableIdentifier = /^[^\s:]+:[^\s:]+$/;
if (usesNoProductionMarker && inventoryLines.length !== 1) {
  failures.push("## Touched production inventory: cannot mix N/A with identifiers");
} else if (!usesNoProductionMarker &&
           (inventoryLines.length === 0 || inventoryLines.some(line => !stableIdentifier.test(line)))) {
  failures.push("## Touched production inventory: expected file:symbol identifiers or the exact N/A marker");
}

const unresolved = [...brief.matchAll(/\{\{[A-Z0-9_]+\}\}/g)].map(match => match[0]);
if (unresolved.length > 0) {
  failures.push(`unresolved template fields: ${[...new Set(unresolved)].join(", ")}`);
}

if (failures.length > 0) {
  for (const failure of failures) console.error(`invalid brief: ${failure}`);
  process.exit(1);
}

console.log("brief contract valid");
