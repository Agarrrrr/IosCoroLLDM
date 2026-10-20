from pathlib import Path
import json
import re
root=Path('E:/proyectos/CoroLLDM')
p=root/'package.json'
d=json.loads(p.read_text(encoding='utf-8'))
d['scripts']['test:catalog-safety']='node --test scripts/catalog_safety.test.mjs scripts/remote_catalog_safety.test.mjs'
d['scripts']['sync-catalogs:check']='node scripts/sync_catalogs.mjs --dry-run'
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
p=root/'.gitignore'
s=p.read_text(encoding='utf-8')
if '.codex-backups/' not in s: s+='\n# Recoverable local source backups\n.codex-backups/\n'
p.write_text(s,encoding='utf-8')
p=root/'src/api/remoteCatalogDB.js'
s=p.read_text(encoding='utf-8')
s=s.replace('            offlineCopies\n            )','                offlineCopies\n            )')
s=s.replace('// 2. Integrar filas remotas evitando duplicados por ID, external_id o nombre+idioma','// 2. Integrar únicamente por ID o correspondencia externa explícita.')
s=re.sub(r'^        const normalizarClave = .*\n','',s,flags=re.M)
s=re.sub(r'^            const normKey = .*\n','',s,flags=re.M)
s=re.sub(r'^            const lang = row.idioma .*\n','',s,flags=re.M)
p.write_text(s,encoding='utf-8')
p=root/'scripts/catalog_safety.mjs'
s=p.read_text(encoding='utf-8')
marker='    const merged = { ...previous, ...update, id: previous.id };'
s=s.replace(marker,marker+'''
    if (newVersion === oldVersion) for (const field of ['archivo','midi_archivo']) {
      if (previous[field] && update[field] && previous[field] !== update[field]) {
        if (rejectOlder) throw new Error(`El recurso de ${update.id} cambió sin una versión superior.`);
        merged[field] = previous[field];
      }
    }''')
p.write_text(s,encoding='utf-8')
print('Safety test scripts registered; same-version resource conflicts are preserved or rejected.')
