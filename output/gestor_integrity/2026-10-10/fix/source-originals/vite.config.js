import { defineConfig } from 'vite';
import { resolve, join, relative, isAbsolute, dirname } from 'path';
import legacy from '@vitejs/plugin-legacy';
import crypto from 'crypto';
import fs from 'fs';

function extractInlineScriptsPlugin() {
  let config;
  return {
    name: 'extract-inline-scripts',
    apply: 'build', 
    enforce: 'post', 
    configResolved(resolvedConfig) {
      config = resolvedConfig;
    },
    transformIndexHtml: {
      order: 'post',
      handler(html, ctx) {
        if (!ctx.bundle) return html;

        const scriptRegex = /<script([^>]*?)>([\s\S]*?)<\/script>/gi;
        const base = config.base || '/';
        
        return html.replace(scriptRegex, (fullMatch, attrs, content) => {
          if (/src\s*=/i.test(attrs) || !content.trim()) return fullMatch;
          
          const typeMatch = attrs.match(/type\s*=\s*["']?([^"'\s>]+)["']?/i);
          const type = typeMatch ? typeMatch[1].toLowerCase() : '';
          const isExecutable = !type || ['module', 'text/javascript', 'application/javascript'].includes(type) || attrs.includes('nomodule');
          
          if (!isExecutable) return fullMatch;

          const hash = crypto.createHash('sha256').update(content).digest('hex').slice(0, 8);
          const fileName = `assets/legacy-inline-${hash}.js`;
          
          ctx.bundle[fileName] = {
            name: fileName,
            isAsset: true,
            type: 'asset',
            fileName: fileName,
            source: content
          };
          
          return `<script${attrs} src="${base}${fileName}"></script>`;
        });
      }
    }
  };
}

