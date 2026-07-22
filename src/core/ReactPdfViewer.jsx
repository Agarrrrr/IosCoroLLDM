import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Document, Page, pdfjs } from 'react-pdf';
import 'react-pdf/dist/Page/AnnotationLayer.css';
import 'react-pdf/dist/Page/TextLayer.css';
import { anotacionesManager } from './anotacionesManager.js';
import { pdfEngine } from './pdfEngine.js';
import { localDB } from '../api/localDB.js';
import { decryptOffThread } from './decryptor.js';

pdfjs.GlobalWorkerOptions.workerSrc = '/vendor/pdf.worker.legacy.min.js';

// ─── Componente de Página Individual ─────────────────────────────────────────
const PdfPageWithAnnotations = ({ index, cantoId, maxWidth }) => {
    const pageRef = useRef(null);
    const canvasAnotacionesRef = useRef(null);
    const [viewportParams, setViewportParams] = useState(null);
    const [isVisible, setIsVisible] = useState(index === 0);

    // Fix 2a: IntersectionObserver siempre se desconecta en cleanup
    useEffect(() => {
        if (index === 0) return; // La primera siempre carga

        const observer = new IntersectionObserver(
            (entries) => {
                if (entries[0].isIntersecting) {
                    setIsVisible(true);
                    observer.disconnect();
                }
            },
            { rootMargin: '100% 0px' }
        );

        if (pageRef.current) observer.observe(pageRef.current);
        // ✅ Cleanup siempre, incluso si la página nunca se hizo visible
        return () => observer.disconnect();
    }, [index]);

    const onPageRenderSuccess = useCallback((page) => {
        const viewport = page.getViewport({ scale: 1 });
        setViewportParams({ width: viewport.width, height: viewport.height });
    }, []);

    // Fix 2b: Cleanup completo de canvas GPU + visibilitychange + abort controller
    useEffect(() => {
        const drawCanvas = () => {
            if (!viewportParams || !canvasAnotacionesRef.current) return;
            const canvas = canvasAnotacionesRef.current;
            const ctx = canvas.getContext('2d');
            if (!ctx) return;

            const dpr = window.devicePixelRatio || 1;
            canvas.width = viewportParams.width * dpr;
            canvas.height = viewportParams.height * dpr;
            ctx.scale(dpr, dpr);
            ctx.lineCap = 'round';
            ctx.lineJoin = 'round';

            const trazos = anotacionesManager.obtenerTrazosLocal(cantoId, index + 1);
            if (trazos) pdfEngine.dibujarTrazos(ctx, trazos, viewportParams.width, viewportParams.height);

            pdfEngine.bindEventosDibujo(canvas, ctx, index + 1, viewportParams.width, viewportParams.height, cantoId);
        };

        drawCanvas();

        // Hack para WebView Android: forzar redibujado al volver de suspensión
        const handleVisibility = () => {
            if (document.visibilityState === 'visible') {
                setTimeout(drawCanvas, 150);
            }
        };
        document.addEventListener('visibilitychange', handleVisibility);

        return () => {
            // ✅ Fix 2b: Limpiar listener de visibilidad
            document.removeEventListener('visibilitychange', handleVisibility);

            // ✅ Fix 2b: Liberar VRAM del canvas de anotaciones inmediatamente
            // Poner width/height a 0 destruye el buffer interno del canvas en la GPU,
            // liberando la VRAM que estaba bloqueada. Crítico para evitar canvas negros en Android.
            const canvas = canvasAnotacionesRef.current;
            if (canvas) {
                try {
                    const ctx = canvas.getContext('2d');
                    if (ctx) ctx.clearRect(0, 0, canvas.width, canvas.height);
                    canvas.width = 0;
                    canvas.height = 0;
                } catch (e) {}
            }

            // ✅ Fix 2b: Abortar todos los event listeners de dibujo de esta página
            const estadoPag = pdfEngine.anotacionesEstado[index + 1];
            if (estadoPag?.abortController && !estadoPag.abortController.signal.aborted) {
                estadoPag.abortController.abort();
            }
        };
    }, [viewportParams, cantoId, index]);

    return (
        <div ref={pageRef} className="pdf-page-wrapper" style={{ position: 'relative', width: '100%', minHeight: `${maxWidth * 1.3}px` }}>
            {isVisible ? (
                <Page
                    className="pdf-page-canvas"
                    pageNumber={index + 1}
                    width={maxWidth}
                    renderTextLayer={false}
                    renderAnnotationLayer={false}
                    onRenderSuccess={onPageRenderSuccess}
                    onLoadError={(e) => console.error('Error al cargar página:', e)}
                    onRenderError={(e) => console.error('Error al renderizar página:', e)}
                    loading={<div style={{ width: '100%', height: `${maxWidth * 1.3}px`, backgroundColor: 'transparent' }}></div>}
                />
            ) : (
                <div style={{ width: '100%', height: `${maxWidth * 1.3}px`, backgroundColor: 'transparent' }}></div>
            )}
            {isVisible && viewportParams && (
                <canvas
                    ref={canvasAnotacionesRef}
                    className="pdf-page-canvas canvas-anotaciones"
                    data-pagina={index + 1}
                    style={{
                        position: 'absolute',
                        top: 0,
                        left: 0,
                        width: '100%',
                        height: '100%',
                        pointerEvents: pdfEngine.modoDibujo ? 'auto' : 'none',
                        zIndex: 5
                    }}
                />
            )}
        </div>
    );
};

