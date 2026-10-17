import SwiftUI
import AVFoundation
import VisionKit

struct PairingScanner: View {
    var onPayload: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var allowed = false
    @State private var checked = false
    var body: some View {
        NavigationStack {
            Group {
                if allowed && DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    QRScanner { value in onPayload(value); dismiss() }
                } else if checked {
                    ContentUnavailableView("Caméra indisponible", systemImage: "camera", description: Text("Autorise la caméra dans Réglages, ou importe le fichier d’appairage du Mac. Le simulateur utilise l’import ou le collage du contenu."))
                } else { ProgressView() }
            }
            .navigationTitle("Relier le Mac")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } } }
        }
        .task {
            allowed = await AVCaptureDevice.requestAccess(for: .video)
            checked = true
        }
    }
}
private struct QRScanner: UIViewControllerRepresentable {
    var onPayload: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onPayload: onPayload) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced, recognizesMultipleItems: false, isGuidanceEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}
    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) { uiViewController.stopScanning() }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onPayload: (String) -> Void
        var consumed = false
        init(onPayload: @escaping (String) -> Void) { self.onPayload = onPayload }
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !consumed else { return }
            for item in addedItems {
                if case .barcode(let code) = item, let payload = code.payloadStringValue {
                    consumed = true; dataScanner.stopScanning(); onPayload(payload); return
                }
            }
        }
    }
}
