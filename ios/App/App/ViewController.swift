import UIKit
import Capacitor
import PDFKit

class ViewController: CAPBridgeViewController {
    @MainActor
    override open func capacitorDidLoad() {
        bridge?.registerPluginType(NativePDFPlugin.self)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func handleAppDidBecomeActive() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let webView = self.webView else { return }
            webView.frame = self.view.bounds
            webView.setNeedsLayout()
            webView.layoutIfNeeded()
            
            // Disparar evento resize en WebKit para forzar re-cálculo de 100vw y flexbox
            let js = "window.dispatchEvent(new Event('resize')); document.documentElement.style.setProperty('--vh', (window.innerHeight * 0.01) + 'px');"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let webView = self.webView, webView.frame != self.view.bounds {
            webView.frame = self.view.bounds
        }
    }
}
