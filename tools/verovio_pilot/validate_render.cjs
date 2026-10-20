// Render through the same official engine bundled in the pilot, without a phone.
const fs = require('node:fs');
const path = require('node:path');
const base = path.resolve('output/verovio_pilot');
const out = path.resolve('output/verovio_pilot_support');
const verovio = require(path.join(base, 'assets/reader/verovio-toolkit-wasm.js'));
verovio.module.onRuntimeInitialized = () => {
  try {
    const report = [];
    for (const key of ['acercame', 'al-gran-senor']) {
      for (const layout of ['closed', 'open']) {
        const toolkit = new verovio.toolkit();
        toolkit.setOptions({scale:36,pageWidth:1140,pageHeight:4200,adjustPageHeight:true,
          breaks:'auto',header:'none',footer:'none',lyricSize:3.6,lyricWordSpace:2.5,spacingStaff:14,spacingSystem:18,svgViewBox:true});
        if (!toolkit.loadData(fs.readFileSync(path.join(base, `assets/scores/${key}-${layout}.musicxml`),'utf8'))) throw Error('load');
        toolkit.renderToMIDI();
        const timemap = toolkit.renderToTimemap();
        const notes=[];
        for (const entry of timemap) for (const id of entry.on||[]) {
          notes.push({id,notatedId:toolkit.getNotatedIdForElement(id),q:entry.qstamp,...toolkit.getMIDIValuesForElement(id)});
        }
        fs.writeFileSync(path.join(out,`${key}-${layout}.mei`),toolkit.getMEI());
        fs.writeFileSync(path.join(out,`${key}-${layout}-render.json`),JSON.stringify(notes,null,2));
        for(let page=1;page<=toolkit.getPageCount();page++) fs.writeFileSync(path.join(out,`${key}-${layout}-${page}.svg`),toolkit.renderToSVG(page));
        report.push({key,layout,version:toolkit.getVersion(),pages:toolkit.getPageCount(),notes:notes.length});
        toolkit.destroy();
      }
    }
    fs.writeFileSync(path.join(out,'render-report.json'),JSON.stringify(report,null,2));
    console.log(JSON.stringify(report));
  } catch(error) {console.error(error);process.exitCode=1;}
};
