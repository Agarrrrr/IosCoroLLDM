const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const root = 'docs/optimizaciones/2026-09-30/reapertura_borrador';
const entries = [];
function walk(dir) {
  for (const item of fs.readdirSync(dir, {withFileTypes: true})) {
    const target = path.join(dir, item.name);
    if (item.isDirectory()) walk(target);
    else if (item.name !== 'SHA256.json') {
      const bytes = fs.readFileSync(target);
      entries.push({file: path.relative(root, target).replaceAll('\\', '/'), bytes: bytes.length, sha256: crypto.createHash('sha256').update(bytes).digest('hex')});
    }
  }
}
walk(root);
entries.sort((a, b) => a.file.localeCompare(b.file));
fs.writeFileSync(path.join(root, 'SHA256.json'), JSON.stringify(entries, null, 2) + '\n');
console.log(`Manifest created: ${entries.length} files.`);
