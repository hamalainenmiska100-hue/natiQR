import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var libraryStore: QRLibraryStore
    @EnvironmentObject private var router: AppRouter
    @State private var searchText = ""
    @State private var selectedItem: QRLibraryItem?

    private var filteredItems: [QRLibraryItem] {
        guard !searchText.isEmpty else { return libraryStore.items }
        return libraryStore.items.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.subtitle.localizedCaseInsensitiveContains(searchText) ||
            $0.payload.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredItems.isEmpty {
                    EmptyStateCard(title: "Nothing saved yet", message: "Scans and generated QR codes appear here with favorites and instant reuse.", systemImage: "tray")
                        .padding()
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            Button {
                                selectedItem = item
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: item.kind.icon)
                                        .font(.title3)
                                        .frame(width: 34, height: 34)
                                        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(item.title)
                                                .font(.headline)
                                            if item.favorite {
                                                Image(systemName: "star.fill")
                                                    .foregroundStyle(.yellow)
                                            }
                                        }
                                        Text(item.subtitle)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 6) {
                                        Text(item.source == .scanned ? "Scanned" : "Created")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text(item.createdAt, style: .date)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    libraryStore.delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    libraryStore.toggleFavorite(item)
                                    Haptics.shared.impact(.soft)
                                } label: {
                                    Label(item.favorite ? "Unfavorite" : "Favorite", systemImage: item.favorite ? "star.slash" : "star")
                                }
                                .tint(.yellow)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search saved codes")
            .toolbar {
                if !libraryStore.items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                libraryStore.clearAll()
                            } label: {
                                Label("Clear Library", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                let parsed = QRPayloadParser.parse(item.payload)
                let image = QRCodeGeneratorService.makeImage(from: item.payload, correctionLevel: .medium, palette: .classic, dimension: 1024)
                QRDetailCard(
                    payload: item.payload,
                    parsed: parsed,
                    image: image,
                    onUseInCreator: { router.openCreator(with: item.payload, kind: item.kind) },
                    onFavoriteToggle: { libraryStore.toggleFavorite(item) },
                    isFavorite: item.favorite
                )
            }
        }
    }
}
