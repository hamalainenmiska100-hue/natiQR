import SwiftUI
import PhotosUI
import UIKit

struct ScannerView: View {
    @ObservedObject var viewModel: QRScannerViewModel
    @EnvironmentObject private var libraryStore: QRLibraryStore
    @EnvironmentObject private var router: AppRouter
    @Environment(\.openURL) private var openURL
    @AppStorage("autoSaveScans") private var autoSaveScans = true
    @AppStorage("autoCopyScans") private var autoCopyScans = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var showPermissionInfo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    scannerCard
                    if let capture = viewModel.lastCapture {
                        resultCard(capture)
                            .transition(.blurReplace)
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Scan")
            .sheet(isPresented: $showPermissionInfo) {
                permissionSheet
                    .presentationDetents([.medium])
            }
            .onChange(of: selectedPhoto) { item in
                guard let item else { return }
                Task {
                    await importPhoto(item)
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fast scanner")
                .font(.title2.weight(.semibold))
            Text("Scan QR codes and common barcodes, then jump into native actions, copy details, or send the result straight to the creator.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                PillBadge(title: "Live camera", systemImage: "camera.viewfinder")
                PillBadge(title: "Photo import", systemImage: "photo")
                PillBadge(title: "Auto parsing", systemImage: "sparkles.rectangle.stack")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var scannerCard: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black)
                    .frame(height: 360)

                switch viewModel.permissionState {
                case .authorized, .configuring:
                    CameraPreviewView(session: viewModel.session)
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .overlay(alignment: .center) {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.9), lineWidth: 2)
                                .frame(width: 240, height: 240)
                        }
                case .unknown:
                    EmptyStateCard(title: "Camera access needed", message: "Allow camera access to scan instantly, or import a screenshot from Photos.", systemImage: "camera.badge.ellipsis")
                        .padding(24)
                case .denied:
                    EmptyStateCard(title: "Camera unavailable", message: "You can still scan from screenshots. For live scanning, allow camera access in Settings.", systemImage: "camera.fill.badge.xmark")
                        .padding(24)
                }
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.permissionState == .authorized {
                    Button {
                        viewModel.toggleTorch()
                    } label: {
                        Image(systemName: viewModel.torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title3)
                            .padding(12)
                            .background(.thinMaterial, in: Circle())
                    }
                    .padding(16)
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                primaryActionButton
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(isLoadingPhoto ? "Importing…" : "Scan from Photo", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingPhoto)
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        switch viewModel.permissionState {
        case .authorized:
            Button {
                if viewModel.lastCapture == nil {
                    viewModel.start()
                } else {
                    viewModel.resetAndResume()
                }
                Haptics.shared.selection()
            } label: {
                Label(viewModel.lastCapture == nil ? "Live Scan" : "Scan Again", systemImage: viewModel.lastCapture == nil ? "viewfinder" : "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        case .unknown:
            Button {
                viewModel.requestCameraAccess()
                Haptics.shared.selection()
            } label: {
                Label("Allow Camera", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        case .denied:
            Button {
                showPermissionInfo = true
                Haptics.shared.warning()
            } label: {
                Label("How to Enable", systemImage: "questionmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        case .configuring:
            ProgressView()
                .frame(maxWidth: .infinity)
        }
    }

    private func resultCard(_ capture: QRScannerViewModel.ScanCapture) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(capture.parsed.title)
                        .font(.title3.weight(.semibold))
                    Text(capture.parsed.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                Spacer()
                PillBadge(title: capture.symbology.uppercased(), systemImage: "qrcode.viewfinder")
            }

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(capture.parsed.fields.enumerated()), id: \.offset) { index, field in
                    DetailFieldRow(field: field)
                    if index < capture.parsed.fields.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 2)

            HStack(spacing: 12) {
                if let primaryURL = capture.parsed.primaryURLString, let url = URL(string: primaryURL) {
                    Button {
                        openURL(url)
                        Haptics.shared.impact(.soft)
                    } label: {
                        Label("Open", systemImage: "arrow.up.forward.app")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    UIPasteboard.general.string = capture.payload
                    Haptics.shared.success()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 12) {
                Button {
                    router.openCreator(with: capture.payload, kind: capture.parsed.kind)
                } label: {
                    Label("Use in Creator", systemImage: "plus.square.on.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                ShareLink(item: capture.payload) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .task(id: capture.id) {
            if autoSaveScans {
                libraryStore.add(payload: capture.payload, parsed: capture.parsed, source: .scanned)
            }
            if autoCopyScans {
                UIPasteboard.general.string = capture.payload
            }
        }
    }

    private var permissionSheet: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.badge.ellipsis")
                .font(.system(size: 36, weight: .semibold))
            Text("Enable camera access")
                .font(.title3.weight(.semibold))
            Text("Open the system Settings app, go to NativeQR, and enable Camera. Photo import continues to work even without it.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    openURL(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            if let (payload, symbology) = try await ImageBarcodeScanner.scan(data: data) {
                viewModel.handleImportedPayload(payload, symbology: symbology)
            } else {
                Haptics.shared.warning()
            }
        } catch {
            Haptics.shared.warning()
        }
    }
}
