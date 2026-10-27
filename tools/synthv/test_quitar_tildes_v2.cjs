const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const source = fs.readFileSync(__dirname + '/CantaiQuitarTildes.js', 'utf8');
function note(text, phones = 'old phones') {
    return {
        lyrics: text, phones, lang: '', attrs: {phonemes: [{leftOffset: .1}], loudness: .25},
        pitch: 64, onset: 960, duration: 1920, data: {},
        getLyrics() { return this.lyrics; }, setLyrics(v) { this.lyrics = v; },
        getPhonemes() { return this.phones; }, setPhonemes(v) { this.phones = v; },
        getLanguageOverride() { return this.lang; }, setLanguageOverride(v) { this.lang = v; },
        getAttributes() { return structuredClone(this.attrs); }, setAttributes(v) { Object.assign(this.attrs, v); },
        getScriptData(k) { return this.data[k]; }, setScriptData(k, v) { this.data[k] = v; },
        getIndexInParent() { return notes.indexOf(this); }, setPitch(p) { this.pitch = p; },
        setTimeRange(q,d) { this.onset=q; this.duration=d; }
    };
}
const notes = [note('Oración,'), note('NAASÓN'), note('a\u0301rbol'), note('niño pingüino.'),
    note('-'), note('.pau'), note('yoés'), note('ción'), note('+','n'),
    note('Palóma','p a'), note('+',''), note('+','')];
const group = {getUUID: () => 'original', getNumNotes: () => notes.length, getNote: i => notes[i]};
const ref = {isInstrumental: () => false, getTarget: () => group, getParent: () => track};
const track = {refs: [ref], addGroupReference(r) { this.refs.push(r); return this.refs.length-1; },
    getGroupReference(i) { return this.refs[i]; }, getNumGroups() { return this.refs.length; }};
const pool=[];
const project={
    addNoteGroup(g) { g.index=pool.length; pool.push(g); return g.index; },
    getNoteGroup(v) { return typeof v==='number' ? pool[v] : pool.find(g=>g && g.getUUID()===v); },
    removeNoteGroup(i) { const g=pool[i]; track.refs=track.refs.filter(r=>r.getTarget()!==g); pool[i]=null; },
    getNumTracks:()=>1, getTrack:()=>track
};
let operation = 0, failProbe = false;
const messages = [];
// Per-syllable '+' fixtures reproduce the truncation: yoes starts with y o,
// then the remaining e s arrives on the next probe note.
const pronunciations={
    'Oracion,':['o','r a','s i o n'], 'NAASON':['n a','a','s o n'],
    'arbol':['a r','b o l'], 'ninyopinghuino.':['n i','n y o','p i N','g U i','n o'],
    'yoes':['y o','e s'], 'cion':['s i o n'], 'Paloma':['p a','l o','m a']
};
const SV = {
    getHostInfo: () => ({hostVersionNumber: 0x020201}),
    QUARTER: 960,
    getMainEditor: () => ({getSelection: () => ({getSelectedNotes: () => []}), getCurrentGroup: () => ref}),
    getProject: () => project, showCustomDialog: () => ({status: true, answers: {operation, scope: 1}}),
    showMessageBox: (_, text) => messages.push(text),
    showMessageBoxAsync: (_,text,cb)=>{messages.push(text);cb();}, finish() {},
    setTimeout: (_, cb) => cb(),
    create(type) {
        if(type==='Note') return note('','');
        if(type==='NoteGroup') return {notes:[], setName(){},addNote(n){this.notes.push(n);},
            getNumNotes(){return this.notes.length;}, getNote(i){return this.notes[i];},
            getUUID(){return 'probe-'+this.index;},getIndexInParent(){return this.index;}};
        if(type==='NoteGroupReference') return {setTarget(g){this.group=g;},getTarget(){return this.group;},setMuted(v){assert.equal(v,true);}};
        throw Error(type);
    },
    getPhonemesForGroup(r) {
        if(failProbe) throw Error('Simulated engine failure');
        let pending=[];
        return r.getTarget().notes.map(n=>{
            if(n.lyrics!=='+') { assert.ok(pronunciations[n.lyrics],n.lyrics); pending=[...pronunciations[n.lyrics]]; }
            return pending.shift() || '';
        });
    }
};
const ctx = vm.createContext({SV});
vm.runInContext(source, ctx);
ctx.main();
assert.deepEqual(notes.map(n=>n.lyrics),['Oracion,','NAASON','arbol','niño pingüino.','-','.pau','yoes','cion','+','Paloma','+','+']);
assert.equal(notes[0].phones,'o r a s i o n');
assert.equal(notes[0].lang,'spanish');
assert.equal(notes[0].attrs.phonemes.length,0);
assert.equal(notes[3].phones,'old phones');
assert.equal(notes[6].phones,'y o e s');
assert.equal(notes[7].phones,'s i o n');
assert.equal(notes[8].phones,'n');
assert.equal(notes[9].phones,'');
assert.equal(notes[10].phones,'');
assert.equal(track.refs.length,1);
for(const n of notes) assert.deepEqual([n.pitch,n.onset,n.duration,n.attrs.loudness],[64,960,1920,.25]);
operation=1;ctx.main();
assert.equal(notes[0].data[ctx.KEY].beforeLyrics,'Oración,');
assert.equal(notes[6].phones,'y o e s');
assert.notEqual(notes[3].phones,'old phones');
assert.equal(notes[3].phones,'n i J o p i N g U i n o');
assert.equal(notes[8].phones,'n');
notes[1].phones='my later correction';
operation=2;ctx.main();
assert.equal(notes[0].lyrics,'Oración,');
assert.equal(notes[0].phones,'old phones');
assert.equal(notes[0].lang,'');
assert.equal(notes[0].attrs.phonemes[0].leftOffset,.1);
assert.equal(notes[1].phones,'my later correction');
assert.equal(notes[2].lyrics,'a\u0301rbol');
assert.equal(notes[3].phones,'old phones');
assert.equal(notes[6].lyrics,'yoés');
assert.equal(notes[9].phones,'p a');
// Failure cannot partially rewrite lyrics or leave a probe in the song.
const before=notes.map(n=>JSON.stringify([n.lyrics,n.phones,n.lang,n.attrs]));
operation=0;failProbe=true;ctx.main();
assert.deepEqual(notes.map(n=>JSON.stringify([n.lyrics,n.phones,n.lang,n.attrs])),before);
assert.equal(track.refs.length,1);
assert.equal(ctx.probeSpelling('señor pingüino'), 'senyor pinghuino');
assert.equal(ctx.completePhones('señor','s e n y o r'), 's e J o r');
assert.equal(ctx.completePhones('niño','n i o'), null);
assert.equal(ctx.completePhones('pingüino','p i N g i n o'), null);
assert.equal(ctx.completePhones('ñandú y Enya','n y a n d u i e n y a'), null);
assert.equal(ctx.completePhones('ü','u'), null);
console.log('PASS: full G2P, yoes, sion+n, distributed +, accents, timing, restore, later edits, failure cleanup.');
