/* Local notation and cursor; playback remains in our native MIDI engine. */
'use strict';
let engineReady=false,toolkit=null,pending=null,spans=[],active=new Set(),muted=[];
let lastSystem=null,currentTime=0,following=true,scale=36,initPoll=null;
let geometry=new Map(),anchors=[],clock={seconds:0,playing:false,speed:1,at:0},raf=0;
let layerRoles=new Map(),markRoles=new Map();
const NS='http://www.music-encoding.org/ns/mei';
function post(v){if(window.Pilot)Pilot.postMessage(JSON.stringify(v));}
function fail(e){document.getElementById('status').textContent='No se pudo preparar la partitura.';post({type:'error',message:String(e)});}
function initEngine(){if(engineReady)return;try{toolkit=new verovio.toolkit();engineReady=true;clearInterval(initPoll);post({type:'engine',version:toolkit.getVersion()});if(pending)renderPending();}catch(e){clearInterval(initPoll);fail(e);}}
verovio.module.onRuntimeInitialized=initEngine;
if(typeof verovio.module._vrvToolkit_constructor==='function')initEngine();
else initPoll=setInterval(()=>{if(typeof verovio.module._vrvToolkit_constructor==='function')initEngine();},50);
setTimeout(()=>{if(!engineReady){clearInterval(initPoll);fail('El motor no terminó de iniciar. Reintenta abrir la prueba.');}},20000);
window.loadScore=function(xml,layout,events,meta={}){currentTime=0;clock={seconds:0,playing:false,speed:1,at:performance.now()};if(raf){cancelAnimationFrame(raf);raf=0;}window.scrollTo(0,0);pending={xml,layout,events,meta};if(engineReady)renderPending();};
function renderPending(){
 const started=performance.now();
 try{
  const {xml,layout,events}=pending;
  toolkit.setOptions({scale,pageWidth:Math.round(window.innerWidth*100/scale),pageHeight:4200,
   adjustPageHeight:true,breaks:'auto',header:'none',footer:'none',font:'Leipzig',
   condense:layout==='mixed'?'auto':'none',condenseFirstPage:true,condenseTempoPages:true,
   lyricSize:3.6,lyricWordSpace:2.5,spacingStaff:14,spacingSystem:16,svgViewBox:true,xmlIdSeed:17});
  if(!toolkit.loadData(xml))throw Error('MusicXML no válido');
  const imported=new DOMParser().parseFromString(toolkit.getMEI(),'application/xml');
  const source=new DOMParser().parseFromString(xml,'application/xml');
  let edited=false;
  for(const note of source.querySelectorAll('note[id]')){
   const above=[...note.querySelectorAll('lyric[placement="above"]')];if(!above.length)continue;
   const target=[...imported.getElementsByTagNameNS(NS,'note')].find(n=>n.getAttributeNS('http://www.w3.org/XML/1998/namespace','id')===note.getAttribute('id'));
   if(target)for(const verse of target.getElementsByTagNameNS(NS,'verse'))if(above.some(l=>l.getAttribute('number')===verse.getAttribute('n'))){verse.setAttribute('place','above');edited=true;}
  }
  if(edited&&!toolkit.loadData(new XMLSerializer().serializeToString(imported)))throw Error('No se pudo preparar la disposición original');
  const mei=new DOMParser().parseFromString(toolkit.getMEI(),'application/xml');
  const ids=new Set([...mei.getElementsByTagNameNS(NS,'note')].map(n=>n.getAttributeNS('http://www.w3.org/XML/1998/namespace','id')));
  spans=events.map(e=>({...e,start:e.time,end:e.time+Math.max(.03,e.duration)})).sort((a,b)=>a.start-b.start||a.role-b.role);
  const missing=spans.filter(s=>!ids.has(s.id));if(missing.length)throw Error(missing.length+' notas sin identificador de notación');
  const container=document.getElementById('score');container.innerHTML='';active.clear();lastSystem=null;
  let renderedPages=0;layerRoles.clear();markRoles.clear();
  const noteRoles=new Map(spans.map(s=>[s.id,s.role]));
  function appendPages(renderer){
   const doc=new DOMParser().parseFromString(renderer.getMEI(),'application/xml'),roles=new Map(),layers=[...doc.getElementsByTagNameNS(NS,'layer')];
   const identity=l=>l.parentNode.getAttribute('n')+':'+l.getAttribute('n');
   for(const layer of layers){const note=[...layer.getElementsByTagNameNS(NS,'note')].find(n=>noteRoles.has(n.getAttributeNS('http://www.w3.org/XML/1998/namespace','id')));if(note)roles.set(identity(layer),noteRoles.get(note.getAttributeNS('http://www.w3.org/XML/1998/namespace','id')));}
   for(const layer of layers)layerRoles.set(layer.getAttributeNS('http://www.w3.org/XML/1998/namespace','id'),roles.get(identity(layer)));
   for(const tag of ['tie','slur'])for(const mark of doc.getElementsByTagNameNS(NS,tag))markRoles.set(mark.getAttributeNS('http://www.w3.org/XML/1998/namespace','id'),noteRoles.get(mark.getAttribute('startid')?.replace('#','')));
   for(let p=1;p<=renderer.getPageCount();p++){const page=document.createElement('section');page.className='score-page';page.dataset.page=++renderedPages;page.innerHTML=renderer.renderToSVG(p);container.appendChild(page);}
  }
  if(layout==='mixed'){
   // Separate engraving sections preserve the original 2 -> 3 staff change.
   for(const half of [0,1]){
    const section=source.cloneNode(true);
    for(const part of [...section.querySelectorAll('score-partwise > part')]){
     if(half===0&&part.getAttribute('id')==='P1'){part.remove();continue;}
     const measures=[...part.querySelectorAll('measure')],attributes=measures[0].querySelector('attributes').cloneNode(true);
     measures.forEach((m,i)=>{if(half===0?i>=8:i<8)m.remove();});
     if(half===1)part.querySelector('measure').prepend(attributes);
    }
    if(half===0)section.querySelector('score-part[id="P1"]').remove();
    else section.querySelector('score-part[id="P2"] part-name').textContent='A';
    const renderer=new verovio.toolkit();renderer.setOptions({...toolkit.getOptions(),condense:'none'});
    if(!renderer.loadData(new XMLSerializer().serializeToString(section)))throw Error('No se pudo abrir la sección coral');
    appendPages(renderer);renderer.destroy();
   }
  }else appendPages(toolkit);
  for(const bar of container.querySelectorAll('.barLine')){
   const paths=[...bar.querySelectorAll('path')],xs=paths.map(p=>(p.getAttribute('d')||'').match(/^M\s*(-?[\d.]+)/)?.[1]);
   if(!bar.querySelector('use')&&paths.length&&xs.every(x=>x!==undefined&&x===xs[0]))bar.classList.add('ordinary');
  }
  const first=new Map();for(const s of spans)if(!first.has(s.id))first.set(s.id,s);
  for(const note of container.querySelectorAll('.note')){
   const span=first.get(note.id);if(!span)continue;if(span.pitchVerified===false)note.classList.add('review');
   note.addEventListener('click',()=>{const occurrences=spans.filter(s=>s.id===note.id);post({type:'seek',seconds:(occurrences.find(s=>s.start>=currentTime-.2)||occurrences[0]).start});});
  }
  let cursor=document.getElementById('play-cursor');if(!cursor){cursor=document.createElement('div');cursor.id='play-cursor';document.body.appendChild(cursor);}
  document.getElementById('status').style.display='none';
  geometry.clear();
  for(const [id]of first){
   const note=document.getElementById(id);if(!note)continue;const head=note.querySelector('.notehead')||note,system=note.closest('.system');if(!system)continue;
   const nr=head.getBoundingClientRect(),sr=system.getBoundingClientRect();
   geometry.set(id,{x:nr.left+window.scrollX+nr.width/2,top:sr.top+window.scrollY,height:sr.height,system});
  }
  anchors=[];let previous=-1;
  for(const s of spans){if(Math.abs(s.start-previous)<.005)continue;const g=geometry.get(s.id);if(!g)continue;anchors.push({...g,time:s.start,end:s.end});previous=s.start;}
  document.getElementById('status').style.display='none';setMuted(muted);paint(currentTime,false);
  post({type:'ready',notes:ids.size,events:spans.length,lyrics:mei.getElementsByTagNameNS(NS,'syl').length,
   ties:mei.getElementsByTagNameNS(NS,'tie').length,slurs:mei.getElementsByTagNameNS(NS,'slur').length,beams:mei.getElementsByTagNameNS(NS,'beam').length,
   pages:renderedPages,milliseconds:Math.round(performance.now()-started),layout});
 }catch(e){fail(e);}
}
function paint(seconds,playing){
 currentTime=seconds;const next=new Set(spans.filter(s=>seconds>=s.start&&seconds<s.end&&!muted[s.role]).map(s=>s.id));
 for(const id of active)if(!next.has(id))document.getElementById(id)?.classList.remove('playing');
 for(const id of next)if(!active.has(id))document.getElementById(id)?.classList.add('playing');active=next;
 let lo=0,hi=anchors.length-1,index=-1;while(lo<=hi){const m=(lo+hi)>>1;if(anchors[m].time<=seconds){index=m;lo=m+1;}else hi=m-1;}
 const a=anchors[Math.max(0,index)],b=anchors[index+1],cursor=document.getElementById('play-cursor');if(!a||!cursor)return;
 let x=a.x;if(b&&b.system===a.system&&b.time>a.time)x=a.x+(b.x-a.x)*Math.max(0,Math.min(1,(seconds-a.time)/(b.time-a.time)));
 cursor.style.display='block';cursor.style.height=a.height+'px';cursor.style.transform='translate('+x+'px,'+a.top+'px)';cursor.style.left='0';cursor.style.top='0';
 if(playing&&following&&a.system!==lastSystem){lastSystem=a.system;const r=a.system.getBoundingClientRect();if(r.top<0||r.bottom>window.innerHeight)window.scrollTo({top:a.top-12,behavior:'smooth'});}
}
function animate(now){paint(clock.seconds+(clock.playing?Math.min(.3,(now-clock.at)/1000)*clock.speed:0),clock.playing);raf=clock.playing?requestAnimationFrame(animate):0;}
window.setPosition=function(seconds,playing,speed=1){clock={seconds,playing,speed,at:performance.now()};if(!raf){if(playing)raf=requestAnimationFrame(animate);else paint(seconds,false);}};
window.setMuted=function(v){
 muted=v;const roles=new Map(spans.map(s=>[s.id,s.role]));
 for(const layer of document.querySelectorAll('#score .layer')){
  const role=layerRoles.get(layer.id);
  for(const shape of layer.querySelectorAll('path,use,polygon,polyline,circle,ellipse,line')){
   if(shape.closest('.verse,.syl,.lyric'))continue;
   const note=shape.closest('.note'),owner=note?roles.get(note.id):role;
   shape.classList.toggle('voice-muted',owner!==undefined&&!!muted[owner]);
  }
 }
 const seen=new Set();for(const s of spans){if(seen.has(s.id))continue;seen.add(s.id);document.getElementById(s.id)?.classList.toggle('muted',!!muted[s.role]);}
 // Phrase marks live outside layers; inherit the starting note's voice.
 for(const mark of document.querySelectorAll('#score .tie,#score .slur')){
  const role=markRoles.get(mark.id);
  for(const shape of mark.querySelectorAll('path,use'))shape.classList.toggle('voice-muted',role!==undefined&&!!muted[role]);
 }
};
window.setFollow=function(v){following=v;};
window.changeScale=function(d){scale=Math.max(28,Math.min(58,scale+d));if(pending)renderPending();};
window.addEventListener('error',e=>fail(e.message));window.addEventListener('unhandledrejection',e=>fail(e.reason));