function gestorLocalCmsPlugin() {
  const projectsDir = process.env.COROLLDM_PROJECTS_DIR
    ? resolve(process.env.COROLLDM_PROJECTS_DIR)
    : resolve(__dirname, '..');
  const iosAssetsDir = process.env.IOS_COROLLDM_ASSETS_DIR
    ? resolve(process.env.IOS_COROLLDM_ASSETS_DIR)
    : join(projectsDir, 'IosCoroLLDM', 'assets');
  const repertorioBcAssetsDir = process.env.REPERTORIO_BC_ASSETS_DIR
    ? resolve(process.env.REPERTORIO_BC_ASSETS_DIR)
    : join(projectsDir, 'repertorio_bc', 'assets');
  const pwaAssetsDir = resolve(__dirname, 'public');

  function writeMergedCatalog(targetDir, catFile, sourceCatalog) {
    if (!fs.existsSync(targetDir)) return false;
    const targetPath = join(targetDir, catFile);
    const existing = fs.existsSync(targetPath)
      ? JSON.parse(fs.readFileSync(targetPath, 'utf8'))
      : [];
    const language = catFile === 'catalogo_en.json' ? 'en' : 'es';
    const key = song => `${song.idioma || song._idioma || language}:${String(song.nombre || '')
      .normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
      .replace(/[^a-z0-9]+/g, ' ').trim()}`;
    const sourceById = new Map(sourceCatalog.filter(song => song.id).map(song => [song.id, song]));
    const sourceByExternalId = new Map(
      sourceCatalog.filter(song => song.external_id).map(song => [song.external_id, song])
    );
    const sourceByKey = new Map(sourceCatalog.map(song => [key(song), song]));
    const consumed = new Set();
    const merged = existing.map(song => {
      const songKey = key(song);
      const global = sourceById.get(song.id)
        || sourceByExternalId.get(song.id)
        || (song.external_id ? sourceByExternalId.get(song.external_id) : null)
        || sourceByKey.get(songKey);
      if (!global) return song;
      consumed.add(key(global));
      const strongMatch = song.id === global.id
        || song.id === global.external_id
        || (song.external_id && song.external_id === global.external_id);
      if (strongMatch) {
        return { ...song, ...global, idioma: language, _idioma: language };
      }
      return {
        ...song,
        midi_archivo: song.midi_archivo || global.midi_archivo || null,
        idioma: language,
        _idioma: language,
      };
    });
    for (const song of sourceCatalog) {
      const songKey = key(song);
      if (!consumed.has(songKey)) merged.push(song);
    }
    const canonicalIds = new Set(sourceCatalog.map(song => song.id).filter(Boolean));
    const deduplicated = new Map();
    for (const song of merged) {
      const songKey = key(song);
      const current = deduplicated.get(songKey);
      if (!current || (canonicalIds.has(song.id) && !canonicalIds.has(current.id))) {
        deduplicated.set(songKey, song);
      }
    }
    const finalCatalog = [...deduplicated.values()];
    finalCatalog.sort((a, b) => String(a.nombre || '').localeCompare(
      String(b.nombre || ''), language, { sensitivity: 'base', numeric: true }
    ));
    fs.writeFileSync(targetPath, JSON.stringify(finalCatalog, null, 2));
    return true;
  }

  function encryptBuffer(buffer) {
    const encryptionKey = crypto.createHash('sha256')
      .update('repertorio-coral-lldm-key-2026')
      .digest();
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', encryptionKey, iv);
    const encrypted = Buffer.concat([cipher.update(buffer), cipher.final()]);
    return Buffer.concat([iv, encrypted, cipher.getAuthTag()]);
  }

  function decodeDataUrl(dataUrl) {
    if (typeof dataUrl !== 'string' || !dataUrl.startsWith('data:')) return null;
    const comma = dataUrl.indexOf(',');
    if (comma < 0) throw new Error('Data URL inválida');
    return Buffer.from(dataUrl.slice(comma + 1), 'base64');
  }

  function writeOfflineAsset(rootDir, type, objectKey, dataUrl) {
    if (!rootDir || !objectKey || !dataUrl) return false;
    const baseDir = resolve(rootDir, 'offline_assets', type === 'pdf' ? 'pdfs' : 'midis');
    const target = resolve(baseDir, objectKey);
    const targetRelative = relative(baseDir, target);
    if (targetRelative.startsWith('..' + '\\') || isAbsolute(targetRelative)) {
      throw new Error(`Clave de archivo inválida para ${type}: ${objectKey}`);
    }
    fs.mkdirSync(dirname(target), { recursive: true });
    fs.writeFileSync(target, encryptBuffer(decodeDataUrl(dataUrl)));
    return true;
  }

  function writeEncryptedOfflineAsset(rootDir, type, objectKey, bytes) {
    if (!rootDir || !objectKey || !bytes) return false;
    const baseDir = resolve(rootDir, 'offline_assets', type === 'pdf' ? 'pdfs' : 'midis');
    const target = resolve(baseDir, objectKey);
    const targetRelative = relative(baseDir, target);
    if (targetRelative === '..' || targetRelative.startsWith('..' + '\\') || isAbsolute(targetRelative)) {
      throw new Error(`Clave de archivo inválida para ${type}: ${objectKey}`);
    }
    fs.mkdirSync(dirname(target), { recursive: true });
    fs.writeFileSync(target, Buffer.from(bytes));
    return true;
  }

  function offlineAssetExists(rootDir, type, objectKey) {
    if (!rootDir || !objectKey) return false;
    const baseDir = resolve(rootDir, 'offline_assets', type === 'pdf' ? 'pdfs' : 'midis');
    const target = resolve(baseDir, objectKey);
    const targetRelative = relative(baseDir, target);
    if (targetRelative === '..' || targetRelative.startsWith('..' + '\\') || isAbsolute(targetRelative)) {
      return false;
    }
    return fs.existsSync(target);
  }

  return {
    name: 'gestor-local-cms',
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        if (req.url === '/__gestor_sync' && req.method === 'POST') {
          let bodyStr = '';
          req.on('data', chunk => bodyStr += chunk.toString());
          req.on('end', () => {
            try {
              const body = JSON.parse(bodyStr);
              const action = body.action;
              if (action === 'delete') {
                const { id } = body;
                ['catalogo.json', 'catalogo_en.json'].forEach(file => {
                  const path = resolve(__dirname, 'public/offline_assets', file);
                  if (fs.existsSync(path)) {
                    let catalogo = JSON.parse(fs.readFileSync(path, 'utf8'));
                    const filtered = catalogo.filter(c => c.id !== id);
                    if (filtered.length !== catalogo.length) {
                      fs.writeFileSync(path, JSON.stringify(filtered, null, 2));
                    }
                  }
                });
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true }));
              } else {
                res.writeHead(400); res.end('Invalid action');
              }
            } catch (err) {
              console.error('Error en gestor-local-cms:', err);
              res.writeHead(500, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ error: err.message }));
            }
          });
          return;
        }

        // --- Persistencia del catálogo remoto: tras guardar en Supabase/Cloudflare ---
        if (req.url === '/__gestor_sync_catalog' && req.method === 'POST') {
          let bodyStr = '';
          req.on('data', chunk => bodyStr += chunk.toString());
          req.on('end', async () => {
            try {
              const body = JSON.parse(bodyStr);
              const { action, canto, oldId, archivoData, midiData } = body;

              if (action === 'sync_remote_assets') {
                const { rows = [], apiUrl, accessToken } = body;
                if (!apiUrl || !accessToken) throw new Error('Falta la sesión autenticada para sincronizar archivos.');

                  const jobs = rows.flatMap(row =>
                  [['pdf', row.archivo], ['midi', row.midi_archivo]]
                    .filter(([, objectKey]) => objectKey && String(objectKey).startsWith('global/'))
                      .map(([type, objectKey]) => ({ row, type, objectKey }))
                  );
                  const results = await Promise.all(jobs.map(async ({ row, type, objectKey }) => {
                    try {
                      const localReady = offlineAssetExists(pwaAssetsDir, type, objectKey) &&
                        (!fs.existsSync(iosAssetsDir) || offlineAssetExists(iosAssetsDir, type, objectKey));
                      if (localReady) {
                        return { id: row.id, type, objectKey, ok: true, skipped: true };
                      }
                      const remoteUrl = `${String(apiUrl).replace(/\/+$/, '')}/v1/files/${row.id}/${type}`;
                    const remote = await fetch(remoteUrl, {
                      headers: { Authorization: `Bearer ${accessToken}` },
                      signal: AbortSignal.timeout(30000)
                    });
                      if (!remote.ok) {
                        const detail = await remote.text().catch(() => '');
                        let message = `Cloudflare respondió ${remote.status}`;
                        if (detail) {
                          try {
                            const parsed = JSON.parse(detail);
                            message += `: ${parsed.error || parsed.message || detail}`;
                          } catch {
                            message += `: ${detail.slice(0, 240)}`;
                          }
                        }
                        throw new Error(message);
                      }
                    const bytes = await remote.arrayBuffer();
                      writeEncryptedOfflineAsset(pwaAssetsDir, type, objectKey, bytes);
                    if (fs.existsSync(iosAssetsDir)) {
                      writeEncryptedOfflineAsset(iosAssetsDir, type, objectKey, bytes);
                    }
                    return { id: row.id, type, objectKey, ok: true };
                  } catch (error) {
                    return { id: row.id, type, objectKey, ok: false, error: error.message };
                  }
                }));

                const failed = results.filter(item => !item.ok);
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({
                  success: failed.length === 0,
                    synced: results.filter(item => item.ok && !item.skipped).length,
                    skipped: results.filter(item => item.ok && item.skipped).length,
                  failed: failed.length,
                  results
                }));
                return;
              }

              if (action === 'upsert' && canto) {
                const locale = canto._idioma || canto.idioma || 'es';
                const catFile = locale === 'es' ? 'catalogo.json' : 'catalogo_en.json';
                const catPath = resolve(__dirname, 'public/offline_assets', catFile);

                let catalogo = [];
                if (fs.existsSync(catPath)) {
                  catalogo = JSON.parse(fs.readFileSync(catPath, 'utf8'));
                }

                const norm = s => (s || '').toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "").replace(/[^a-z0-9\s]/gi, "").trim();
                const cantoNormName = norm(canto.nombre);
                const externalId = canto.external_id;

                // Limpiar campos internos del framework
                const toSave = { ...canto };
                delete toSave._idioma;
                delete toSave._nombre_norm;
                delete toSave._autor_norm;

                // Buscar índice existente por id, oldId, external_id o (nombre normalizado + idioma)
                let idx = catalogo.findIndex(c => {
                  if (c.id === canto.id) return true;
                  if (oldId && c.id === oldId) return true;
                  if (externalId && c.id === externalId) return true;
                  if (c.external_id && (c.external_id === canto.id || c.external_id === oldId || (externalId && c.external_id === externalId))) return true;
                  if (norm(c.nombre) === cantoNormName && (c.idioma || 'es') === locale) return true;
                  return false;
                });

                if (idx >= 0) {
                  catalogo[idx] = { ...catalogo[idx], ...toSave };
                } else {
                  catalogo.push(toSave);
                }

                // Filtrar cualquier otra entrada fantasma duplicada que coincida con oldId, externalId o el mismo nombre e idioma
                const targetIdx = idx >= 0 ? idx : catalogo.length - 1;
                catalogo = catalogo.filter((c, i) => {
                  if (i === targetIdx) return true;
                  if (oldId && (c.id === oldId || c.external_id === oldId)) return false;
                  if (externalId && (c.id === externalId || c.external_id === externalId)) return false;
                  if (norm(c.nombre) === cantoNormName && (c.idioma || 'es') === locale) return false;
                  return true;
                });

                // Copiar los archivos nuevos al PWA y al proyecto Flutter/iOS.
                // Se conserva la misma clave global/... que guarda el catálogo,
                // por lo que también funciona con el resolver offline existente.
                const pdfLocal = writeOfflineAsset(pwaAssetsDir, 'pdf', canto.archivo, archivoData);
                const midiLocal = writeOfflineAsset(pwaAssetsDir, 'midi', canto.midi_archivo, midiData);

                if (pdfLocal || midiLocal) {
                  console.log(`[sync-assets] PWA actualizado: PDF=${pdfLocal}, MIDI=${midiLocal}`);
                }

                catalogo.sort((a, b) =>
                  (a.nombre || '').toLowerCase().localeCompare((b.nombre || '').toLowerCase(), 'es', { sensitivity: 'base', numeric: true, ignorePunctuation: true })
                );

                fs.writeFileSync(catPath, JSON.stringify(catalogo, null, 2));
                console.log(`[sync-catalog] ${catFile} actualizado: "${canto.nombre}" (${canto.id})`);

                // Sync a iOS
                const iosDir = iosAssetsDir;
                if (fs.existsSync(iosDir)) {
                  fs.writeFileSync(join(iosDir, catFile), JSON.stringify(catalogo, null, 2));
                  const iosOffline = join(iosDir, 'offline_assets');
                  if (fs.existsSync(iosOffline)) {
                    fs.writeFileSync(join(iosOffline, catFile), JSON.stringify(catalogo, null, 2));
                  }
                  const pdfIos = writeOfflineAsset(iosDir, 'pdf', canto.archivo, archivoData);
                  const midiIos = writeOfflineAsset(iosDir, 'midi', canto.midi_archivo, midiData);
                  if (pdfIos || midiIos) {
                    console.log(`[sync-assets] iOS actualizado: PDF=${pdfIos}, MIDI=${midiIos}`);
                  }
                  console.log(`[sync-catalog] Sincronizado con iOS: ${catFile}`);
                }

                // repertorio_bc consume Supabase en línea, pero conserva estos
                // JSON como catálogo fuente/offline. Se actualiza en cada
                // guardado y se reemplazan IDs legacy por el UUID global.
                if (writeMergedCatalog(repertorioBcAssetsDir, catFile, catalogo)) {
                  console.log(`[sync-catalog] Sincronizado con repertorio_bc: ${catFile}`);
                }

                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true, id: canto.id }));
              } else {
                res.writeHead(400); res.end('Missing canto or unknown action');
              }
            } catch (err) {
              console.error('Error en gestor-sync-catalog:', err);
              res.writeHead(500, { 'Content-Type': 'application/json' });
              res.end(JSON.stringify({ error: err.message }));
            }
          });
          return;
        }

        next();
      });
    }
  };
}

