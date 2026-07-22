import { defineConfig } from 'vite';
import { resolve } from 'path';
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
              
              if (action === 'save') {
                const { canto } = body;
                const locale = canto._idioma || 'es';
                const catalogoFilename = locale === 'es' ? 'catalogo.json' : 'catalogo_en.json';
                const catalogoPath = resolve(__dirname, 'public/offline_assets', catalogoFilename);
                
                const ENCRYPTION_KEY = crypto.createHash('sha256').update('repertorio-coral-lldm-key-2026').digest();
                
                function encryptBuffer(buffer) {
                    const iv = crypto.randomBytes(12);
                    const cipher = crypto.createCipheriv('aes-256-gcm', ENCRYPTION_KEY, iv);
                    const encrypted = Buffer.concat([cipher.update(buffer), cipher.final()]);
                    const authTag = cipher.getAuthTag();
                    return Buffer.concat([iv, encrypted, authTag]);
                }

                if (canto.archivo && canto.archivo.startsWith('data:')) {
                  const base64Data = canto.archivo.split(',')[1];
                  const timestamp = Date.now();
                  const filename = `${canto.nombre.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/-+/g, '-')}-${timestamp}.pdf`;
                  const outPath = resolve(__dirname, 'public/offline_assets/pdfs', filename);
                  const rawBuffer = Buffer.from(base64Data, 'base64');
                  fs.writeFileSync(outPath, encryptBuffer(rawBuffer));
                  canto.archivo = filename;
                }
                
                if (canto.midi_archivo && canto.midi_archivo.startsWith('data:')) {
                  const base64Data = canto.midi_archivo.split(',')[1];
                  const timestamp = Date.now();
                  const filename = `${canto.nombre.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/-+/g, '-')}-${timestamp}.mid`;
                  const outPath = resolve(__dirname, 'public/offline_assets/midis', filename);
                  const rawBuffer = Buffer.from(base64Data, 'base64');
                  fs.writeFileSync(outPath, encryptBuffer(rawBuffer));
                  canto.midi_archivo = filename;
                }
                
                let catalogo = [];
                if (fs.existsSync(catalogoPath)) {
                  catalogo = JSON.parse(fs.readFileSync(catalogoPath, 'utf8'));
                }
                
                const id = canto.id;
                delete canto._idioma;
                delete canto.nuevo_local;
                
                const idx = catalogo.findIndex(c => c.id === id);
                if (idx >= 0) {
                  catalogo[idx] = { ...catalogo[idx], ...canto };
                } else {
                  catalogo.push(canto);
                }
                
                catalogo.sort((a, b) => {
                    const nomA = (a.nombre || '').toLowerCase();
                    const nomB = (b.nombre || '').toLowerCase();
                    return nomA.localeCompare(nomB, 'es', { sensitivity: 'base', numeric: true, ignorePunctuation: true });
                });
                
                fs.writeFileSync(catalogoPath, JSON.stringify(catalogo, null, 2));

                if (canto.vinculo_idioma) {
                  const reverseLocale = locale === 'es' ? 'en' : 'es';
                  const reverseFilename = reverseLocale === 'es' ? 'catalogo.json' : 'catalogo_en.json';
                  const reversePath = resolve(__dirname, 'public/offline_assets', reverseFilename);
                  if (fs.existsSync(reversePath)) {
                    let reverseCatalogo = JSON.parse(fs.readFileSync(reversePath, 'utf8'));
                    let vinculadoIdx = reverseCatalogo.findIndex(x => x.id === canto.vinculo_idioma);
                    if (vinculadoIdx >= 0) {
                      reverseCatalogo[vinculadoIdx].vinculo_idioma = canto.id;
                      if ('midi_archivo' in canto) {
                        reverseCatalogo[vinculadoIdx].midi_archivo = canto.midi_archivo;
                      }
                      fs.writeFileSync(reversePath, JSON.stringify(reverseCatalogo, null, 2));
                    }
                  }
                }
                
                res.writeHead(200, { 'Content-Type': 'application/json' });
                res.end(JSON.stringify({ success: true }));
              } else if (action === 'delete') {
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
    drop: ['debugger'],
    pure: ['console.log', 'console.debug'],
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
