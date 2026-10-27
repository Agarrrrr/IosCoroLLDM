// Strip Spanish vowel accents and ask the real group to regenerate pronunciation.
// Do not rewrite phonemes by character substitution: Spanish G2P needs context.
var TITLE = "Cantai - Quitar tildes y recalcular pronunciacion";
var KEY = "cantai.removeVowelAccents.v1";

function getClientInfo() {
    return {name: TITLE, author: "Cantai", versionNumber: 3, minEditorVersion: 0x020101};
}

function withoutAccents(text) {
    var accented = "áéíóúÁÉÍÓÚ", plain = "aeiouAEIOU";
    return text.replace(/[áéíóúÁÉÍÓÚ]/g, function (c) {
        return plain.charAt(accented.indexOf(c));
    }).replace(/([aeiouAEIOU])\u0301/g, "$1");
}

function normalLyrics(text) {
    var s = text.replace(/^\s+|\s+$/g, "");
    return /[a-záéíóúñü]/i.test(s) && s.charAt(0) !== "." &&
        !/^(?:br|sil|pau|cl)$/i.test(s);
}

function copy(value) {
    return JSON.parse(JSON.stringify(value));
}

function collect(scope) {
    var editor = SV.getMainEditor(), project = SV.getProject();
    var entries = [], seen = {};
    function add(ref, selected) {
        if (!ref || ref.isInstrumental()) return;
        var group = ref.getTarget(), id = group.getUUID();
        if (seen[id]) return;
        seen[id] = true;
        var notes = selected || [];
        if (!selected) {
            for (var i = 0; i < group.getNumNotes(); i++) notes.push(group.getNote(i));
        }
        if (notes.length) entries.push({group: group, ref: ref, notes: notes});
    }
    function track(t) {
        if (t) for (var i = 0; i < t.getNumGroups(); i++) add(t.getGroupReference(i), null);
    }
    if (scope === 0) {
        var selected = editor.getSelection().getSelectedNotes();
        if (selected.length) add(editor.getCurrentGroup(), selected);
    } else if (scope === 1) add(editor.getCurrentGroup(), null);
    else if (scope === 2) track(editor.getCurrentTrack());
    else for (var t = 0; t < project.getNumTracks(); t++) track(project.getTrack(t));
    return entries;
}

function tokens(text) {
    return (text || "").replace(/^\s+|\s+$/g, "").split(/\s+/).filter(function (p) {
        return p && p !== "sil" && p !== "pau";
    });
}

// Studio 2.2.1 drops non-ASCII letters in the script G2P path. Use tested
// ASCII spellings only for the muted probe; never change the displayed text.
function probeSpelling(text) {
    return text.replace(/n\u0303/gi, "ñ").replace(/u\u0308/gi, "ü")
        .replace(/ñ/gi, "ny").replace(/gü/gi, "ghu");
}

function completePhones(text, phones) {
    var normalized = text.replace(/n\u0303/gi, "ñ").replace(/u\u0308/gi, "ü");
    var nasalCount = (normalized.match(/ñ/gi) || []).length;
    var umlautCount = (normalized.match(/ü/gi) || []).length;
    if (umlautCount !== (normalized.match(/gü/gi) || []).length) return null;
    var parts = tokens(phones), matches = 0, result = [];
    var modern = SV.getHostInfo().hostVersionNumber >= 0x020300;
    for (var i = 0; i < parts.length; i++) {
        if (nasalCount && parts[i] === "n" && parts[i + 1] === "y") {
            result.push(modern ? "ny" : "J"); matches++; i++;
        } else result.push(parts[i]);
    }
    // An ambiguous surrogate must leave the user's original note intact.
    if (matches !== nasalCount) return null;
    if (umlautCount && result.filter(function (p) {return p === "U" || p === "W" || p === "w";}).length < umlautCount) return null;
    return result.join(" ");
}

