from pathlib import Path
import zipfile,json,sqlite3,re
out=Path('output/lldm_comunidad/2026-10-15');z=zipfile.ZipFile(out/'base.apk')
for f in ['assets/capacitor.config.json','assets/capacitor.plugins.json']:
 j=json.loads(z.read(f));print(f, json.dumps(j,ensure_ascii=False)[:2200])
for n in z.namelist():
 if n.startswith('assets/public/') and (n.endswith('.js') or n.endswith('.html')):
  f=out/'web'/n.removeprefix('assets/public/');f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(z.read(n))
libwords=['OpenSheetMusicDisplay','opensheetmusicdisplay','verovio','VexFlow','vexflow','alphaTab','musicxml','MusicXML','@angular','ionic','Tone.js','soundfont','midi-player-js','pdfjs','MIDIPlayer','lector interactivo']
hits=[]
for f in (out/'web').rglob('*.js'):
 s=f.read_text(encoding='utf-8',errors='replace');found=[w for w in libwords if w.lower() in s.lower()]
 if found:hits.append({'file':f.name,'bytes':f.stat().st_size,'keywords':found})
print('JS indicators',json.dumps(hits,ensure_ascii=False))
db=out/'mainSQLite.db';db.write_bytes(z.read('assets/public/assets/databases/mainSQLite.db'))
conn=sqlite3.connect('file:'+str(db.resolve())+'?mode=ro',uri=True)
tables=conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
print('DATABASE TABLES',tables)
for (t,) in tables:
 if any(w in t.lower() for w in ['coro','canto','song','score','midi','partitura']):
  print('SCHEMA',t,conn.execute('PRAGMA table_info("'+t.replace('"','""')+'")').fetchall())
print('WASM',[n for n in z.namelist() if n.endswith('.wasm')])
