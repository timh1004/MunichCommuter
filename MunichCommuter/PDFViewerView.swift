import SwiftUI
import PDFKit

// MARK: - PDFKit Platform Representable

#if canImport(UIKit)
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = document
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
    }
}
#elseif canImport(AppKit)
struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.document = document
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== document {
            pdfView.document = document
        }
    }
}
#endif

// MARK: - PDF Viewer View

struct PDFViewerView: View {
    let title: String
    let url: URL
    
    @StateObject private var cacheManager = PDFCacheManager()
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        Group {
            if cacheManager.isLoading || (cacheManager.pdfDocument == nil && cacheManager.errorMessage == nil) {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("PDF wird geladen…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = cacheManager.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    
                    Text("Fehler beim Laden")
                        .font(.headline)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    HStack(spacing: 16) {
                        Button {
                            cacheManager.loadPDF(from: url)
                        } label: {
                            Label("Erneut versuchen", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button {
                            openURL(url)
                        } label: {
                            Label("In Safari öffnen", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let document = cacheManager.pdfDocument {
                PDFKitView(document: document)
                    #if canImport(UIKit)
                    .ignoresSafeArea(edges: .bottom)
                    #endif
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    #if canImport(UIKit) && !os(visionOS)
                    if cacheManager.pdfDocument != nil {
                        Button {
                            sharePDF()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    #endif
                    
                    Button {
                        openURL(url)
                    } label: {
                        Image(systemName: "safari")
                    }
                }
            }
        }
        .onAppear {
            print("[PDFViewerView] Lade PDF: \(url.absoluteString)")
            cacheManager.loadPDF(from: url)
        }
    }
    
    #if canImport(UIKit) && !os(visionOS)
    private func sharePDF() {
        guard let document = cacheManager.pdfDocument,
              let data = document.dataRepresentation() else { return }
        
        let tempDir = FileManager.default.temporaryDirectory
        let filename = title.replacingOccurrences(of: " ", with: "_") + ".pdf"
        let tempURL = tempDir.appendingPathComponent(filename)
        
        guard let _ = try? data.write(to: tempURL) else { return }
        
        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        
        var presenter = rootVC
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: 0, width: 0, height: 0)
        }
        
        presenter.present(activityVC, animated: true)
    }
    #endif
}

// MARK: - PDF Cache Manager

class PDFCacheManager: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pdfDocument: PDFDocument?
    
    private let fileManager = FileManager.default
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60
    
    private var cacheDirectory: URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("PDFCache", isDirectory: true)
    }
    
    init() {
        ensureCacheDirectoryExists()
    }
    
    private func ensureCacheDirectoryExists() {
        guard let dir = cacheDirectory else { return }
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
    
    private func cacheFileURL(for remoteURL: URL) -> URL? {
        let filename = remoteURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? UUID().uuidString
        return cacheDirectory?.appendingPathComponent(filename + ".pdf")
    }
    
    private func isCacheValid(at fileURL: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return false
        }
        return Date().timeIntervalSince(modificationDate) < maxCacheAge
    }
    
    func loadPDF(from url: URL) {
        print("[PDFCacheManager] loadPDF URL: \(url.absoluteString)")
        isLoading = true
        errorMessage = nil
        pdfDocument = nil
        
        if let cachedFileURL = cacheFileURL(for: url),
           fileManager.fileExists(atPath: cachedFileURL.path),
           isCacheValid(at: cachedFileURL),
           let document = PDFDocument(url: cachedFileURL) {
            print("[PDFCacheManager] PDF aus Cache geladen: \(url.absoluteString)")
            DispatchQueue.main.async {
                self.pdfDocument = document
                self.isLoading = false
            }
            return
        }
        
        print("[PDFCacheManager] PDF wird aus dem Netz geladen: \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("[PDFCacheManager] Download-Fehler für \(url.absoluteString): \(error.localizedDescription)")
                    self.errorMessage = "Download fehlgeschlagen: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    print("[PDFCacheManager] Keine Daten für \(url.absoluteString) (Leere: \(data?.isEmpty ?? true))")
                    self.errorMessage = "Keine Daten empfangen"
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    print("[PDFCacheManager] HTTP \(httpResponse.statusCode) für \(url.absoluteString)")
                    self.errorMessage = "Server-Fehler (HTTP \(httpResponse.statusCode))"
                    return
                }
                
                guard let document = PDFDocument(data: data) else {
                    print("[PDFCacheManager] PDF-Daten konnten nicht gelesen werden: \(url.absoluteString)")
                    self.errorMessage = "PDF konnte nicht gelesen werden"
                    return
                }
                
                print("[PDFCacheManager] PDF erfolgreich geladen: \(url.absoluteString)")
                self.pdfDocument = document
                
                if let cachedFileURL = self.cacheFileURL(for: url) {
                    try? data.write(to: cachedFileURL, options: .atomic)
                }
            }
        }.resume()
    }
    
    static func clearCache() {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("PDFCache", isDirectory: true) else { return }
        try? fm.removeItem(at: dir)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    
    static func cacheSize() -> String {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("PDFCache", isDirectory: true) else { return "0 KB" }
        var totalSize: Int64 = 0
        if let enumerator = fm.enumerator(at: dir, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

#Preview {
    NavigationView {
        PDFViewerView(
            title: "Schnellbahnnetz",
            url: URL(string: "https://www.mvg.de/dam/mvg/plaene/netz-und-tarifplaene/netz-tarifplan.pdf")!
        )
    }
}
