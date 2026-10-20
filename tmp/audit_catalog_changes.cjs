const fs=require('fs'), cp=require('child_process');
const read=(ref,file)=>JSON.parse(ref?cp.execFileSync('git',['show',`${ref}:${file}`],{encoding:'utf8',maxBuffer:20000000}):fs.readFileSync(file,'utf8'));
const report={};
for(const lang of ['es','en']) {
 const file=`assets/catalogo${lang==='en'?'_en':''}.json`;
 const old=read('5d79960',file), current=read(null,file), now=new Map(current.map(s=>[s.id,s]));
 report[lang]={removed:old.filter(s=>!now.has(s.id)), renamed:old.filter(s=>now.has(s.id)&&s.nombre!==now.get(s.id).nombre).map(s=>({id:s.id,before:s.nombre,after:now.get(s.id).nombre})), assetsChanged:old.filter(s=>now.has(s.id)&&(s.archivo!==now.get(s.id).archivo||s.midi_archivo!==now.get(s.id).midi_archivo)).map(s=>({id:s.id,before:s,after:now.get(s.id)}))};
 const unique=new Set(); report[lang].duplicateIds=current.filter(s=>unique.has(s.id)||!unique.add(s.id)).map(s=>s.id);
}
fs.writeFileSync('tmp/catalog_changes_audit.json',JSON.stringify(report,null,2));
for(const [lang,r] of Object.entries(report)) console.log(JSON.stringify({language:lang,removed:r.removed.map(s=>({id:s.id,name:s.nombre})),renamed:r.renamed,assetChangeCount:r.assetsChanged.length,duplicateIds:r.duplicateIds},null,2));
