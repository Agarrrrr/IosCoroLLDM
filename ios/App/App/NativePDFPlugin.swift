import Foundation
import UIKit
import WebKit
import Capacitor
import PDFKit

// MARK: - Custom PDF Kit Document & Page for Theme Inversion
class CustomPDFDocument: PDFDocument {
    var theme: String = "claro"
}

// Ponytail: Se eliminó la caché de bitmaps (CGImage).
// Dibuja 100% vectorial usando blendModes directo al CGContext nativo de PDFKit.
// Cero lag de zoom, nitidez infinita y sin destellos blancos.
class CustomPDFPage: PDFPage {
    override func draw(with box: PDFDisplayBox, to context: CGContext) {
        guard let customDoc = self.document as? CustomPDFDocument else {
            super.draw(with: box, to: context)
            return
        }
        
        let theme = customDoc.theme
        let pageBounds = bounds(for: box)
        
        // Temas claros: sin filtros, dibujo directo
        if theme == "claro" || theme == "rosa" || theme == "azul" || theme == "jade" {
            super.draw(with: box, to: context)
            return
        }
        
        context.saveGState()
        
        // 1. Dibuja el PDF vectorial subyacente
        super.draw(with: box, to: context)
        
        // 2. Aplica máscaras de color (blend modes) directamente sobre los vectores
        switch theme {
        case "oscuro":
            context.setBlendMode(.difference)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(pageBounds)
            context.setBlendMode(.multiply)
            context.setFillColor(UIColor(red: 241/255.0, green: 245/255.0, blue: 249/255.0, alpha: 1.0).cgColor)
            context.fill(pageBounds)
            context.setBlendMode(.screen)
            context.setFillColor(UIColor(red: 27/255.0, green: 36/255.0, blue: 48/255.0, alpha: 1.0).cgColor)
            context.fill(pageBounds)
            
        case "oled":
            context.setBlendMode(.difference)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(pageBounds)
            context.setBlendMode(.multiply)
            context.setFillColor(UIColor(red: 226/255.0, green: 232/255.0, blue: 240/255.0, alpha: 1.0).cgColor)
            context.fill(pageBounds)
            
        case "contraste":
            context.setBlendMode(.difference)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(pageBounds)
            context.setBlendMode(.multiply)
            context.setFillColor(UIColor.yellow.cgColor)
            context.fill(pageBounds)
            
        case "quiet":
            context.setBlendMode(.difference)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(pageBounds)
            context.setBlendMode(.screen)
            context.setFillColor(UIColor(red: 60/255.0, green: 63/255.0, blue: 66/255.0, alpha: 1.0).cgColor)
            context.fill(pageBounds)
            
        case "sepia":
            context.setBlendMode(.multiply)
            context.setFillColor(UIColor(red: 253/255.0, green: 245/255.0, blue: 230/255.0, alpha: 1.0).cgColor)
            context.fill(pageBounds)
            
        default:
            break
        }
        
        context.restoreGState()
    }
}

class TouchPassPDFView: PDFView {
    weak var plugin: NativePDFPlugin?
    var barsVisible: Bool = true
    private var lastBounds: CGRect = .zero
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }
    
    private func setupGestures() {
        // Edge Pan Gesture for Back Navigation
        let edgeGesture = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        edgeGesture.edges = .left
        edgeGesture.delegate = self
        self.addGestureRecognizer(edgeGesture)
    }
    
    @objc private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .recognized {
            plugin?.notifyBackGesture()
        }
    }
    
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Registrar gestures en documentView y scrollview interno
        if let docView = self.documentView {
            if !docView.gestureRecognizers!.contains(where: { $0 is UIScreenEdgePanGestureRecognizer && $0.delegate === self }) {
                let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
                edge.edges = .left
                edge.delegate = self
                docView.addGestureRecognizer(edge)
            }
        }
        
        if let scrollView = self.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            if !scrollView.gestureRecognizers!.contains(where: { $0 is UIScreenEdgePanGestureRecognizer && $0.delegate === self }) {
                let edge = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
                edge.edges = .left
                edge.delegate = self
                scrollView.addGestureRecognizer(edge)
            }
        }
        
        // Auto-escala al ancho
        if self.bounds != lastBounds {
            lastBounds = self.bounds
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.minScaleFactor = self.scaleFactorForSizeToFit
                self.scaleFactor = self.scaleFactorForSizeToFit
            }
        }
    }
}



