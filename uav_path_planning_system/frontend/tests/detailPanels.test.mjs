import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const appPath = path.resolve("src/App.tsx");
const source = fs.readFileSync(appPath, "utf8");

function sectionBetween(name, nextName) {
  const start = source.indexOf(`function ${name}`);
  assert.notEqual(start, -1, `${name} should exist`);
  const end = source.indexOf(`function ${nextName}`, start);
  assert.notEqual(end, -1, `${nextName} should exist after ${name}`);
  return source.slice(start, end);
}

const taskDetail = sectionBetween("TaskDetailPanel", "ScenarioDetailPanel");
const resourceDetail = sectionBetween("ResourceDetailPanel", "InfoPanel");
const resultsView = sectionBetween("ResultsView", "TaskDetailPanel");

assert.equal(
  taskDetail.includes("<ScenarioDetailPanel"),
  false,
  "task details should show only task fields and scenario summary, not nested scenario details"
);
assert.equal(
  resourceDetail.includes("<ResourceDetailPanel"),
  false,
  "resource details should show only the selected resource and linked summaries, not recursive resource details"
);

assert.equal(
  taskDetail.includes("formatBeijingTime"),
  true,
  "task details should format timestamps as Beijing time"
);
assert.equal(
  resourceDetail.includes("formatBeijingTime"),
  true,
  "resource details should format timestamps as Beijing time"
);
assert.equal(
  resultsView.includes('label="运行耗时"'),
  true,
  "results view should expose completed-task runtime as a metric"
);
