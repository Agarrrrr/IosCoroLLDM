const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.static(path.join(__dirname, 'public'))); // Serve the frontend

// Rutas a los catálogos oficiales de la PWA
const BASE_DIR = path.join(__dirname, '..', '..');
const CATALOGO_ES_PATH = path.join(BASE_DIR, 'public', 'offline_assets', 'catalogo.json');
const CATALOGO_EN_PATH = path.join(BASE_DIR, 'public', 'offline_assets', 'catalogo_en.json');
const PDFS_DIR = path.join(BASE_DIR, 'public', 'offline_assets', 'pdfs');
const MIDIS_DIR = path.join(BASE_DIR, 'public', 'offline_assets', 'midis');

// Servir los assets (pdfs) para poder previsualizarlos
app.use('/assets', express.static(path.join(BASE_DIR, 'public', 'offline_assets')));

const multer = require('multer');

const storage = multer.diskStorage({
    destination: function (req, file, cb) {
        cb(null, PDFS_DIR);
    },
    filename: function (req, file, cb) {
        cb(null, req.body.fileName || file.originalname);
    }
});
const upload = multer({ storage: storage });

app.post('/api/upload-pdf', upload.single('pdf'), (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No se subió ningún archivo' });
        }
        res.json({ success: true, fileName: req.file.filename });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// API: Obtener catálogos
app.get('/api/catalogo', (req, res) => {
    try {
        const es = JSON.parse(fs.readFileSync(CATALOGO_ES_PATH, 'utf8'));
        const en = JSON.parse(fs.readFileSync(CATALOGO_EN_PATH, 'utf8'));
        
        // Agregar campo virtual para saber de qué idioma viene
        const esM = es.map(item => ({ ...item, _lang: 'es' }));
        const enM = en.map(item => ({ ...item, _lang: 'en' }));
        
        res.json([...esM, ...enM]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// API: Obtener lista de MIDIs
app.get('/api/midis', (req, res) => {
    try {
        if (!fs.existsSync(MIDIS_DIR)) {
            return res.json([]);
        }
        const midis = fs.readdirSync(MIDIS_DIR).filter(f => f.toLowerCase().endsWith('.mid') || f.toLowerCase().endsWith('.midi'));
        res.json(['(Ninguno)', ...midis]);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// API: Borrar un canto específico (elimina del JSON y borra el PDF físico)
app.delete('/api/canto/:id', (req, res) => {
    try {
        const id = req.params.id;
        const { fileName } = req.body;
        
        let es = JSON.parse(fs.readFileSync(CATALOGO_ES_PATH, 'utf8'));
        let en = JSON.parse(fs.readFileSync(CATALOGO_EN_PATH, 'utf8'));
        
        es = es.filter(c => c.id !== id);
        en = en.filter(c => c.id !== id);
        
        fs.writeFileSync(CATALOGO_ES_PATH, JSON.stringify(es, null, 4));
        fs.writeFileSync(CATALOGO_EN_PATH, JSON.stringify(en, null, 4));
        
        // Intentar borrar el PDF
        if (fileName) {
            const pdfPath = path.join(PDFS_DIR, fileName);
            if (fs.existsSync(pdfPath)) {
                fs.unlinkSync(pdfPath);
            }
        }
        
        res.json({ success: true });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: err.message });
    }
});

// API: Guardar cambios masivos
app.post('/api/catalogo/bulk', (req, res) => {
    try {
        const { items } = req.body; // Array con todos los cantos mezclados
        
        // Separarlos por idioma
        const newEs = items.filter(i => i._lang === 'es').map(i => {
            const { _lang, ...rest } = i;
            return rest;
        });
        
        const newEn = items.filter(i => i._lang === 'en').map(i => {
            const { _lang, ...rest } = i;
            return rest;
        });
        
        // Escribir a disco
        fs.writeFileSync(CATALOGO_ES_PATH, JSON.stringify(newEs, null, 4));
        fs.writeFileSync(CATALOGO_EN_PATH, JSON.stringify(newEn, null, 4));
        
        res.json({ success: true, message: 'Catálogos actualizados correctamente.' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ error: err.message });
    }
});

app.listen(PORT, () => {
    console.log(`🚀 Bulk Manager Server running at http://localhost:${PORT}`);
    console.log(`Accede a esa URL en tu navegador para editar masivamente.`);
});
