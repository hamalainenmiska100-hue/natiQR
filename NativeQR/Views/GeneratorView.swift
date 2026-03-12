import SwiftUI

struct GeneratorView: View {
    @ObservedObject var viewModel: QRGeneratorViewModel
    @EnvironmentObject private var libraryStore: QRLibraryStore
    @State private var shareURL: URL?
    @State private var sharePayload = false
    @AppStorage("animationsEnabled") private var animationsEnabled = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    previewCard
                    kindSelector
                    configurationCard
                    actionCard
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Create")
            .sheet(isPresented: Binding(get: { shareURL != nil }, set: { if !$0 { shareURL = nil } })) {
                if let shareURL {
                    ActivityView(items: [shareURL])
                }
            }
            .sheet(isPresented: $sharePayload) {
                ActivityView(items: [viewModel.payload])
            }
        }
    }

    private var previewCard: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(viewModel.palette.background)
                    .frame(height: 320)

                if let image = viewModel.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(18)
                        .id(viewModel.payload + viewModel.palette.rawValue + viewModel.correctionLevel.rawValue)
                        .transition(.blurReplace)
                } else {
                    EmptyStateCard(title: "Live preview", message: viewModel.validationMessage ?? "Choose a template and fill in the fields to render a crisp QR code.", systemImage: "qrcode")
                        .padding(24)
                }
            }
            .animation(animationsEnabled ? .smooth(duration: 0.22) : nil, value: viewModel.payload)

            VStack(alignment: .leading, spacing: 10) {
                Text(viewModel.selectedKind.title)
                    .font(.title3.weight(.semibold))
                Text(viewModel.selectedKind.shortDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    PillBadge(title: "ECC \(viewModel.correctionLevel.title)", systemImage: "shield.lefthalf.filled")
                    PillBadge(title: "\(Int(viewModel.exportDimension)) px", systemImage: "arrow.up.left.and.arrow.down.right")
                    PillBadge(title: viewModel.palette.title, systemImage: "swatchpalette")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var kindSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(QRCodeKind.allCases) { kind in
                    Button {
                        viewModel.selectedKind = kind
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: kind.icon)
                                .font(.title3)
                                .symbolEffect(.bounce, value: viewModel.selectedKind == kind)
                            Text(kind.title)
                                .font(.footnote.weight(.semibold))
                        }
                        .frame(width: 92, height: 76)
                        .background(viewModel.selectedKind == kind ? Color(uiColor: .label).opacity(0.08) : Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Configuration")
                .font(.title3.weight(.semibold))

            formForSelectedKind

            Divider()

            Picker("Palette", selection: $viewModel.palette) {
                ForEach(QRPalette.allCases) { palette in
                    Text(palette.title).tag(palette)
                }
            }
            .pickerStyle(.segmented)

            Picker("Recovery", selection: $viewModel.correctionLevel) {
                ForEach(QRErrorCorrectionLevel.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Export size")
                    Spacer()
                    Text("\(Int(viewModel.exportDimension)) px")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                Slider(value: $viewModel.exportDimension, in: 512...2048, step: 256)
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .animation(animationsEnabled ? .snappy(duration: 0.24) : nil, value: viewModel.selectedKind)
    }

    @ViewBuilder
    private var formForSelectedKind: some View {
        switch viewModel.selectedKind {
        case .text:
            textField("Text", text: $viewModel.textValue, prompt: "Paste any content")
        case .website:
            textField("Website", text: $viewModel.websiteValue, prompt: "https://example.com")
        case .wifi:
            textField("Network name", text: $viewModel.wifiSSID, prompt: "Office Wi-Fi")
            SecureField("Password", text: $viewModel.wifiPassword)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.wifiSecurity == .none)
            Picker("Security", selection: $viewModel.wifiSecurity) {
                ForEach(WiFiSecurity.allCases) { security in
                    Text(security.title).tag(security)
                }
            }
            .pickerStyle(.segmented)
            Toggle("Hidden network", isOn: $viewModel.wifiHidden)
        case .phone:
            textField("Phone number", text: $viewModel.phoneValue, prompt: "+358401234567")
                .keyboardType(.phonePad)
        case .email:
            textField("Email", text: $viewModel.emailValue, prompt: "hello@example.com")
                .keyboardType(.emailAddress)
            textField("Subject", text: $viewModel.emailSubject, prompt: "Optional subject")
            TextField("Body", text: $viewModel.emailBody, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
        case .sms:
            textField("Number", text: $viewModel.smsNumber, prompt: "+358401234567")
                .keyboardType(.phonePad)
            TextField("Message", text: $viewModel.smsBody, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
        case .contact:
            textField("First name", text: $viewModel.contactFirstName, prompt: "Ada")
            textField("Last name", text: $viewModel.contactLastName, prompt: "Lovelace")
            textField("Organization", text: $viewModel.contactOrganization, prompt: "Example Inc.")
            textField("Phone", text: $viewModel.contactPhone, prompt: "+358401234567")
            textField("Email", text: $viewModel.contactEmail, prompt: "ada@example.com")
            textField("Website", text: $viewModel.contactURL, prompt: "https://example.com")
        case .location:
            textField("Latitude", text: $viewModel.latitude, prompt: "61.8687")
                .keyboardType(.numbersAndPunctuation)
            textField("Longitude", text: $viewModel.longitude, prompt: "28.8799")
                .keyboardType(.numbersAndPunctuation)
            textField("Label", text: $viewModel.locationLabel, prompt: "Optional place name")
        case .event:
            textField("Event title", text: $viewModel.eventTitle, prompt: "Meeting")
            textField("Location", text: $viewModel.eventLocation, prompt: "Conference room")
            Toggle("All day", isOn: $viewModel.eventAllDay)
            DatePicker("Starts", selection: $viewModel.eventStarts)
            DatePicker("Ends", selection: $viewModel.eventEnds)
            TextField("Notes", text: $viewModel.eventNotes, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
        case .facetime:
            textField("Phone or email", text: $viewModel.facetimeAddress, prompt: "name@example.com")
        case .appLink:
            textField("Custom scheme or URL", text: $viewModel.appLink, prompt: "myapp://open/item/42")
        case .otp:
            textField("Issuer", text: $viewModel.otpIssuer, prompt: "NativeQR")
            textField("Account", text: $viewModel.otpAccount, prompt: "user@example.com")
            textField("Secret", text: $viewModel.otpSecret, prompt: "JBSWY3DPEHPK3PXP")
                .textInputAutocapitalization(.characters)
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.title3.weight(.semibold))

            if let validationMessage = viewModel.validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Button {
                    guard let preview = viewModel.previewImage else {
                        Haptics.shared.warning()
                        return
                    }
                    let parsed = QRPayloadParser.parse(viewModel.payload)
                    libraryStore.add(payload: viewModel.payload, parsed: parsed, source: .created)
                    do {
                        shareURL = try QRCodeGeneratorService.exportPNG(preview, name: parsed.title)
                        Haptics.shared.success()
                    } catch {
                        Haptics.shared.warning()
                    }
                } label: {
                    Label("Share PNG", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.validationMessage != nil)

                Button {
                    guard !viewModel.payload.isEmpty else {
                        Haptics.shared.warning()
                        return
                    }
                    UIPasteboard.general.string = viewModel.payload
                    Haptics.shared.success()
                } label: {
                    Label("Copy Payload", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.validationMessage != nil)
            }

            HStack(spacing: 12) {
                Button {
                    guard !viewModel.payload.isEmpty else {
                        Haptics.shared.warning()
                        return
                    }
                    let parsed = QRPayloadParser.parse(viewModel.payload)
                    libraryStore.add(payload: viewModel.payload, parsed: parsed, source: .created)
                    Haptics.shared.success()
                } label: {
                    Label("Save to Library", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.validationMessage != nil)

                Button {
                    sharePayload = true
                    Haptics.shared.selection()
                } label: {
                    Label("Share Payload", systemImage: "paperplane")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.validationMessage != nil)
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func textField(_ title: String, text: Binding<String>, prompt: String) -> some View {
        TextField(title, text: text, prompt: Text(prompt))
            .textFieldStyle(.roundedBorder)
    }
}
