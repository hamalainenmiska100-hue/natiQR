import SwiftUI
import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
import ImageIO

@MainActor
final class Haptics {
    static let shared = Haptics()
    var isEnabled = true

    private init() {}

    func selection() {
        guard isEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    func success() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .soft) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

@MainActor
final class QRLibraryStore: ObservableObject {
    @Published private(set) var items: [QRLibraryItem] = []

    private let storageKey = "nativeqr.library.items"

    init() {
        load()
    }

    func add(payload: String, parsed: ParsedQRContent, source: QRLibrarySource) {
        let item = QRLibraryItem(
            createdAt: Date(),
            source: source,
            title: parsed.title,
            subtitle: parsed.subtitle,
            payload: payload,
            kind: parsed.kind,
            favorite: false
        )

        if let existing = items.firstIndex(where: { $0.payload == item.payload && $0.source == item.source }) {
            items[existing].createdAt = Date()
            items.move(fromOffsets: IndexSet(integer: existing), toOffset: 0)
        } else {
            items.insert(item, at: 0)
        }
        persist()
    }

    func toggleFavorite(_ item: QRLibraryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].favorite.toggle()
        persist()
    }

    func delete(_ item: QRLibraryItem) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func clearAll() {
        items.removeAll()
        persist()
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            assertionFailure("Failed to save library: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            items = try JSONDecoder().decode([QRLibraryItem].self, from: data)
        } catch {
            items = []
        }
    }
}

enum QRPayloadParser {
    static func parse(_ rawValue: String) -> ParsedQRContent {
        let raw = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let uppercased = raw.uppercased()

        if uppercased.hasPrefix("WIFI:") {
            return parseWiFi(raw)
        }
        if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
            return ParsedQRContent(
                kind: .website,
                title: "Website",
                subtitle: raw,
                fields: [QRInfoField(label: "URL", value: raw)],
                rawValue: raw,
                primaryURLString: raw
            )
        }
        if raw.lowercased().hasPrefix("mailto:") {
            return parseMail(raw)
        }
        if uppercased.hasPrefix("TEL:") || raw.lowercased().hasPrefix("tel:") {
            let number = raw.replacingOccurrences(of: "TEL:", with: "", options: [.caseInsensitive])
            let cleaned = number.trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedQRContent(
                kind: .phone,
                title: "Phone",
                subtitle: cleaned,
                fields: [QRInfoField(label: "Number", value: cleaned)],
                rawValue: raw,
                primaryURLString: "tel:\(cleaned)"
            )
        }
        if uppercased.hasPrefix("SMSTO:") || uppercased.hasPrefix("SMS:") {
            return parseSMS(raw)
        }
        if raw.lowercased().hasPrefix("geo:") {
            return parseGeo(raw)
        }
        if uppercased.hasPrefix("BEGIN:VCARD") {
            return parseVCard(raw)
        }
        if uppercased.hasPrefix("BEGIN:VEVENT") {
            return parseEvent(raw)
        }
        if raw.lowercased().hasPrefix("facetime://") {
            let address = raw.replacingOccurrences(of: "facetime://", with: "", options: [.caseInsensitive])
            return ParsedQRContent(
                kind: .facetime,
                title: "FaceTime",
                subtitle: address,
                fields: [QRInfoField(label: "Address", value: address)],
                rawValue: raw,
                primaryURLString: raw
            )
        }
        if raw.lowercased().hasPrefix("otpauth://") {
            return parseOTP(raw)
        }
        if raw.contains("://") {
            return ParsedQRContent(
                kind: .appLink,
                title: "App Link",
                subtitle: raw,
                fields: [QRInfoField(label: "Payload", value: raw)],
                rawValue: raw,
                primaryURLString: raw
            )
        }

