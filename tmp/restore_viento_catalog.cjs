const fs = require('fs');
const cp = require('child_process');
const path = require('path');
const remote = JSON.parse(fs.readFileSync('tmp/viento_remote.json'));
const old = JSON.parse(cp.execFileSync('git', ['show', '5d79960:assets/catalogo.json'], {encoding:'utf8', maxBuffer:10000000}));
const shortId = 'eaeafa56-1d25-4517-b13f-1b3f7f6beced';
const longId = 'f034d95c-6ae5-45ad-9d7c-c0ea51075a58';
const shortRemote = remote.find(s => s.id === shortId);
const longRemote = remote.find(s => s.id === longId);
const short = {...old.find(s => s.id === shortId), ...shortRemote};
if (!short.archivo || !short.midi_archivo || !longRemote) throw new Error('Incomplete recovered metadata');
for (const file of ['assets/catalogo.json', 'assets/offline_assets/catalogo.json', 'website/public/catalogo.json']) {
  const catalog = JSON.parse(fs.readFileSync(file));
  const before = catalog.length;
  const long = catalog.find(s => s.id === longId);
  if (!long) throw new Error(`Missing long entry in ${file}`);
  long.nombre = longRemote.nombre;
  const existing = catalog.find(s => s.id === shortId);
  if (existing) Object.assign(existing, short);
  else catalog.splice(catalog.indexOf(long), 0, short);
  const selected = catalog.filter(s => s.id === shortId || s.id === longId);
  if (selected.length !== 2 || selected[0].archivo === selected[1].archivo || selected[0].midi_archivo === selected[1].midi_archivo) throw new Error('Distinct works lost');
  fs.writeFileSync(file, JSON.stringify(catalog, null, 2) + '\n');
  console.log(file, `${before} -> ${catalog.length}`, 'both works restored');
}
for (const song of remote) for (const type of ['pdf', 'midi']) {
  const key = song[type === 'pdf' ? 'archivo' : 'midi_archivo'];
  const target = `assets/offline_assets/${type === 'pdf' ? 'pdfs' : 'midis'}/${key}`;
  const source = fs.readFileSync(`tmp/viento_recovery/${song.id}.${type}.enc`);
  if (fs.existsSync(target)) {
    // Ciphertexts can differ by nonce; validate decrypted identity with
    // validate_viento_recovery.dart before accepting existing resources.
    console.log('Existing resource retained for decrypted validation:', target);
  } else {
    fs.mkdirSync(path.dirname(target), {recursive:true});
    fs.writeFileSync(target, source);
    console.log('Offline resource restored:', target);
  }
}
