import{a as _,b as m}from"./chunk-BZ5N7KOH.js";import{a as o}from"./chunk-PLDZ6BDU.js";import{o as a,r,y}from"./chunk-T2S575GI.js";import{h as i}from"./chunk-WWX6BADO.js";var p=(()=>{let n=class n{constructor(e){this.sqlite=e,this._lastToggled=y(null),this.lastToggled=this._lastToggled.asReadonly()}clearLastToggled(){this._lastToggled.set(null)}getTypes(){return i(this,null,function*(){return this.sqlite.query('SELECT id, name_es, name_en, "index" FROM hymnal_type ORDER BY "index" ASC')})}getHymnalsByType(e){return i(this,null,function*(){return this.sqlite.query(`SELECT h.id, h.title_es, h.title_en, h.favorite, hht.number, hht.hymnal_type_id AS type_id
       FROM hymnal h
       INNER JOIN hymnal_hymnal_type hht ON hht.hymnal_id = h.id
       WHERE hht.hymnal_type_id = ?
       ORDER BY hht.number ASC, h.title_es ASC`,[e])})}searchHymnals(e,h){return i(this,null,function*(){let l=`%${_(h.trim()).toLowerCase()}%`;return this.sqlite.query(`SELECT h.id, h.title_es, h.title_en, h.favorite, hht.number, hht.hymnal_type_id AS type_id
       FROM hymnal h
       INNER JOIN hymnal_hymnal_type hht ON hht.hymnal_id = h.id
       WHERE hht.hymnal_type_id = ?
         AND (
           ${m("h.title_es")} LIKE ?
           OR CAST(hht.number AS TEXT) LIKE ?
         )
       ORDER BY hht.number ASC, h.title_es ASC`,[e,l,l])})}getFavorites(){return i(this,null,function*(){return this.sqlite.query(`SELECT h.id, h.title_es, h.title_en, h.favorite,
              (SELECT MIN(hht.number) FROM hymnal_hymnal_type hht WHERE hht.hymnal_id = h.id) AS number,
              (SELECT hht.hymnal_type_id FROM hymnal_hymnal_type hht WHERE hht.hymnal_id = h.id LIMIT 1) AS type_id
       FROM hymnal h
       WHERE h.favorite = 1
       ORDER BY h.title_es ASC`)})}getHymnalDetail(e){return i(this,null,function*(){let h=yield this.sqlite.query(`SELECT h.id, h.title_es, h.title_en, h.verses_es, h.verses_en, h.favorite,
              (SELECT MIN(hht.number) FROM hymnal_hymnal_type hht WHERE hht.hymnal_id = h.id) AS number
       FROM hymnal h
       WHERE h.id = ?
       LIMIT 1`,[e]);if(!h.length)return null;let t=h[0];return{id:t.id,title_es:t.title_es,title_en:t.title_en,number:t.number,favorite:t.favorite??0,verses_es:t.verses_es?JSON.parse(t.verses_es):[],verses_en:t.verses_en?JSON.parse(t.verses_en):[]}})}getByTitle(e){return i(this,null,function*(){return(yield this.sqlite.query(`SELECT h.id, h.title_es, h.title_en, h.favorite,
              hht.number, hht.hymnal_type_id AS type_id
       FROM hymnal h
       LEFT JOIN hymnal_hymnal_type hht ON hht.hymnal_id = h.id
       WHERE h.title_es = ? OR h.title_en = ?
       ORDER BY hht.number ASC
       LIMIT 1`,[e,e]))[0]??null})}toggleFavorite(e){return i(this,null,function*(){let t=(yield this.sqlite.query("SELECT favorite FROM hymnal WHERE id = ?",[e]))[0]?.favorite?0:1;return yield this.sqlite.run("UPDATE hymnal SET favorite = ? WHERE id = ?",[t,e]),this._lastToggled.set({id:e,favorite:t===1}),t===1})}};n.\u0275fac=function(h){return new(h||n)(r(o))},n.\u0275prov=a({token:n,factory:n.\u0275fac,providedIn:"root"});let s=n;return s})();export{p as a};
