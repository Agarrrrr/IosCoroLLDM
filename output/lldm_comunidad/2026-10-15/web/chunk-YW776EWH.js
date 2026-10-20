import{a as v,b as d}from"./chunk-BZ5N7KOH.js";import{a as S}from"./chunk-PLDZ6BDU.js";import{o as u,r as m}from"./chunk-T2S575GI.js";import{a as R,b as _,h as i}from"./chunk-WWX6BADO.js";var N=3,p=300,O=(()=>{let n=class n{constructor(e){this.sqlite=e}getTestaments(){return i(this,null,function*(){return this.sqlite.query("SELECT id, name FROM bible_testament ORDER BY id ASC")})}getBooksByTestament(e){return i(this,null,function*(){return this.sqlite.query(`SELECT b.id, b.testament_id, b.name, b.abbreviation,
              (SELECT MAX(v.chapter) FROM bible_verse v WHERE v.book_id = b.id) AS chapters
       FROM bible_book b
       WHERE b.testament_id = ?
       ORDER BY b.id ASC`,[e])})}searchBooks(e){return i(this,null,function*(){let s=`%${v(e.trim()).toLowerCase()}%`;return this.sqlite.query(`SELECT b.id, b.testament_id, b.name, b.abbreviation,
              (SELECT MAX(v.chapter) FROM bible_verse v WHERE v.book_id = b.id) AS chapters
       FROM bible_book b
       WHERE ${d("b.name")} LIKE ?
       ORDER BY b.id ASC`,[s])})}getBook(e){return i(this,null,function*(){return(yield this.sqlite.query(`SELECT b.id, b.testament_id, b.name, b.abbreviation,
              (SELECT MAX(v.chapter) FROM bible_verse v WHERE v.book_id = b.id) AS chapters
       FROM bible_book b
       WHERE b.id = ? LIMIT 1`,[e]))[0]??null})}getVerses(e,t){return i(this,null,function*(){return yield this.ensureNoteTable(),this.sqlite.query(`SELECT v.id, v.book_id, v.chapter, v.verse, v.text, v.marked,
              n.text AS note
       FROM bible_verse v
       LEFT JOIN bible_note n ON n.verse_id = v.id
       WHERE v.book_id = ? AND v.chapter = ?
       ORDER BY v.verse ASC`,[e,t])})}ensureNoteTable(){return this.noteTableReady||(this.noteTableReady=this.sqlite.run(`CREATE TABLE IF NOT EXISTS bible_note (
           verse_id   INTEGER PRIMARY KEY,
           text       TEXT NOT NULL,
           updated_at TEXT
         )`).catch(()=>{this.noteTableReady=void 0})),this.noteTableReady}saveNote(e,t){return i(this,null,function*(){yield this.ensureNoteTable();let s=(t||"").trim();if(!s)return this.deleteNote(e);yield this.sqlite.run("INSERT OR REPLACE INTO bible_note (verse_id, text, updated_at) VALUES (?, ?, ?)",[e,s,new Date().toISOString()])})}deleteNote(e){return i(this,null,function*(){yield this.ensureNoteTable(),yield this.sqlite.run("DELETE FROM bible_note WHERE verse_id = ?",[e])})}listNotes(){return i(this,null,function*(){return yield this.ensureNoteTable(),this.sqlite.query(`SELECT n.verse_id, n.text AS note, n.updated_at,
              v.text, v.book_id, v.chapter, v.verse,
              b.name AS book_name, b.abbreviation
       FROM bible_note n
       INNER JOIN bible_verse v ON v.id = n.verse_id
       INNER JOIN bible_book  b ON b.id = v.book_id
       ORDER BY n.updated_at DESC`)})}searchVerses(e){return i(this,null,function*(){let t=this.tokenize(e);return!t.length||e.trim().length<N?[]:(yield this.hasFts())?this.searchVersesFts(t):this.searchVersesLike(t)})}tokenize(e){return e.trim().toLowerCase().split(/[^\p{L}\p{N}]+/u).filter(Boolean)}hasFts(){return i(this,null,function*(){if(this.ftsAvailable===void 0)try{let e=yield this.sqlite.query(`SELECT count(*) AS n FROM sqlite_master
           WHERE type = 'table' AND name = 'bible_verse_fts'`);this.ftsAvailable=(e[0]?.n??0)>0}catch{this.ftsAvailable=!1}return this.ftsAvailable})}searchVersesFts(e){return i(this,null,function*(){let t=e.map((s,a)=>a===e.length-1?`"${s}"*`:`"${s}"`).join(" ");return this.sqlite.query(`SELECT v.id, v.book_id, b.name AS book_name, b.abbreviation,
              v.chapter, v.verse, v.text,
              snippet(bible_verse_fts, 0, '<mark>', '</mark>', '\u2026', 64) AS snippet
       FROM bible_verse_fts f
       INNER JOIN bible_verse v ON v.id = f.rowid
       INNER JOIN bible_book  b ON b.id = v.book_id
       WHERE bible_verse_fts MATCH ?
       ORDER BY v.book_id ASC, v.chapter ASC, v.verse ASC
       LIMIT ?`,[t,p])})}searchVersesLike(e){return i(this,null,function*(){let t=d("v.text"),s=e.map(()=>`${t} LIKE ?`).join(" AND "),a=e.map(r=>`%${v(r)}%`);return(yield this.sqlite.query(`SELECT v.id, v.book_id, b.name AS book_name, b.abbreviation,
              v.chapter, v.verse, v.text, v.text AS snippet
       FROM bible_verse v
       INNER JOIN bible_book b ON b.id = v.book_id
       WHERE ${s}
       ORDER BY v.book_id ASC, v.chapter ASC, v.verse ASC
       LIMIT ?`,[...a,p])).map(r=>_(R({},r),{snippet:this.highlight(r.text,e)}))})}highlight(e,t){let s=v(e).toLowerCase(),a=[];for(let b of t){let o=v(b),h=0,E;for(;(E=s.indexOf(o,h))!==-1;)a.push([E,E+o.length]),h=E+o.length}if(!a.length)return e;a.sort((b,o)=>b[0]-o[0]);let c="",r=0;for(let[b,o]of a)b<r||(c+=e.slice(r,b)+"<mark>"+e.slice(b,o)+"</mark>",r=o);return c+e.slice(r)}toggleMark(e){return i(this,null,function*(){let s=(yield this.sqlite.query("SELECT marked FROM bible_verse WHERE id = ?",[e]))[0]?.marked?0:1;return yield this.sqlite.run("UPDATE bible_verse SET marked = ? WHERE id = ?",[s,e]),s===1})}getMarkedVerses(){return i(this,null,function*(){return this.sqlite.query(`SELECT v.id, v.book_id, b.name AS book_name, b.abbreviation,
              v.chapter, v.verse, v.text
       FROM bible_verse v
       INNER JOIN bible_book b ON b.id = v.book_id
       WHERE v.marked = 1
       ORDER BY v.book_id ASC, v.chapter ASC, v.verse ASC`)})}};n.\u0275fac=function(t){return new(t||n)(m(S))},n.\u0275prov=u({token:n,factory:n.\u0275fac,providedIn:"root"});let l=n;return l})();export{N as a,p as b,O as c};
