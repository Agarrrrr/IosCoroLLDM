import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { PDFDocument } = require('pdf-lib');
const { Midi } = require('@tonejs/midi');
const key = crypto.createHash('sha256').update('repertorio-coral-lldm-key-2026').digest();

export function readCatalog(file) {
  const rows = JSON.parse(fs.readFileSync(file, 'utf8'));
  validateCatalog(rows);
  return rows;
}

export function validateCatalog(rows) {
  if (!Array.isArray(rows)) throw new Error('El catálogo no es una lista.');
  const ids = new Set();
  for (const row of rows) {
    if (!row || typeof row.id !== 'string' || !row.id.trim() ||
        typeof row.nombre !== 'string' || !row.nombre.trim() ||
        typeof row.archivo !== 'string' || !row.archivo.trim())
      throw new Error('Hay un canto sin ID, título o PDF válido.');
    if (ids.has(row.id)) throw new Error(`ID duplicado: ${row.id}`);
    ids.add(row.id);
  }
}

// Titles never determine identity. Keep the destination's stable IDs.
export function mergeCatalog(existing, updates, { rejectOlder = false } = {}) {
  validateCatalog(existing); validateCatalog(updates);
  const rows = new Map(existing.map(row => [row.id, { ...row }]));
  for (const update of updates) {
    const previous = rows.get(update.id);
    if (!previous) {
      const alias = update.external_id && existing.find(row =>
        row.id === update.external_id || row.external_id === update.external_id);
      if (alias) throw new Error(`La migración de ${update.id} requiere una correspondencia explícita; no se cambiará ${alias.id}.`);
      rows.set(update.id, { ...update });
      continue;
    }
    const oldVersion = Number(previous.version || 1);
    const newVersion = Number(update.version || 1);
    if (!Number.isFinite(newVersion) || newVersion < 1) throw new Error('Versión inválida.');
    if (newVersion < oldVersion) {
      if (rejectOlder) throw new Error(`El canto ${update.id} tiene una versión más reciente en el destino.`);
      continue;
    }
    const merged = { ...previous, ...update, id: previous.id };
    if (previous.midi_archivo && !update.midi_archivo) merged.midi_archivo = previous.midi_archivo;
    // An existing local PDF must never be replaced by an HTTP dependency.
    for (const field of ['archivo', 'midi_archivo']) {
      if (previous[field] && !/^https?:/i.test(previous[field]) && /^https?:/i.test(update[field] || ''))
        merged[field] = previous[field];
    }
    rows.set(update.id, merged);
  }
  return [...rows.values()].sort((a,b) => a.nombre.localeCompare(b.nombre, 'es', {numeric:true, sensitivity:'base'}));
}

export function assetPath(root, type, objectKey) {
  if (typeof objectKey !== 'string' || !objectKey || /^https?:/i.test(objectKey))
    throw new Error(`El ${type} debe tener una ruta local.`);
  const base = path.resolve(root, 'offline_assets', type === 'pdf' ? 'pdfs' : 'midis');
  const target = path.resolve(base, objectKey);
  const rel = path.relative(base, target);
  if (!rel || rel === '..' || rel.startsWith(`..${path.sep}`) || path.isAbsolute(rel))
    throw new Error('La ruta sale del directorio de recursos.');
  return target;
}

export function clearAsset(raw) {
  const bytes = Buffer.from(raw);
  if (bytes.subarray(0,4).equals(Buffer.from('%PDF')) || bytes.subarray(0,4).equals(Buffer.from('MThd'))) return bytes;
  if (bytes.length < 28) throw new Error('Archivo cifrado incompleto.');
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, bytes.subarray(0,12));
  decipher.setAuthTag(bytes.subarray(-16));
  return Buffer.concat([decipher.update(bytes.subarray(12,-16)), decipher.final()]);
}

