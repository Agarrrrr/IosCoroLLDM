const fs = require('fs');
const path = require('path');
const zlib = require('zlib');
const root = 'docs/optimizaciones/2026-09-30/reapertura_borrador';
fs.mkdirSync(root, {recursive: true});
fs.writeFileSync(path.join(root, '.gitignore'), '!*.log\n!*.gz\n');
for (const stage of ['probe', 'probe2', 'probe3', 'probe4', 'probe5', 'probe6', 'probe7', 'final']) {
  const input = `output/optimization_session_2026-09-30/${stage}`;
  if (!fs.existsSync(input)) continue;
  const dir = path.join(root, stage);
  fs.mkdirSync(dir, {recursive: true});
  for (const file of fs.readdirSync(input)) {
    const bytes = fs.readFileSync(path.join(input, file));
    if (file === 'results.json' && stage !== 'final') {
      fs.writeFileSync(path.join(dir, 'results.json.gz'), zlib.gzipSync(bytes));
    } else if (file.endsWith('.json')) {
      fs.writeFileSync(path.join(dir, file), bytes);
    }
  }
}
for (const file of fs.readdirSync('tmp').filter(name => /^optimization_session.*\.log$/.test(name))) {
  fs.copyFileSync(path.join('tmp', file), path.join(root, file));
}
const sources = path.join(root, 'fuentes');
fs.mkdirSync(sources, {recursive: true});
for (const file of [
  'lib/features/visor/widgets/annotation_layer.dart',
  'lib/features/visor/widgets/annotation_eraser_preview.dart',
  'test/annotation_rendering_test.dart',
  'integration_test/performance_optimization_test.dart',
  'test_driver/performance_audit.dart',
]) fs.copyFileSync(file, path.join(sources, path.basename(file)));
console.log('Evidence archived separately from the original audit.');
