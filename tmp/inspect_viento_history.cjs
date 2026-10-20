const cp = require('child_process');
const commits = cp.execFileSync('git', ['log', '--format=%h', '--all', '--', 'assets/catalogo.json'], {encoding:'utf8'}).trim().split(/\s+/);
for (const commit of commits) {
  try {
    const catalog = JSON.parse(cp.execFileSync('git', ['show', `${commit}:assets/catalogo.json`], {encoding:'utf8', maxBuffer:10000000}));
    const matches = catalog.filter(s => /vida.*viento|pronto.*nubes/i.test(s.nombre));
    console.log(JSON.stringify({commit, matches}));
  } catch {}
}
