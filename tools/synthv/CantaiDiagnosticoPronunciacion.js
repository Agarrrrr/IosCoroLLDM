function getClientInfo(){return {name:'Cantai - Diagnostico pronunciacion',author:'Cantai',versionNumber:4,minEditorVersion:0x020101};}
function main(){
 var project=SV.getProject();
 for(var z=project.getNumNoteGroupsInLibrary()-1;z>=0;z--){var old=project.getNoteGroup(z);if(old&&old.getName()==='Cantai TEMP prueba fonemas')project.removeNoteGroup(z);}
 var track=SV.getMainEditor().getCurrentTrack(),voice=track.getGroupReference(0).getVoice();
 var g=SV.create('NoteGroup');g.setName('Cantai TEMP prueba fonemas');
 var words=['yoes','+','+','+','+','+','+','+','a'];
 for(var i=0;i<words.length;i++){var n=SV.create('Note');n.setPitch(60);n.setLanguageOverride('spanish');n.setTimeRange(i*SV.QUARTER,SV.QUARTER);n.setLyrics(words[i]);g.addNote(n);}
 var gi=project.addNoteGroup(g);var ref=SV.create('NoteGroupReference');ref.setTarget(project.getNoteGroup(gi));ref.setVoice(voice);ref.setMuted(true);var ri=track.addGroupReference(ref);
 function poll(k){try{var current=track.getGroupReference(ri),data=SV.getPhonemesForGroup(current);if((!data||data.length<words.length)&&k<30){SV.setTimeout(200,function(){poll(k+1)});return;}var msg=JSON.stringify(data);project.removeNoteGroup(gi);SV.showMessageBox('Cantai prueba ESPANOL',msg);SV.finish();}catch(e){SV.showMessageBox('Cantai prueba error',String(e));SV.finish();}}
 SV.setTimeout(300,function(){poll(0)});
}
