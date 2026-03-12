import SwiftUI

struct SettingsView: View {
    @ObservedObject var scanner: QRScannerViewModel
    @EnvironmentObject private var libraryStore: QRLibraryStore
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("animationsEnabled") private var animationsEnabled = true
    @AppStorage("autoSaveScans") private var autoSaveScans = true
    @AppStorage("autoCopyScans") private var autoCopyScans = false

    var body: some View {
        NavigationStack {
            List {
                Section("Experience") {
                    Toggle("Haptics", isOn: $hapticsEnabled)
                    Toggle("Animations", isOn: $animationsEnabled)
                }

                Section("Scanner") {
                    Toggle("Auto-save scans", isOn: $autoSaveScans)
                    Toggle("Auto-copy scan result", isOn: $autoCopyScans)
                    HStack {
                        Text("Camera status")
                        Spacer()
                        Text(statusText)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("What makes it strong") {
                    Label("Live camera scanning for QR and common barcodes", systemImage: "camera.viewfinder")
                    Label("Photo import with offline barcode detection", systemImage: "photo")
                    Label("Wi-Fi, contact, event, OTP, deep links, and more", systemImage: "square.grid.3x3")
                    Label("Palette, export resolution, and recovery level", systemImage: "swatchpalette")
                    Label("Local library with favorites and instant reuse", systemImage: "tray.full")
                }
            }
            .listStyle(.insetGrouped)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Settings")
            .onAppear {
                Haptics.shared.isEnabled = hapticsEnabled
            }
            .onChange(of: hapticsEnabled) { newValue in
                Haptics.shared.isEnabled = newValue
            }
        }
    }

    private var statusText: String {
        switch scanner.permissionState {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .unknown: return "Not determined"
        case .configuring: return "Configuring"
        }
    }
}
