import fs from 'node:fs';
import path from 'node:path';

// Usage: node test_driver/summarize_performance_audit.mjs path/to/results.json
const input = process.argv[2];
if (!input) throw new Error('Provide a results.json path');
const report = JSON.parse(fs.readFileSync(input, 'utf8'));
const percentile = (values, p) => {
  if (!values.length) return null;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.max(0, Math.ceil(sorted.length * p) - 1)];
};
const stats = values => Object.fromEntries(
  [['p50', .5], ['p95', .95], ['p99', .99], ['max', 1]].map(
    ([name, p]) => [name, percentile(values, p)],
  ),
);
const budgetUs = 1e6 / report.device.refreshRate;
const scenarios = Object.fromEntries(Object.entries(report.scenarios).map(([name, data]) => {
  const {frames, timerGapsMs = [], timeline, ...rest} = data;
  const overBudget = frames.filter(f => f[0] > budgetUs || f[1] > budgetUs).length;
  return [name, {
    ...rest,
    uiMs: stats(frames.map(f => f[0] / 1000)),
    rasterMs: stats(frames.map(f => f[1] / 1000)),
    totalSpanMs: stats(frames.map(f => f[2] / 1000)),
    timerGapsMs: stats(timerGapsMs),
    overBudget,
    overBudgetPercent: frames.length ? overBudget / frames.length * 100 : null,
    rssAfterMiB: data.rssAfter / 1048576,
  }];
}));
const summary = {
  input: path.basename(input), device: report.device, budgetMs: budgetUs / 1000,
  note: 'UI/raster duration thresholds are not a count of display-dropped frames. Timers include scheduling delays. RSS includes test instrumentation and graphics allocations.',
  pdfSamples: report.pdfSamples, catalogCount: report.catalogCount,
  rssAtEndMiB: report.rssAtEnd / 1048576, screenshotRss: report.screenshotRss,
  scenarios,
};
const output = input.replace(/\.json$/, '_summary.json');
fs.writeFileSync(output, JSON.stringify(summary, null, 2) + '\n');
for (const [name, s] of Object.entries(scenarios)) {
  console.log(`${name}: ${s.elapsedMs.toFixed(1)} ms; UI p95/max ${s.uiMs.p95}/${s.uiMs.max}; raster p50/p95/max ${s.rasterMs.p50}/${s.rasterMs.p95}/${s.rasterMs.max}; over ${s.overBudget}/${s.frameCount}; timer max ${s.timerGapsMs.max}; RSS ${s.rssAfterMiB.toFixed(0)} MiB${s.error ? '; ERROR ' + s.error : ''}`);
}
console.log(`Written ${output}`);