// ─── Componente Principal ─────────────────────────────────────────────────────
export default function ReactPdfViewer({ canto }) {
    const [numPages, setNumPages] = useState(null);
    const [windowWidth, setWindowWidth] = useState(window.innerWidth);
    const [pdfData, setPdfData] = useState(null);
    const [pdfError, setPdfError] = useState(null);

    useEffect(() => {
        const handleResize = () => setWindowWidth(window.innerWidth);
        window.addEventListener('resize', handleResize);
        return () => window.removeEventListener('resize', handleResize);
    }, []);

    const pdfUrl = (canto && canto.archivo && canto.archivo !== 'null')
        ? localDB.resolverUrlPdf(canto.archivo)
        : '';

    // Fix 3b: Usar worker de desencriptado off-thread para no bloquear la UI
    useEffect(() => {
        if (!pdfUrl) {
            setPdfData(null);
            setNumPages(null);
            return;
        }

        let cancelled = false;
        setPdfData(null);
        setPdfError(null);

        decryptOffThread(pdfUrl)
            .then(buffer => {
                if (cancelled) return;
                setPdfData({ data: new Uint8Array(buffer) });
            })
            .catch(err => {
                if (cancelled) return;
                console.error('Error al procesar PDF:', err);
                setPdfError('Error al cargar la partitura. Verifica tu conexión.');
            });

        // Fix 2c: Limpiar pdfData al desmontar o cambiar de partitura para liberar RAM
        return () => {
            cancelled = true;
            setPdfData(null);
            setNumPages(null);
        };
    }, [pdfUrl]);

    // Forzar actualización cuando cambia el modo dibujo
    const [, setForzarUpdate] = useState(0);
    useEffect(() => {
        const handleToggleDibujo = () => setForzarUpdate(prev => prev + 1);
        window.addEventListener('toggle-modo-dibujo', handleToggleDibujo);
        return () => window.removeEventListener('toggle-modo-dibujo', handleToggleDibujo);
    }, []);

    const onDocumentLoadSuccess = useCallback(({ numPages }) => {
        setNumPages(numPages);
    }, []);

    const maxWidth = windowWidth;

    if (!canto) {
        return <div id="zoom-layer" style={{ width: '100%', height: '1px' }}></div>;
    }

    return (
        <div id="zoom-layer" style={{ width: '100%' }}>
            {pdfError && <div className="mensaje-vacio" style={{ marginTop: '20px' }}>{pdfError}</div>}
            {pdfData && (
                <Document
                    file={pdfData}
                    onLoadSuccess={onDocumentLoadSuccess}
                    onLoadError={(error) => {
                        console.error('Error interno de PDF.js:', error);
                        setPdfError('El archivo parece estar dañado o la desencriptación falló.');
                        setPdfData(null);
                    }}
                    loading={
                        <div style={{ width: '100vw', height: '100vh', display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '10px' }}>
                            <div className="skeleton-page" style={{ width: '100%', height: '130vw', backgroundColor: 'var(--color-superficie-secundaria, #e2e8f0)' }}></div>
                        </div>
                    }
                >
                    {Array.from(new Array(numPages), (el, index) => (
                        <PdfPageWithAnnotations
                            key={`page_${index + 1}`}
                            index={index}
                            cantoId={canto.id}
                            maxWidth={windowWidth}
                        />
                    ))}
                </Document>
            )}
        </div>
    );
}
