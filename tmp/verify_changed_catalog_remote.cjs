const fs=require('fs'),path=require('path');
(async()=>{
 const config={};
 for(const name of ['.env','.env.local','.env.production']) {const f=path.join('C:/Users/Huri_/Documents/proyectos/repertoriobc',name);if(!fs.existsSync(f))continue;for(const line of fs.readFileSync(f,'utf8').split(/\r?\n/)){const m=line.match(/^(VITE_SUPABASE_URL|VITE_SUPABASE_ANON_KEY)\s*=\s*(.*)$/);if(m)config[m[1]]=m[2].trim().replace(/^['"]|['"]$/g,'');}}
 const changes=JSON.parse(fs.readFileSync('tmp/catalog_changes_audit.json'));
 const selected=[], migrations=[], missing=[];
 for(const lang of ['es','en']) {const c=JSON.parse(fs.readFileSync(`assets/catalogo${lang==='en'?'_en':''}.json`));for(const old of changes[lang].removed){const found=c.filter(s=>s.external_id===old.id);if(found.length!==1)missing.push({oldId:old.id,name:old.nombre,candidates:found.length});else{migrations.push({oldId:old.id,id:found[0].id,name:old.nombre});selected.push(found[0]);}}selected.push(...changes[lang].assetsChanged.map(x=>x.after));}
 const rows=[...new Map(selected.map(s=>[s.id,s])).values()];
 const url=new URL('/rest/v1/cantos',config.VITE_SUPABASE_URL);url.searchParams.set('select','id,nombre,archivo,midi_archivo,version');url.searchParams.set('id',`in.(${rows.map(s=>s.id).join(',')})`);
 const response=await fetch(url,{headers:{apikey:config.VITE_SUPABASE_ANON_KEY,Authorization:`Bearer ${config.VITE_SUPABASE_ANON_KEY}`}});if(!response.ok)throw Error(`Catalog HTTP ${response.status}`);const remote=await response.json(),byId=new Map(remote.map(s=>[s.id,s]));
 const differences=[];for(const local of rows){const live=byId.get(local.id);if(!live){differences.push({id:local.id,name:local.nombre,missingRemote:true});continue;}for(const field of ['nombre','archivo','midi_archivo'])if((local[field]||null)!==(live[field]||null))differences.push({id:local.id,name:local.nombre,field,local:local[field],remote:live[field]});}
 const report={checkedRows:rows.length,remoteRows:remote.length,migrations,unmappedRemoved:missing,differences,remote};fs.writeFileSync('tmp/catalog_remote_audit.json',JSON.stringify(report,null,2));console.log(JSON.stringify({checkedRows:rows.length,remoteRows:remote.length,migratedIds:migrations.length,unmappedRemoved:missing,differences},null,2));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
