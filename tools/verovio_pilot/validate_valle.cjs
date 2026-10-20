const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const out=path.resolve('output/verovio_pilot_support/valle');
const verovio=require('../../output/verovio_pilot/assets/reader/verovio-toolkit-wasm.js');
verovio.module.onRuntimeInitialized=()=>{
 try {
  const tk=new verovio.toolkit();
  tk.setOptions({scale:40,pageWidth:2100,pageHeight:2970,breaks:'auto',condense:'none',
   header:'auto',footer:'none',lyricSize:4,lyricWordSpace:2.5,spacingStaff:14,spacingSystem:16,svgViewBox:true});
  const source=process.argv[2]||path.join(out,'Valle de los Huesos Secos - SATB con letra.musicxml');
  assert(tk.loadData(fs.readFileSync(source,'utf8')));
  const mei=tk.getMEI(), pages=tk.getPageCount();
  const report={pages,notes:(mei.match(/<note\b/g)||[]).length,
    ties:(mei.match(/<tie\b/g)||[]).length,slurs:(mei.match(/<slur\b/g)||[]).length};
  assert.equal(report.notes,2451);assert.equal(report.ties,54);assert.equal(report.slurs,1);
  for(const match of mei.matchAll(/<tie\b([^>]+)>/g)){
    const start=/startid="([^"]+)"/.exec(match[1]),end=/endid="([^"]+)"/.exec(match[1]);
    assert(start&&end&&start[1]!==end[1],'Tie must join two distinct notes');
  }
  for(let p=1;p<=pages;p++)fs.writeFileSync(path.join(out,`verovio-${p}.svg`),tk.renderToSVG(p));
  fs.writeFileSync(path.join(out,'verovio-validation.json'),JSON.stringify(report,null,2));
  console.log(report);tk.destroy();
 }catch(e){console.error(e);process.exitCode=1;}
};
