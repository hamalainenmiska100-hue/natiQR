import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var libraryStore: QRLibraryStore
    @StateObject private var scanner = QRScannerViewModel()
    @StateObject private var generator = QRGeneratorViewModel()
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ScannerView(viewModel: scanner)
                .tabItem {
                    Label("Scan", systemImage: router.selectedTab == .scan ? "viewfinder.circle.fill" : "viewfinder.circle")
                }
                .tag(AppTab.scan)

            GeneratorView(viewModel: generator)
                .tabItem {
                    Label("Create", systemImage: router.selectedTab == .create ? "qrcode" : "plus.square.on.square")
                }
                .tag(AppTab.create)

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: router.selectedTab == .library ? "tray.full.fill" : "tray.full")
                }
                .tag(AppTab.library)

            SettingsView(scanner: scanner)
                .tabItem {
                    Label("Settings", systemImage: router.selectedTab == .settings ? "slider.horizontal.3" : "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(.primary)
        .onAppear {
            Haptics.shared.isEnabled = hapticsEnabled
            scanner.prepareIfNeeded()
        }
        .onChange(of: hapticsEnabled) { newValue in
            Haptics.shared.isEnabled = newValue
        }
        .onChange(of: router.selectedTab) { _ in
            Haptics.shared.selection()
        }
        .onChange(of: router.importedPayload) { payload in
            guard let payload else { return }
            generator.importPayload(payload, suggestedKind: router.importedKind)
            router.clearImport()
        }
    }
}