// The engine can put only the first syllable on a one-note word. Obtain the
// complete Spanish G2P result on an isolated muted group before editing lyrics.
function queryComplete(entries, changes, ready, failed) {
    var project = SV.getProject(), blocks = [], byText = {}, uuid = null, ref = null;
    function cleanup() {
        if (!uuid) return;
        var g = project.getNoteGroup(uuid), index = g ? g.getIndexInParent() : null;
        ref = null; g = null; uuid = null;
        if (index !== null) project.removeNoteGroup(index);
    }
    function fail(error) {
        try { cleanup(); } catch (ignore) {}
        failed(error);
    }
    try {
        for (var i = 0; i < changes.length; i++) {
            var text = changes[i].after.replace(/\s+/g, ""), key = "$" + text;
            if (typeof byText[key] === "undefined") {
                byText[key] = blocks.length; blocks.push({text: text});
            }
            changes[i].block = byText[key];
        }
        var group = SV.create("NoteGroup"), q = 0;
        group.setName("Cantai TEMP tildes fonemas completos");
        function add(text) {
            var n = SV.create("Note"); n.setPitch(60); n.setLanguageOverride("spanish");
            n.setTimeRange(q, SV.QUARTER); n.setLyrics(text); group.addNote(n); q += SV.QUARTER;
        }
        for (var b = 0; b < blocks.length; b++) {
            var block = blocks[b]; block.start = group.getNumNotes();
            block.slots = Math.max(4, (block.text.match(/[aeiouü]/gi) || []).length + 2);
            add(probeSpelling(block.text));
            for (var j = 1; j < block.slots; j++) add("+");
            q += SV.QUARTER;
        }
        var gi = project.addNoteGroup(group); uuid = project.getNoteGroup(gi).getUUID();
        var probe = SV.create("NoteGroupReference"); probe.setTarget(project.getNoteGroup(gi)); probe.setMuted(true);
        var track = entries[0].ref.getParent(), ri = track.addGroupReference(probe);
        ref = track.getGroupReference(ri); group = null; probe = null;
        SV.setTimeout(300, function () { read(0); });
    } catch (error) { fail(error); }
    function read(attempt) {
        try {
            var data = SV.getPhonemesForGroup(ref), total = ref.getTarget().getNumNotes(), incomplete = false;
            if (!data || data.length < total) incomplete = true;
            else {
                for (var b = 0; b < blocks.length; b++) {
                    var block = blocks[b], all = [], ended = false, syllables = 0;
                    for (var j = 0; j < block.slots; j++) {
                        var part = tokens(data[block.start + j]);
                        if (!part.length) { ended = true; break; }
                        all = all.concat(part); syllables++;
                    }
                    block.complete = ended && all.length ? completePhones(block.text, all.join(" ")) : null;
                    block.syllables = syllables;
                    if (!block.complete) incomplete = true;
                }
            }
            if (incomplete && attempt < 60) {
                SV.setTimeout(150, function () { read(attempt + 1); }); return;
            }
            if (!data || data.length < total) throw new Error("El motor no devolvio los fonemas.");
            for (var i = 0; i < changes.length; i++) {
                var change = changes[i], result = blocks[change.block];
                if (!result.complete) { change.unavailable = true; continue; }
                var full = tokens(result.complete), last = full[full.length - 1];
                var tail = tokens(change.nextManualPhones);
                var fullWordThenHold = tail.length === 1 && tail[0] === last;
                var alreadyFull = tokens(change.sourcePhones).length >= full.length;
                // A real multisyllable '+' chain keeps the group's distribution;
                // a sustained syllable or manual final-consonant tail keeps the
                // whole word on the first note. Tail notes are never rewritten.
                var distributed = change.hasPlus && result.syllables > 1 && !fullWordThenHold && !alreadyFull;
                if (distributed && /[ñü\u0303\u0308]/i.test(change.after)) {
                    change.unavailable = true; continue;
                }
                change.afterPhones = distributed ? "" : result.complete;
            }
            cleanup(); ready();
        } catch (error) { fail(error); }
    }
}

