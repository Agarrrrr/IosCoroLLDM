import UIKit
import Capacitor
import PDFKit

class ViewController: CAPBridgeViewController {
    @MainActor
    override open func capacitorDidLoad() {
        bridge?.registerPluginType(NativePDFPlugin.self)
    }
}
