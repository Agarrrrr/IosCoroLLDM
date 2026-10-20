const fs=require('node:fs');
const env=fs.readFileSync('E:/proyectos/CoroLLDM/.env','utf8');
function val(name){const m=env.match(new RegExp(`^${name}=(.*)$`,'m'));return m?.[1].trim().replace(/^['"]|['"]$/g,'');}
const base=val('VITE_SUPABASE_URL');
const anon=val('VITE_SUPABASE_ANON_KEY');
if(!base||!anon)throw Error('Missing public client configuration');
async function main(){
  for(const [rpc,body] of [['catalogo_global_bilingue',{}],['resolver_archivo_canto',{p_canto_id:'c17e1cc7-5c27-4ab1-9a75-3826fc2e66df',p_tipo:'midi'}]]){
    const r=await fetch(`${base}/rest/v1/rpc/${rpc}`,{method:'POST',headers:{apikey:anon,Authorization:`Bearer ${anon}`,'Content-Type':'application/json'},body:JSON.stringify(body)});
    const data=await r.json();
    console.log(rpc,r.status);
    if(!r.ok){console.log(JSON.stringify(data));continue;}
    if(rpc==='catalogo_global_bilingue'){
      fs.writeFileSync('tmp/codex_release_remote_catalog.json',JSON.stringify(data));
      console.log(JSON.stringify(data.filter(row=>/alfarero|great potter|bells.*baptism/i.test(row.nombre||'')),null,2));
    }else console.log(JSON.stringify(data));
  }
}
main().catch(e=>{console.error(e.message);process.exitCode=1});