function main() {
    var result = SV.showCustomDialog({
        title: TITLE, buttons: "OkCancel",
        message: "Quita á é í ó ú y recalcula la pronunciacion en espanol.\n" +
            "Conserva ñ, ü, espacios, puntuacion, notas, tiempos y dinamicas.\n" +
            "En las notas tratadas elimina los fonemas manuales y sus ajustes individuales.\n" +
            "Obtiene los fonemas completos sin recortar palabras como yoes.\n" +
            "Conserva las continuaciones + y -. No guarda el proyecto.",
        widgets: [
            {name: "operation", type: "ComboBox", label: "Operacion", default: 0,
             choices: ["Quitar tildes y recalcular SOLO las notas con tildes",
                       "Quitar tildes y recalcular TODAS las notas con letra",
                       "Restaurar los cambios guardados por este script"]},
            {name: "scope", type: "ComboBox", label: "Aplicar a",
             default: SV.getMainEditor().getSelection().getSelectedNotes().length ? 0 : 1,
             choices: ["Notas seleccionadas", "Grupo abierto", "Pista actual", "Todo el proyecto"]}
        ]
    });
    if (!result.status) { SV.finish(); return; }
    var entries = collect(result.answers.scope), changes = [], preserved = 0, examples = [];
    var restore = result.answers.operation === 2;
    for (var ei = 0; ei < entries.length; ei++) {
        var notes = entries[ei].notes;
        for (var ni = 0; ni < notes.length; ni++) {
            var note = notes[ni], before = note.getLyrics();
            if (restore) {
                var saved = note.getScriptData(KEY);
                if (!saved) continue;
                if (before !== saved.afterLyrics || note.getPhonemes() !== (saved.afterPhones || "") ||
                    note.getLanguageOverride() !== "spanish" ||
                    JSON.stringify(note.getAttributes().phonemes || []) !== "[]") {
                    preserved++;
                    continue;
                }
                changes.push({note: note, restore: saved});
            } else {
                if (!normalLyrics(before)) continue;
                var after = withoutAccents(before);
                if (after === before && result.answers.operation !== 1) continue;
                var index = note.getIndexInParent(), next = index + 1 < entries[ei].group.getNumNotes() ? entries[ei].group.getNote(index + 1) : null;
                changes.push({note: note, before: before, after: after,
                    sourcePhones: note.getPhonemes(), sourceLanguage: note.getLanguageOverride(),
                    sourcePhonemeAttributes: copy(note.getAttributes().phonemes || []),
                    hasPlus: !!next && next.getLyrics().replace(/^\s+|\s+$/g, "") === "+",
                    nextManualPhones: next ? next.getPhonemes() : ""});
            }
        }
    }
    if (!changes.length) {
        SV.showMessageBox(TITLE, restore ? "No hay cambios restaurables en el alcance elegido.\nEdiciones posteriores conservadas: " + preserved :
            "No hay notas con tildes en el alcance elegido.\nSi la letra ya no tiene tildes pero conserva fonemas viejos, elige la segunda operacion.");
        SV.finish(); return;
    }
    var applied = 0, unavailable = 0;
    function applyChanges() {
    try {
        for (var i = 0; i < changes.length; i++) {
            var change = changes[i], n = change.note;
            if (restore) {
                var snapshot = change.restore;
                n.setLyrics(snapshot.beforeLyrics);
                n.setLanguageOverride(snapshot.beforeLanguage);
                n.setPhonemes(snapshot.beforePhones);
                n.setAttributes({phonemes: copy(snapshot.beforePhonemeAttributes)});
                n.setScriptData(KEY, null);
            } else {
                if (change.unavailable) { unavailable++; continue; }
                if (n.getLyrics() !== change.before || n.getPhonemes() !== change.sourcePhones ||
                    n.getLanguageOverride() !== change.sourceLanguage ||
                    JSON.stringify(n.getAttributes().phonemes || []) !== JSON.stringify(change.sourcePhonemeAttributes)) {
                    preserved++; continue;
                }
                var previous = n.getScriptData(KEY);
                // Preserve the first snapshot when the operation is run repeatedly.
                if (!previous || previous.afterLyrics !== change.before || n.getPhonemes() !== (previous.afterPhones || "") ||
                    n.getLanguageOverride() !== "spanish" ||
                    JSON.stringify(n.getAttributes().phonemes || []) !== "[]") {
                    n.setScriptData(KEY, {
                        beforeLyrics: change.before, beforePhones: n.getPhonemes(),
                        beforeLanguage: n.getLanguageOverride(),
                        beforePhonemeAttributes: copy(n.getAttributes().phonemes || []),
                        afterLyrics: change.after, afterPhones: change.afterPhones
                    });
                } else {
                    previous = copy(previous); previous.afterLyrics = change.after; previous.afterPhones = change.afterPhones;
                    n.setScriptData(KEY, previous);
                }
                n.setLyrics(change.after);
                n.setLanguageOverride("spanish");
                n.setPhonemes(change.afterPhones);
                n.setAttributes({phonemes: []});
                if (examples.length < 5 && change.before !== change.after)
                    examples.push(change.before + " -> " + change.after);
            }
            applied++;
        }
    } catch (error) {
        SV.showMessageBox(TITLE, "Operacion interrumpida tras " + applied + " notas.\n" + String(error) +
            "\nUsa Restaurar en este script para recuperar los cambios guardados.");
        SV.finish(); return;
    }
    SV.showMessageBoxAsync(TITLE, (restore ? "Notas restauradas: " : "Notas tratadas: ") + applied +
        (examples.length ? "\n\n" + examples.join("\n") : "") +
        (preserved ? "\nEdiciones posteriores conservadas: " + preserved : "") +
        (unavailable ? "\nSin resultado fiable, conservadas: " + unavailable + "\nIncluye cadenas + de varias silabas con ñ o ü; no se altera su pronunciacion.": "") +
        (restore ? "" : "\n\nPronunciacion completa en espanol. Las cadenas + conservan su distribucion.\nEspera a que termine el renderizado antes de escuchar.") +
        "\nPuedes usar la operacion Restaurar para revertir este script.", function () { SV.finish(); });
    }
    if (restore) applyChanges();
    else queryComplete(entries, changes, applyChanges, function (error) {
        SV.showMessageBoxAsync(TITLE, "No se pudo consultar la pronunciacion completa.\n" + String(error) +
            "\nLas notas originales se conservaron.", function () { SV.finish(); });
    });
}