        return ParsedQRContent(
            kind: .text,
            title: "Text",
            subtitle: raw.count > 60 ? String(raw.prefix(60)) + "…" : raw,
            fields: [QRInfoField(label: "Content", value: raw)],
            rawValue: raw,
            primaryURLString: nil
        )
    }

    private static func parseMail(_ raw: String) -> ParsedQRContent {
        guard let components = URLComponents(string: raw) else {
            return ParsedQRContent(kind: .email, title: "Email", subtitle: raw, fields: [QRInfoField(label: "Payload", value: raw)], rawValue: raw, primaryURLString: raw)
        }
        let email = components.path
        var fields: [QRInfoField] = [QRInfoField(label: "Address", value: email)]
        if let subject = components.queryItems?.first(where: { $0.name == "subject" })?.value, !subject.isEmpty {
            fields.append(QRInfoField(label: "Subject", value: subject))
        }
        if let body = components.queryItems?.first(where: { $0.name == "body" })?.value, !body.isEmpty {
            fields.append(QRInfoField(label: "Body", value: body))
        }
        return ParsedQRContent(kind: .email, title: "Email", subtitle: email, fields: fields, rawValue: raw, primaryURLString: raw)
    }

    private static func parseSMS(_ raw: String) -> ParsedQRContent {
        let stripped = raw.replacingOccurrences(of: "SMSTO:", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "SMS:", with: "", options: [.caseInsensitive])
        let components = stripped.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let number = components.first ?? ""
        let message = components.count > 1 ? components[1] : ""
        var fields = [QRInfoField(label: "Number", value: number)]
        if !message.isEmpty {
            fields.append(QRInfoField(label: "Message", value: message))
        }
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? message
        return ParsedQRContent(kind: .sms, title: "Message", subtitle: number, fields: fields, rawValue: raw, primaryURLString: "sms:\(number)&body=\(encoded)")
    }

    private static func parseGeo(_ raw: String) -> ParsedQRContent {
        let stripped = raw.replacingOccurrences(of: "geo:", with: "", options: [.caseInsensitive])
        let mainPart = stripped.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).map(String.init).first ?? stripped
        let parts = mainPart.split(separator: ",").map(String.init)
        let latitude = parts.first ?? ""
        let longitude = parts.count > 1 ? parts[1] : ""
        let fields = [
            QRInfoField(label: "Latitude", value: latitude),
            QRInfoField(label: "Longitude", value: longitude)
        ]
        let label = "Location"
        let mapsURL = "http://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(label.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? label)"
        return ParsedQRContent(kind: .location, title: "Location", subtitle: "\(latitude), \(longitude)", fields: fields, rawValue: raw, primaryURLString: mapsURL)
    }

    private static func parseWiFi(_ raw: String) -> ParsedQRContent {
        let body = raw.dropFirst(5)
        var ssid = ""
        var password = ""
        var type = "WPA"
        var hidden = "false"
        body.split(separator: ";").forEach { segment in
            if segment.hasPrefix("S:") { ssid = String(segment.dropFirst(2)) }
            if segment.hasPrefix("P:") { password = String(segment.dropFirst(2)) }
            if segment.hasPrefix("T:") { type = String(segment.dropFirst(2)) }
            if segment.hasPrefix("H:") { hidden = String(segment.dropFirst(2)) }
        }
        let fields = [
            QRInfoField(label: "SSID", value: ssid),
            QRInfoField(label: "Password", value: password.isEmpty ? "—" : password),
            QRInfoField(label: "Security", value: type),
            QRInfoField(label: "Hidden", value: hidden == "true" ? "Yes" : "No")
        ]
        return ParsedQRContent(kind: .wifi, title: "Wi-Fi", subtitle: ssid, fields: fields, rawValue: raw, primaryURLString: nil)
    }

    private static func parseVCard(_ raw: String) -> ParsedQRContent {
        var name = "Contact"
        var organization = ""
        var phone = ""
        var email = ""
        raw.split(whereSeparator: \.isNewline).forEach { line in
            let line = String(line)
            if line.hasPrefix("FN:") { name = String(line.dropFirst(3)) }
            if line.hasPrefix("ORG:") { organization = String(line.dropFirst(4)) }
            if line.hasPrefix("TEL") { phone = line.components(separatedBy: ":").dropFirst().joined(separator: ":") }
            if line.hasPrefix("EMAIL") { email = line.components(separatedBy: ":").dropFirst().joined(separator: ":") }
        }
        var fields = [QRInfoField(label: "Name", value: name)]
        if !organization.isEmpty { fields.append(QRInfoField(label: "Organization", value: organization)) }
        if !phone.isEmpty { fields.append(QRInfoField(label: "Phone", value: phone)) }
        if !email.isEmpty { fields.append(QRInfoField(label: "Email", value: email)) }
        return ParsedQRContent(kind: .contact, title: "Contact", subtitle: name, fields: fields, rawValue: raw, primaryURLString: nil)
    }

    private static func parseEvent(_ raw: String) -> ParsedQRContent {
        var title = "Event"
        var start = ""
        var end = ""
        var location = ""
        raw.split(whereSeparator: \.isNewline).forEach { line in
            let line = String(line)
            if line.hasPrefix("SUMMARY:") { title = String(line.dropFirst(8)) }
            if line.hasPrefix("DTSTART:") { start = String(line.dropFirst(8)) }
            if line.hasPrefix("DTEND:") { end = String(line.dropFirst(6)) }
            if line.hasPrefix("LOCATION:") { location = String(line.dropFirst(9)) }
        }
        var fields = [QRInfoField(label: "Title", value: title)]
        if !start.isEmpty { fields.append(QRInfoField(label: "Starts", value: start)) }
        if !end.isEmpty { fields.append(QRInfoField(label: "Ends", value: end)) }
        if !location.isEmpty { fields.append(QRInfoField(label: "Location", value: location)) }
        return ParsedQRContent(kind: .event, title: "Event", subtitle: title, fields: fields, rawValue: raw, primaryURLString: nil)
    }

    private static func parseOTP(_ raw: String) -> ParsedQRContent {
        let withoutPrefix = raw.replacingOccurrences(of: "otpauth://totp/", with: "", options: [.caseInsensitive])
        let parts = withoutPrefix.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let label = parts.first?.removingPercentEncoding ?? "Authenticator"
        let query = URLComponents(string: "https://dummy.invalid/?" + (parts.count > 1 ? parts[1] : ""))
        let issuer = query?.queryItems?.first(where: { $0.name == "issuer" })?.value ?? ""
        let account = label.split(separator: ":").last.map(String.init) ?? label
        var fields = [QRInfoField(label: "Account", value: account)]
        if !issuer.isEmpty { fields.append(QRInfoField(label: "Issuer", value: issuer)) }
        return ParsedQRContent(kind: .otp, title: "One-Time Code", subtitle: label, fields: fields, rawValue: raw, primaryURLString: nil)
    }
}