class TouchForwardView: UIView, UIGestureRecognizerDelegate {
    weak var targetView: TouchPassPDFView?
    weak var plugin: NativePDFPlugin?
    var barsVisible: Bool = true
    var interactiveRects: [CGRect] = []
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if view === self {
            if !barsVisible {
                return nil
            }
            
            // 1. Evaluar rectángulos dinámicos registrados desde JS (menús, reproductor, modales, herramientas)
            for rect in interactiveRects {
                if rect.contains(point) {
                    return nil
                }
            }
            
            // 2. Fallback a límites de barra superior (con safeAreaTop) e inferior
            let safeTop = self.safeAreaInsets.top
            let rawTop = self.plugin?.topbarHeight ?? 64.0
            let topLimit = rawTop + safeTop
            
            let bottomInset = self.plugin?.bottomInset ?? 0.0
            let bottomLimit = self.bounds.height - bottomInset
            
            // Si el toque cae en la barra superior o en el reproductor desplegado (bottomInset > 0), dejarlo pasar a la webView
            if point.y < topLimit || (bottomInset > 0 && point.y > bottomLimit) {
                return nil
            }
            
            // De lo contrario (centro de la partitura), reenviar al PDFView nativo para permitir el scroll y navegación de la partitura
            if let target = targetView {
                let convertedPoint = self.convert(point, to: target)
                return target.hitTest(convertedPoint, with: event)
            }
        }
        return view
    }
}

@_silgen_name("configurePlaybackAudioSession")
func configurePlaybackAudioSession()

@objc(NativePDFPlugin)
public class NativePDFPlugin: CAPPlugin, PDFDocumentDelegate {
    
    // MARK: - State
    private var pdfView: TouchPassPDFView?
    private var touchForwardView: TouchForwardView?
    private var currentPageObserver: Any?
    private var scrollObserver: NSKeyValueObservation?
    private var barsVisible: Bool = true
    var topbarHeight: CGFloat = 64.0
    var bottomInset: CGFloat = 0.0
    
    private var pdfTopConstraint: NSLayoutConstraint?
    
    // MARK: - Helper to resolve theme background color
    private func getBackgroundColorForTheme(_ theme: String) -> UIColor {
        switch theme {
        case "oscuro":
            return UIColor(red: 17/255.0, green: 22/255.0, blue: 28/255.0, alpha: 1.0) // #11161c
        case "oled", "contraste":
            return UIColor.black // #000000
        case "quiet":
            return UIColor(red: 60/255.0, green: 63/255.0, blue: 66/255.0, alpha: 1.0) // #3c3f42
        case "sepia":
            return UIColor(red: 244/255.0, green: 236/255.0, blue: 216/255.0, alpha: 1.0) // #f4ecd8
        case "rosa":
            return UIColor.white // #ffffff
        case "azul":
            return UIColor(red: 244/255.0, green: 248/255.0, blue: 255/255.0, alpha: 1.0) // #f4f8ff
        case "jade":
            return UIColor(red: 245/255.0, green: 252/255.0, blue: 248/255.0, alpha: 1.0) // #f5fcf8
        default:
            return UIColor.white // Blanco puro para que empate con el fondo del PDF real
        }
    }
    
