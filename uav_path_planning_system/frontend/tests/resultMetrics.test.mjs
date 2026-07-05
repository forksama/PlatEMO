import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import vm from "node:vm";

import ts from "typescript";

const require = createRequire(import.meta.url);
const helperPath = path.resolve("src/resultMetrics.ts");
const source = fs.readFileSync(helperPath, "utf8");
const transpiled = ts.transpileModule(source, {
  compilerOptions: {
    module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2020
  }
}).outputText;

const module = { exports: {} };
vm.runInNewContext(
  transpiled,
  {
    exports: module.exports,
    module,
    require
  },
  { filename: helperPath }
);

const { getSelectedObjectiveMetrics } = module.exports;

const objectives = [
  { solutionIndex: 0, negativeSignal: 80, switchCount: 1, negativeCoverage: -0.9 },
  { solutionIndex: 1, negativeSignal: 70, switchCount: 4, negativeCoverage: -0.98 }
];

const first = getSelectedObjectiveMetrics(objectives, 0);
const second = getSelectedObjectiveMetrics(objectives, 1);

assert.equal(first.solutionIndex, 0);
assert.equal(first.signalDbm, -80);
assert.equal(first.switchCount, 1);
assert.equal(first.coverageRatio, 0.9);
assert.equal(second.solutionIndex, 1);
assert.equal(second.signalDbm, -70);
assert.equal(second.switchCount, 4);
assert.equal(second.coverageRatio, 0.98);
assert.equal("hypervolume" in first, false, "candidate metrics should not expose per-solution HV");
assert.equal("totalHypervolume" in first, false, "candidate metrics should not calculate front HV in the frontend");

const missing = getSelectedObjectiveMetrics(objectives, 99);
assert.equal(missing.signalDbm, null);
assert.equal("hypervolume" in missing, false, "missing candidate metrics should not expose HV");