export default defineConfig({
  resolve: {
    alias: {
      events: 'events',
    }
  },
  plugins: [
    legacy({
      targets: ['ios >= 12.1', 'safari >= 12.1'],
      renderLegacyChunks: true,
      additionalLegacyPolyfills: ['regenerator-runtime/runtime']
    }),
    extractInlineScriptsPlugin(),
    gestorLocalCmsPlugin(),
  ],
  test: {
    globals: true,
    environment: 'jsdom',
    include: ['tests/unit/**/*.{test,spec}.{js,ts}', 'src/**/*.{test,spec}.{js,ts}'],
  },
  esbuild: {
    drop: ['console', 'debugger'],
  },
  build: {
    chunkSizeWarningLimit: 1200,
    assetsInlineLimit: 0,
    rollupOptions: {
      onwarn(warning, warn) {
        if (warning.code === 'MODULE_LEVEL_DIRECTIVE' && warning.message.includes('use client')) {
          return;
        }
        warn(warning);
      },
      input: {
        publico: resolve(__dirname, 'index.html'),
        gestor: resolve(__dirname, 'gestor.html'),
      },
      output: {
        manualChunks(id) {
          if (id.includes('pdf.min.mjs') || id.includes('pdf.worker')) {
            return 'vendor-pdf';
          }
          if (id.includes('core-js') || id.includes('regenerator')) {
            return 'vendor-legacy';
          }
          if (id.includes('node_modules')) {
            return 'vendor-libs';
          }
        }
      }
    },
  },
});
