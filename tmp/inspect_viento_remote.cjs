const fs = require('fs');
const path = require('path');
(async () => {
  const project = 'C:/Users/Huri_/Documents/proyectos/repertoriobc';
  let config = {};
  for (const name of ['.env', '.env.local', '.env.production']) {
    const file = path.join(project, name);
    if (!fs.existsSync(file)) continue;
    for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
      const match = line.match(/^(VITE_SUPABASE_URL|VITE_SUPABASE_ANON_KEY)\s*=\s*(.*)$/);
      if (match) config[match[1]] = match[2].trim().replace(/^['"]|['"]$/g, '');
    }
  }
  if (!config.VITE_SUPABASE_URL || !config.VITE_SUPABASE_ANON_KEY) throw new Error('Public API configuration unavailable');
  const url = new URL('/rest/v1/cantos', config.VITE_SUPABASE_URL);
  url.searchParams.set('select', 'id,nombre,archivo,midi_archivo,version');
  url.searchParams.set('id', 'in.(eaeafa56-1d25-4517-b13f-1b3f7f6beced,f034d95c-6ae5-45ad-9d7c-c0ea51075a58)');
  const response = await fetch(url, {headers: {apikey: config.VITE_SUPABASE_ANON_KEY, Authorization: `Bearer ${config.VITE_SUPABASE_ANON_KEY}`}});
  console.log('Public catalog HTTP', response.status);
  const data = await response.json();
  fs.writeFileSync('tmp/viento_remote.json', JSON.stringify(data, null, 2));
  if (Array.isArray(data)) console.log(JSON.stringify(data, null, 2));
  else console.log('Catalog response:', data.message || data.error || 'no rows');
  if (Array.isArray(data)) {
    fs.mkdirSync('tmp/viento_recovery', {recursive: true});
    for (const song of data) for (const type of ['pdf', 'midi']) {
      const response = await fetch(`https://repertoriobc-files.huritolentino.workers.dev/v1/files/${song.id}/${type}`,
        {headers: {Authorization: `Bearer ${config.VITE_SUPABASE_ANON_KEY}`}});
      console.log(song.id, type, 'HTTP', response.status);
      if (response.ok) {
        const bytes = Buffer.from(await response.arrayBuffer());
        fs.writeFileSync(`tmp/viento_recovery/${song.id}.${type}.enc`, bytes);
        console.log('Downloaded', bytes.length, 'bytes, catalog version', response.headers.get('x-catalog-version'));
      }
    }
  }
})().catch(error => { console.error(error.message); process.exitCode = 1; });
