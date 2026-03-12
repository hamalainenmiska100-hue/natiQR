import SwiftUI
import AVFoundation
import UIKit

final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

struct DetailFieldRow: View {
    let field: QRInfoField
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(field.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(field.value)
                .font(.body)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

struct PillBadge: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: Capsule())
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .semibold))
                .symbolEffect(.pulse, value: title)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct QRDetailCard: View {
    let payload: String
    let parsed: ParsedQRContent
    let image: UIImage?
    let onUseInCreator: () -> Void
    let onFavoriteToggle: (() -> Void)?
    let isFavorite: Bool

    @Environment(\.openURL) private var openURL
    @State private var isSharing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(maxWidth: 240)
                        .padding(20)
                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .id(parsed.rawValue)
                        .transition(.blurReplace)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(parsed.title)
                                .font(.title3.weight(.semibold))
                            Text(parsed.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let onFavoriteToggle {
                            Button(action: onFavoriteToggle) {
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    ForEach(Array(parsed.fields.enumerated()), id: \.offset) { index, field in
                        DetailFieldRow(field: field)
                        if index < parsed.fields.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(20)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                HStack(spacing: 12) {
                    if let action = parsed.primaryURLString, let url = URL(string: action) {
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
                        UIPasteboard.general.string = payload
                        Haptics.shared.success()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 12) {
                    Button {
                        isSharing = true
                        Haptics.shared.selection()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: onUseInCreator) {
                        Label("Use in Creator", systemImage: "plus.square.on.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $isSharing) {
            ActivityView(items: [payload])
        }
    }
}
