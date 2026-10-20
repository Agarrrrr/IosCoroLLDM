const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const key=crypto.createHash('sha256').update(fs.readFileSync('lib/core/security/file_crypto.dart','utf8').match(/_rawKey = '([^']+)'/)[1]).digest();
function scan(dir){
 if(!fs.existsSync(dir))return;
 for(const e of fs.readdirSync(dir,{withFileTypes:true})){
  const file=path.join(dir,e.name);
  if(e.isDirectory()){scan(file);continue;}
  if(!/\.(enc|midi?)$/i.test(e.name))continue;
  try{
   let bytes=fs.readFileSync(file);
   if(bytes.subarray(0,4).toString()!=='MThd'){
    const c=crypto.createDecipheriv('aes-256-gcm',key,bytes.subarray(0,12));c.setAuthTag(bytes.subarray(-16));
    bytes=Buffer.concat([c.update(bytes.subarray(12,-16)),c.final()]);
   }
   if(bytes.subarray(0,4).toString()==='MThd'&&/alfarero|great.{0,4}potter/i.test(bytes.toString('latin1')))console.log(file);
  }catch{}
 }
}
for(const dir of ['assets/offline_assets/midis','E:/proyectos/CoroLLDM/public/offline_assets/midis','C:/Users/Huri_/Documents/proyectos/IosCoroLLDM/assets/offline_assets/midis','C:/Users/Huri_/Downloads'])scan(dir);