    // MARK: - openPdf
    @objc public func openPdf(_ call: CAPPluginCall) {
        guard let path = call.options["path"] as? String else {
            call.resolve(["error": "Must provide path"])
            return
        }
        let startPage = call.options["startPage"] as? Int ?? 0
        let theme = call.options["theme"] as? String ?? "claro"
        let modoPaginas = call.options["modoPaginas"] as? Bool ?? false
        
        var pdfURL: URL?
        if path.hasPrefix("file://") {
            let cleanPath = path.replacingOccurrences(of: "file://", with: "").removingPercentEncoding ?? path.replacingOccurrences(of: "file://", with: "")
            pdfURL = URL(fileURLWithPath: cleanPath)
        } else {
            if let bp = Bundle.main.path(forResource: path, ofType: nil) {
                pdfURL = URL(fileURLWithPath: bp)
            } else if let bp = Bundle.main.path(forResource: "public/\(path)", ofType: nil) {
                pdfURL = URL(fileURLWithPath: bp)
            }
        }
        
        // DIAGNÓSTICO: verificar el archivo en disco antes de abrir
        var diagMessages: [String] = []
        if let url = pdfURL, let attrs = try? FileManager.default.attributesOfItem(atPath: url.path), let size = attrs[.size] as? Int {
            let msg = "disco: \(size)b en \(url.lastPathComponent)"
            print("[NativePdf][DIAG] \(msg)")
            diagMessages.append(msg)
            if let data = try? Data(contentsOf: url), data.count >= 5 {
                let header = String(data: data.prefix(5), encoding: .ascii) ?? "?"
                let msg2 = "hdr=\"\(header)\""
                print("[NativePdf][DIAG] \(msg2)")
                diagMessages.append(msg2)
                if header != "%PDF-" {
                    let err = "Disco corrupto (hdr=\(header))"
                    print("[NativePdf][DIAG] ¡\(err)!")
                    call.resolve(["error": err, "diag": diagMessages])
                    return
                }
            }
        }

        guard let url = pdfURL, let document = CustomPDFDocument(url: url) else {
            call.resolve(["error": "PDF no encontrado en: \(path)", "diag": diagMessages])
            return
        }
        let pcMsg = "pageCount=\(document.pageCount)"
        print("[NativePdf][DIAG] \(pcMsg)")
        diagMessages.append(pcMsg)
        if document.pageCount == 0 {
            print("[NativePdf][DIAG] ¡PDFDocument tiene 0 páginas!")
            call.resolve(["error": "PDFDocument vacío (0 páginas)", "diag": diagMessages])
            return
        }
        document.theme = theme
        document.delegate = self
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let themeBgColor = self.getBackgroundColorForTheme(theme)
            self.barsVisible = true
            
            if self.pdfView == nil {
                let pv = TouchPassPDFView()
                pv.plugin = self
                pv.autoScales = true
                if modoPaginas {
                    pv.displayMode = .singlePage
                    pv.displayDirection = .horizontal
                    pv.usePageViewController(true)
                } else {
                    pv.displayMode = .singlePageContinuous
                    pv.displayDirection = .vertical
                    pv.usePageViewController(false)
                }
                pv.backgroundColor = themeBgColor
                pv.barsVisible = true
                pv.pageShadowsEnabled = false
                pv.maxScaleFactor = 4.0
                pv.minScaleFactor = pv.scaleFactorForSizeToFit
                
                if let webView = self.webView, let superview = webView.superview {
                    superview.backgroundColor = themeBgColor
                    if let window = superview.window {
                        window.backgroundColor = themeBgColor
                    }
                    
                    // Insertar PDFView DEBAJO de webView para que el dashboard (HTML) lo cubra y se deslice revelándolo
                    superview.insertSubview(pv, belowSubview: webView)
                    pv.translatesAutoresizingMaskIntoConstraints = false
                    
                    self.pdfTopConstraint = pv.topAnchor.constraint(equalTo: superview.topAnchor)
                    
                    NSLayoutConstraint.activate([
                        self.pdfTopConstraint!,
                        pv.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
                        pv.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                        pv.trailingAnchor.constraint(equalTo: superview.trailingAnchor)
                    ])
                    
                    // Crear e insertar TouchForwardView ARRIBA de webView
                    let tf = TouchForwardView()
                    tf.targetView = pv
                    tf.plugin = self
                    tf.barsVisible = true
                    superview.addSubview(tf)
                    tf.translatesAutoresizingMaskIntoConstraints = false
                    
                    NSLayoutConstraint.activate([
                        tf.topAnchor.constraint(equalTo: superview.topAnchor),
                        tf.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
                        tf.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                        tf.trailingAnchor.constraint(equalTo: superview.trailingAnchor)
                    ])
                    
                    self.touchForwardView = tf
                }
                
                self.webView?.isOpaque = false
                self.webView?.backgroundColor = UIColor.clear
                self.webView?.scrollView.backgroundColor = UIColor.clear
                
                self.pdfView = pv
                
                self.currentPageObserver = NotificationCenter.default.addObserver(
                    forName: .PDFViewPageChanged, object: pv, queue: .main
                ) { [weak self] _ in
                    guard let pv = self?.pdfView,
                          let currentPage = pv.currentPage,
                          let index = pv.document?.index(for: currentPage) else { return }
                    self?.notifyListeners("pageChanged", data: ["page": index])
                }
                
                NotificationCenter.default.addObserver(
                    forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
                ) { [weak self] _ in
                    self?.pdfView?.layoutDocumentView()
                    if let pv = self?.pdfView {
                        pv.minScaleFactor = pv.scaleFactorForSizeToFit
                        pv.scaleFactor = pv.scaleFactorForSizeToFit
                    }
                }
            } else {
                self.pdfView?.backgroundColor = themeBgColor
                if modoPaginas {
                    self.pdfView?.displayMode = .singlePage
                    self.pdfView?.usePageViewController(true)
                } else {
                    self.pdfView?.displayMode = .singlePageContinuous
                    self.pdfView?.displayDirection = .vertical
                    self.pdfView?.usePageViewController(false)
                }
            }
            
            // Ponytail: Solo un fade in ya que el slide lo hace el dashboard
            self.pdfView?.alpha = 0
            self.pdfView?.transform = .identity
            
            self.pdfView?.document = document
            if let targetPage = document.page(at: startPage) {
                self.pdfView?.go(to: targetPage)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let pv = self.pdfView {
                    pv.minScaleFactor = pv.scaleFactorForSizeToFit
                    pv.scaleFactor = pv.scaleFactorForSizeToFit
                    UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut]) {
                        pv.alpha = 1
                    }
                }
            }
            call.resolve()
        }
    }
    
    // MARK: - updateDisplayMode
    @objc public func updateDisplayMode(_ call: CAPPluginCall) {
        let modoPaginas = call.options["modoPaginas"] as? Bool ?? false
        DispatchQueue.main.async { [weak self] in
            if let pv = self?.pdfView {
                if modoPaginas {
                    pv.displayMode = .singlePage
                    pv.displayDirection = .horizontal
                    pv.usePageViewController(true)
                } else {
                    pv.displayMode = .singlePageContinuous
                    pv.displayDirection = .vertical
                    pv.usePageViewController(false)
                }
                self?.applyPadding(modoPaginas: modoPaginas)
            }
            call.resolve()
        }
    }
    
    // MARK: - setBottomInset
    @objc public func setBottomInset(_ call: CAPPluginCall) {
        let insetVal = (call.options["inset"] as? Double) ?? Double(call.options["inset"] as? Int ?? 0)
        let inset = CGFloat(insetVal)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.bottomInset = inset
            call.resolve()
        }
    }
    
    // MARK: - setInteractiveRects
    @objc public func setInteractiveRects(_ call: CAPPluginCall) {
        let rectsData = (call.options["rects"] as? [[String: Any]]) ?? (call.getArray("rects", JSArray()) as? [[String: Any]]) ?? []
        print("🔴 [NativePdf] setInteractiveRects llamado con raw options: \(String(describing: call.options))")
        
        var newRects: [CGRect] = []
        for dict in rectsData {
            let xVal = (dict["x"] as? Double) ?? Double(dict["x"] as? Int ?? 0)
            let yVal = (dict["y"] as? Double) ?? Double(dict["y"] as? Int ?? 0)
            let wVal = (dict["width"] as? Double) ?? Double(dict["width"] as? Int ?? 0)
            let hVal = (dict["height"] as? Double) ?? Double(dict["height"] as? Int ?? 0)
            
            if wVal > 0 && hVal > 0 {
                newRects.append(CGRect(x: CGFloat(xVal), y: CGFloat(yVal), width: CGFloat(wVal), height: CGFloat(hVal)))
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            print("🔴 [NativePdf] Rects parseados exitosamente (\(newRects.count)): \(newRects)")
            self?.touchForwardView?.interactiveRects = newRects
            call.resolve()
        }
    }
    
    // MARK: - closePdf
    @objc public func closePdf(_ call: CAPPluginCall) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let pv = self.pdfView else {
                call.resolve()
                return
            }
            self.touchForwardView?.interactiveRects = []
            self.touchForwardView?.removeFromSuperview()
            self.touchForwardView = nil
            self.pdfView = nil // Evita reentrancia infinita si JS llama dos veces
            
            if let obs = self.currentPageObserver {
                NotificationCenter.default.removeObserver(obs)
                self.currentPageObserver = nil
            }
            if let obs = self.scrollObserver {
                obs.invalidate()
                self.scrollObserver = nil
            }
            
            UIView.animate(withDuration: 0.35, animations: {
                // Solo un ligero fade out mientras el dashboard lo cubre
                pv.alpha = 0
            }) { _ in
                pv.removeFromSuperview()
                if let webView = self.webView, let superview = webView.superview {
                    superview.backgroundColor = .clear
                    
                    superview.bringSubviewToFront(webView)
                }
                
                self.webView?.isOpaque = true
                self.webView?.backgroundColor = UIColor.white
                self.webView?.scrollView.backgroundColor = UIColor.white
                
                self.notifyListeners("pdfClosed", data: [:])
                call.resolve()
            }
        }
    }
    
    // MARK: - jumpToPage
    @objc public func jumpToPage(_ call: CAPPluginCall) {
        guard let pageIndex = call.options["page"] as? Int else {
            call.resolve(["error": "Must provide page index"])
            return
        }
        DispatchQueue.main.async { [weak self] in
            if let doc = self?.pdfView?.document, let page = doc.page(at: pageIndex) {
                self?.pdfView?.go(to: page)
            }
            call.resolve()
        }
    }
    
    // MARK: - setTheme
    @objc public func setTheme(_ call: CAPPluginCall) {
        guard let theme = call.options["theme"] as? String else {
            call.resolve(["error": "Must provide theme"])
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let doc = self.pdfView?.document as? CustomPDFDocument {
                doc.theme = theme
                let themeBgColor = self.getBackgroundColorForTheme(theme)
                self.pdfView?.backgroundColor = themeBgColor
                self.pdfView?.pageShadowsEnabled = false
                
                if let webView = self.webView, let superview = webView.superview {
                    superview.backgroundColor = themeBgColor
                }
                
                // Ya no hay caché que invalidar
                
                let currentPage = self.pdfView?.currentPage
                self.pdfView?.document = nil
                self.pdfView?.document = doc
                if let page = currentPage {
                    self.pdfView?.go(to: page)
                }
                self.pdfView?.minScaleFactor = self.pdfView?.scaleFactorForSizeToFit ?? 0.5
                self.pdfView?.scaleFactor = self.pdfView?.scaleFactorForSizeToFit ?? 1.0
                self.pdfView?.layoutDocumentView()
            }
            call.resolve()
        }
    }
    
    // MARK: - setTopbarInset
    @objc public func setTopbarInset(_ call: CAPPluginCall) {
        let heightVal = (call.options["height"] as? Double) ?? Double(call.options["height"] as? Int ?? 0)
        let insetVal = (call.options["inset"] as? Double) ?? Double(call.options["inset"] as? Int ?? 0)
        let height = CGFloat(max(heightVal, insetVal, 64.0))
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.topbarHeight = height
            
            let modoPaginas = self.pdfView?.displayMode == .singlePage
            self.applyPadding(modoPaginas: modoPaginas)
            call.resolve()
        }
    }
    
    @objc public func setBarsVisible(_ call: CAPPluginCall) {
        guard let active = call.options["active"] as? Bool else {
            call.resolve()
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.barsVisible = active
            self.touchForwardView?.barsVisible = active
            call.resolve()
        }
    }
    
    @objc public func setDrawingMode(_ call: CAPPluginCall) {
        guard let active = call.options["active"] as? Bool else {
            call.resolve()
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.touchForwardView?.isUserInteractionEnabled = !active
            call.resolve()
        }
    }
    
    // MARK: - notifyTap helper
    func notifyTap() {
        // Deshabilitado, el topbar siempre es visible
    }
    
    // MARK: - notifyBackGesture helper
    func notifyBackGesture() {
        self.notifyListeners("pdfClosed", data: [:])
    }
    
    // MARK: - PDFDocumentDelegate
    public func classForPage() -> AnyClass {
        return CustomPDFPage.self
    }
    
    // MARK: - Layout Helper
    private func applyPadding(modoPaginas: Bool) {
        guard let pv = self.pdfView else { return }
        let offset = self.topbarHeight // topbarHeight (del DOM) ya incluye safe-area-inset-top
        
        UIView.animate(withDuration: 0.25) {
            if modoPaginas {
                self.pdfTopConstraint?.constant = offset
                if let scrollView = pv.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
                    scrollView.contentInset = .zero
                    scrollView.scrollIndicatorInsets = .zero
                }
            } else {
                self.pdfTopConstraint?.constant = 0
                if let scrollView = pv.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
                    scrollView.contentInset = UIEdgeInsets(top: offset, left: 0, bottom: 0, right: 0)
                    scrollView.scrollIndicatorInsets = UIEdgeInsets(top: offset, left: 0, bottom: 0, right: 0)
                }
            }
            pv.superview?.layoutIfNeeded()
        }
        
        if !modoPaginas {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let scrollView = pv.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
                    scrollView.setContentOffset(CGPoint(x: 0, y: -offset), animated: false)
                }
            }
        }
    }
}
