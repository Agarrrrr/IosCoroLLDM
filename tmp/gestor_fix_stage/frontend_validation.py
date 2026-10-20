from pathlib import Path
p=Path('E:/proyectos/CoroLLDM/src/api/remoteCatalogDB.js')
s=p.read_text(encoding='utf-8')
marker="    if (!hasHeader(bytes)) throw new Error(`El archivo seleccionado no es un ${type.toUpperCase()} válido.`);\n"
replacement=marker+'''    if (type === 'pdf') {
        const {PDFDocument} = await import('pdf-lib');
        const document = await PDFDocument.load(bytes, {ignoreEncryption:true});
        if (!document.getPageCount()) throw new Error('El PDF no tiene páginas.');
    } else {
        const {Midi} = await import('@tonejs/midi');
        const midi = new Midi(bytes);
        if (!midi.tracks.some(track => track.notes.length)) throw new Error('El MIDI no contiene notas.');
    }
'''
assert marker in s
s=s.replace(marker,replacement,1)
p.write_text(s,encoding='utf-8',newline='\n')
# Link ambiguous aliases must not cause accidental cross-work merges.
PY=''
print('Frontend validates PDF pages and MIDI notes before upload.')