export async function validateAsset(raw, type) {
  const clear = clearAsset(raw);
  if (type === 'pdf') {
    if (!clear.subarray(0,4).equals(Buffer.from('%PDF'))) throw new Error('El archivo no es un PDF.');
    const pdf = await PDFDocument.load(clear, {ignoreEncryption:true});
    if (!pdf.getPageCount()) throw new Error('El PDF no tiene páginas.');
  } else {
    if (!clear.subarray(0,4).equals(Buffer.from('MThd')) || clear.length < 14) throw new Error('El archivo no es un MIDI.');
    const headerSize = clear.readUInt32BE(4);
    if (headerSize < 6 || 8 + headerSize > clear.length) throw new Error('Cabecera MIDI incompleta.');
    let offset = 8 + headerSize, tracks = 0;
    while (offset < clear.length) {
      if (offset + 8 > clear.length) throw new Error('Bloque MIDI incompleto.');
      const length = clear.readUInt32BE(offset + 4);
      if (offset + 8 + length > clear.length) throw new Error('Pista MIDI truncada.');
      if (clear.toString('ascii',offset,offset+4) === 'MTrk') tracks++;
      offset += 8 + length;
    }
    if (!tracks || tracks !== clear.readUInt16BE(10)) throw new Error('Número de pistas MIDI inválido.');
    const midi = new Midi(clear);
    if (!midi.tracks.some(track => track.notes.length)) throw new Error('El MIDI no contiene notas.');
  }
  return clear;
}

export async function encodeDataUrl(data, type) {
  if (typeof data !== 'string' || !/^data:[^,]*;base64,/i.test(data)) throw new Error('Archivo de carga inválido.');
  const payload = data.slice(data.indexOf(',')+1);
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(payload) || payload.length % 4) throw new Error('Base64 inválido.');
  const clear = await validateAsset(Buffer.from(payload,'base64'), type);
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm',key,iv);
  return Buffer.concat([iv,cipher.update(clear),cipher.final(),cipher.getAuthTag()]);
}

// All destinations are staged first. On a rename failure restore every original.
export function writeTransaction(entries) {
  const byPath = new Map(entries.map(entry => [path.resolve(entry.path), Buffer.from(entry.bytes)]));
  const staged = [];
  try {
    for (const [target, bytes] of byPath) {
      fs.mkdirSync(path.dirname(target), {recursive:true});
      const previous = fs.existsSync(target) ? fs.readFileSync(target) : null;
      if (previous?.equals(bytes)) continue;
      const temp = `${target}.${crypto.randomUUID()}.tmp`;
      const item = {target,temp,previous,committed:false}; staged.push(item);
      fs.writeFileSync(temp,bytes,{flag:'wx'});
    }
    for (const item of staged) { fs.renameSync(item.temp,item.target); item.committed=true; }
  } catch (error) {
    const failures=[];
    for (const item of staged.reverse()) {
      try {
        if (item.committed) {
          if (item.previous === null) fs.rmSync(item.target,{force:true});
          else fs.writeFileSync(item.target,item.previous);
        }
      } catch (rollback) { failures.push(rollback.message); }
    }
    if (failures.length) throw new Error(`${error.message}; recuperación incompleta: ${failures.join('; ')}`);
    throw error;
  } finally {
    for (const item of staged) if (fs.existsSync(item.temp)) fs.rmSync(item.temp,{force:true});
  }
}

export async function planAsset(root, type, objectKey, sources, dataUrl) {
  const target = assetPath(root,type,objectKey);
  let bytes;
  if (dataUrl) bytes = await encodeDataUrl(dataUrl,type);
  else if (fs.existsSync(target)) bytes = fs.readFileSync(target);
  else {
    const source = sources.map(dir => assetPath(dir,type,objectKey)).find(file => fs.existsSync(file));
    if (!source) throw new Error(`Falta el ${type} offline: ${objectKey}. Adjunta o sincroniza el archivo antes de guardar.`);
    bytes = fs.readFileSync(source);
  }
  await validateAsset(bytes,type);
  return {path:target,bytes};
}

export const catalogEntry = (file, rows) => ({path:file,bytes:Buffer.from(JSON.stringify(rows,null,2))});