enum QRCodeGeneratorService {
    private static let context = CIContext()

    static func makeImage(from payload: String, correctionLevel: QRErrorCorrectionLevel, palette: QRPalette, dimension: CGFloat) -> UIImage? {
        guard !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        filter.correctionLevel = correctionLevel.rawValue

        guard let outputImage = filter.outputImage else { return nil }

        let colorFilter = CIFilter.falseColor()
        colorFilter.inputImage = outputImage
        colorFilter.color0 = CIColor(color: palette.uiForeground)
        colorFilter.color1 = CIColor(color: palette.uiBackground)

        guard let coloredImage = colorFilter.outputImage else { return nil }

        let scale = max(1, floor(dimension / coloredImage.extent.width))
        let transformed = coloredImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }

        return UIImage(cgImage: cgImage)
    }

    static func exportPNG(_ image: UIImage, name: String) throws -> URL {
        let sanitized = name.replacingOccurrences(of: " ", with: "-").lowercased()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitized)-\(UUID().uuidString).png")
        guard let data = image.pngData() else {
            throw NSError(domain: "NativeQR", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to render PNG data"])
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}

enum ImageBarcodeScanner {
    static func scan(data: Data) async throws -> (String, String)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let request = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.compactMap({ $0 as? VNBarcodeObservation }).first,
              let payload = observation.payloadStringValue else {
            return nil
        }

        return (payload, observation.symbology.rawValue)
    }
}
