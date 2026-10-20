const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const base=path.resolve('output/verovio_pilot/assets/scores');
const out=path.resolve('output/verovio_pilot_support/complete/render');fs.mkdirSync(out,{recursive:true});
const verovio=require('../../output/verovio_pilot/assets/reader/verovio-toolkit-wasm.js');
verovio.module.onRuntimeInitialized=()=>{
 try{
  const report=[];
  for(const score of JSON.parse(fs.readFileSync(path.join(base,'manifest.json'),'utf8'))){
   const toolkit=new verovio.toolkit();const started=Date.now();
   toolkit.setOptions({scale:36,pageWidth:1140,pageHeight:4200,adjustPageHeight:true,breaks:'auto',
    condense:'none',condenseFirstPage:true,condenseTempoPages:true,
    header:'none',footer:'none',lyricSize:3.6,lyricWordSpace:2.5,spacingStaff:14,spacingSystem:16,svgViewBox:true});
   assert(toolkit.loadData(fs.readFileSync(path.join(base,score.key+'.musicxml'),'utf8')));
   const mei=toolkit.getMEI();const events=JSON.parse(fs.readFileSync(path.join(base,score.key+'-events.json'),'utf8'));
   const ids=new Set([...mei.matchAll(/<note\b[^>]*xml:id="([^"]+)"/g)].map(m=>m[1]));
   const missing=events.filter(e=>!ids.has(e.id));assert.equal(missing.length,0,JSON.stringify(missing.slice(0,3)));
   assert.equal(new Set(events.map(e=>e.id)).size,ids.size,'all written notes have an audio mapping');
   let pages=toolkit.getPageCount(),firstStaffCount=0;
   for(let page=1;page<=pages;page++){
    const svg=toolkit.renderToSVG(page);fs.writeFileSync(path.join(out,score.key+'-'+page+'.svg'),svg);
    if(page===1){const system=svg.split('class="system"')[1]?.split('class="system"')[0]||svg;firstStaffCount=(system.match(/class="staff"/g)||[]).length;}
   }
   fs.writeFileSync(path.join(out,score.key+'.mei'),mei);
   const row={key:score.key,notes:ids.size,events:events.length,pages,mode:'structural validation; mobile sections and viewport differ',
    ties:(mei.match(/<tie\b/g)||[]).length,slurs:(mei.match(/<slur\b/g)||[]).length,beams:(mei.match(/<beam\b/g)||[]).length,
    milliseconds:Date.now()-started};report.push(row);console.log(row);
   assert(row.beams>0);assert(row.ties+row.slurs>0);
   toolkit.destroy();
  }
  fs.writeFileSync(path.join(out,'validation.json'),JSON.stringify(report,null,2));
 }catch(e){console.error(e);process.exitCode=1;}
};
