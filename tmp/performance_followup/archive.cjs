const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = 'docs/optimizaciones/2026-09-30/seleccion_borrador_audio';
fs.mkdirSync(root, {recursive: true});
fs.writeFileSync(path.join(root, '.gitignore'), '!*.log\n');
for (const stage of ['baseline', 'phased', 'final', 'async']) {
  const input = `output/performance_followup_2026-09-30/${stage}`;
  const output = path.join(root, stage);
  fs.mkdirSync(output, {recursive: true});
  for (const name of ['results.json', 'results_summary.json']) {
    fs.copyFileSync(path.join(input, name), path.join(output, name));
  }
}
for (const name of fs.readdirSync('tmp/performance_followup')) {
  if (name.endsWith('.log') || name === 'pdf_structure.json') {
    fs.copyFileSync(path.join('tmp/performance_followup', name), path.join(root, name));
  }
  if (name.endsWith('.dart')) {
    const dir = path.join(root, 'candidatos_y_diagnosticos');
    fs.mkdirSync(dir, {recursive: true});
    fs.copyFileSync(path.join('tmp/performance_followup', name), path.join(dir, name + '.txt'));
  }
}
const sources = path.join(root, 'fuentes_retenidas');
fs.mkdirSync(sources, {recursive: true});
for (const file of [
  'lib/features/visor/widgets/annotation_layer.dart',
  'test/annotation_rendering_test.dart',
  'integration_test/performance_followup_test.dart',
  'test_driver/performance_audit.dart',
]) fs.copyFileSync(file, path.join(sources, path.basename(file) + '.txt'));
fs.copyFileSync('docs/OPTIMIZACION_SELECCION_BORRADOR_AUDIO_2026-09-30.md', path.join(root, 'registro.md'));
const entries = [];
function walk(dir) {
  for (const item of fs.readdirSync(dir, {withFileTypes: true})) {
    const file = path.join(dir, item.name);
    if (item.isDirectory()) walk(file);
    else if (item.name !== 'SHA256.json') {
      const bytes = fs.readFileSync(file);
      entries.push({file: path.relative(root, file).replaceAll('\\', '/'), bytes: bytes.length,
        sha256: crypto.createHash('sha256').update(bytes).digest('hex')});
    }
  }
}
walk(root);
entries.sort((a, b) => a.file.localeCompare(b.file));
fs.writeFileSync(path.join(root, 'SHA256.json'), JSON.stringify(entries, null, 2) + '\n');
const original = JSON.parse(fs.readFileSync('docs/auditorias/2026-09-29/SHA256.json'));
for (const entry of original) {
  const bytes = fs.readFileSync(path.join('docs/auditorias/2026-09-29/evidencias', entry.file));
  if (crypto.createHash('sha256').update(bytes).digest('hex') !== entry.sha256) {
    throw new Error(`Original evidence changed: ${entry.file}`);
  }
}
console.log(`Archived ${entries.length} new files; ${original.length} original hashes verified.`);
