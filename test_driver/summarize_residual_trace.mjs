import fs from 'node:fs';

const input = process.argv[2];
const report = JSON.parse(fs.readFileSync(input, 'utf8'));
const summaries = {};
for (const [scenario, data] of Object.entries(report.scenarios)) {
  if (!data.timeline) continue;
  const events = data.timeline.traceEvents ?? [];
  const threads = {};
  const stacks = new Map();
  const spans = [];
  for (const event of events) {
    const key = `${event.pid}:${event.tid}`;
    if (event.ph === 'M' && event.name === 'thread_name') {
      threads[key] = event.args?.name;
    }
    if (event.ph === 'X') spans.push(event);
    if (event.ph === 'B') {
      if (!stacks.has(key)) stacks.set(key, []);
      stacks.get(key).push(event);
    }
    if (event.ph === 'E') {
      const begin = stacks.get(key)?.pop();
      if (begin) spans.push({...begin, ph: 'X', dur: event.ts - begin.ts});
    }
  }
  const describe = e => ({name: e.name, thread: threads[`${e.pid}:${e.tid}`],
    tid: e.tid, ms: e.dur / 1000, ts: e.ts, args: e.args});
  const ordered = spans.filter(e => e.dur >= 1000).sort((a, b) => b.dur - a.dur);
  const raster = ordered.filter(e => /Rasterizer.*Draw|GPURasterizer.*Draw/.test(e.name));
  summaries[scenario] = {
    eventCount: events.length,
    longest: ordered.slice(0, 50).map(describe),
    raster: raster.slice(0, 15).map(root => ({...describe(root),
      nested: ordered.filter(e => e !== root && e.pid === root.pid &&
        e.tid === root.tid && e.ts >= root.ts &&
        e.ts + e.dur <= root.ts + root.dur).slice(0, 15).map(describe)})),
  };
}
const output = input.replace(/\.json$/, '_trace_summary.json');
fs.writeFileSync(output, JSON.stringify(summaries, null, 2) + '\n');
console.log(JSON.stringify(summaries, null, 2));
