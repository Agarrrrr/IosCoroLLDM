const fs=require('node:fs');
const cp=require('node:child_process');
const filename='pecador-ven-al-dulce-jesus-1777250932709.pdf';
const target=`assets/offline_assets/pdfs/${filename}`;
fs.writeFileSync(target,cp.execFileSync('git',['show',`HEAD:${target}`],{maxBuffer:1024*1024}));
for(const catalog of ['assets/catalogo.json','assets/offline_assets/catalogo.json']){
  const text=fs.readFileSync(catalog,'utf8');
  const url=`https://mxnhmtztxgeccohlgqpt.supabase.co/storage/v1/object/public/partituras/${filename}`;
  if(!text.includes(url))throw Error('Expected remote reference missing');
  fs.writeFileSync(catalog,text.replace(url,filename));
}
console.log('Restored existing Pecador PDF and local catalog reference');
