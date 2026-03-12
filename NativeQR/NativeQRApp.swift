import SwiftUI

@main
struct NativeQRApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var libraryStore = QRLibraryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .environmentObject(libraryStore)
        }
    }
}
