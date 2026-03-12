import Foundation
import UIKit

@MainActor
final class QRGeneratorViewModel: ObservableObject {
    @Published var selectedKind: QRCodeKind = .text {
        didSet {
            Haptics.shared.selection()
        }
    }

    @Published var palette: QRPalette = .classic
    @Published var correctionLevel: QRErrorCorrectionLevel = .medium
    @Published var exportDimension: CGFloat = 1024

    @Published var textValue = ""
    @Published var websiteValue = ""
    @Published var wifiSSID = ""
    @Published var wifiPassword = ""
    @Published var wifiSecurity: WiFiSecurity = .wpa
    @Published var wifiHidden = false
    @Published var phoneValue = ""
    @Published var emailValue = ""
    @Published var emailSubject = ""
    @Published var emailBody = ""
    @Published var smsNumber = ""
    @Published var smsBody = ""
    @Published var contactFirstName = ""
    @Published var contactLastName = ""
    @Published var contactOrganization = ""
    @Published var contactPhone = ""
    @Published var contactEmail = ""
    @Published var contactURL = ""
    @Published var latitude = ""
    @Published var longitude = ""
    @Published var locationLabel = ""
    @Published var eventTitle = ""
    @Published var eventLocation = ""
    @Published var eventNotes = ""
    @Published var eventStarts = Date()
    @Published var eventEnds = Date().addingTimeInterval(3600)
    @Published var eventAllDay = false
    @Published var facetimeAddress = ""
    @Published var appLink = ""
    @Published var otpIssuer = ""
    @Published var otpAccount = ""
    @Published var otpSecret = ""

    var payload: String {
        switch selectedKind {
        case .text:
            return textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        case .website:
            let trimmed = websiteValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "" }
            return trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        case .wifi:
            guard !wifiSSID.isEmpty else { return "" }
            let hiddenPart = wifiHidden ? "true" : "false"
            let password = wifiSecurity == .none ? "" : wifiPassword
            return "WIFI:T:\(wifiSecurity.rawValue);S:\(escaped(wifiSSID));P:\(escaped(password));H:\(hiddenPart);;"
        case .phone:
            let trimmed = phoneValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "" : "TEL:\(trimmed)"
        case .email:
            guard !emailValue.isEmpty else { return "" }
            var components = URLComponents()
            components.scheme = "mailto"
            components.path = emailValue
            var queryItems: [URLQueryItem] = []
            if !emailSubject.isEmpty { queryItems.append(URLQueryItem(name: "subject", value: emailSubject)) }
            if !emailBody.isEmpty { queryItems.append(URLQueryItem(name: "body", value: emailBody)) }
            components.queryItems = queryItems.isEmpty ? nil : queryItems
            return components.string ?? "mailto:\(emailValue)"
        case .sms:
            guard !smsNumber.isEmpty else { return "" }
            return smsBody.isEmpty ? "SMSTO:\(smsNumber):" : "SMSTO:\(smsNumber):\(smsBody)"
        case .contact:
            let nameLine = [contactFirstName, contactLastName].filter { !$0.isEmpty }.joined(separator: " ")
            guard !nameLine.isEmpty else { return "" }
            var lines = [
                "BEGIN:VCARD",
                "VERSION:3.0",
                "FN:\(nameLine)"
            ]
            if !contactLastName.isEmpty || !contactFirstName.isEmpty {
                lines.append("N:\(contactLastName);\(contactFirstName);;;")
            }
            if !contactOrganization.isEmpty { lines.append("ORG:\(contactOrganization)") }
            if !contactPhone.isEmpty { lines.append("TEL;TYPE=CELL:\(contactPhone)") }
            if !contactEmail.isEmpty { lines.append("EMAIL;TYPE=INTERNET:\(contactEmail)") }
            if !contactURL.isEmpty { lines.append("URL:\(contactURL)") }
            lines.append("END:VCARD")
            return lines.joined(separator: "\n")
        case .location:
            guard !latitude.isEmpty, !longitude.isEmpty else { return "" }
            let label = locationLabel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? locationLabel
            return locationLabel.isEmpty ? "geo:\(latitude),\(longitude)" : "geo:\(latitude),\(longitude)?q=\(label)"
        case .event:
            guard !eventTitle.isEmpty else { return "" }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
            let startString = eventAllDay ? dayStamp(eventStarts) : formatter.string(from: eventStarts)
            let endString = eventAllDay ? dayStamp(eventEnds) : formatter.string(from: eventEnds)
            var lines = [
                "BEGIN:VEVENT",
                "SUMMARY:\(eventTitle)",
                "DTSTART:\(startString)",
                "DTEND:\(endString)"
            ]
            if !eventLocation.isEmpty { lines.append("LOCATION:\(eventLocation)") }
            if !eventNotes.isEmpty { lines.append("DESCRIPTION:\(eventNotes)") }
            lines.append("END:VEVENT")
            return lines.joined(separator: "\n")
        case .facetime:
            let trimmed = facetimeAddress.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "" : "facetime://\(trimmed)"
        case .appLink:
            return appLink.trimmingCharacters(in: .whitespacesAndNewlines)
        case .otp:
            guard !otpIssuer.isEmpty, !otpAccount.isEmpty, !otpSecret.isEmpty else { return "" }
            let label = "\(otpIssuer):\(otpAccount)".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "\(otpIssuer):\(otpAccount)"
            let issuer = otpIssuer.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? otpIssuer
            let secret = otpSecret.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? otpSecret
            return "otpauth://totp/\(label)?secret=\(secret)&issuer=\(issuer)"
        }
    }

    var previewImage: UIImage? {
        QRCodeGeneratorService.makeImage(from: payload, correctionLevel: correctionLevel, palette: palette, dimension: exportDimension)
    }

    var parsedPreview: ParsedQRContent {
        QRPayloadParser.parse(payload.isEmpty ? selectedKind.title : payload)
    }

    var validationMessage: String? {
        switch selectedKind {
        case .text:
            return textValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter some text to generate a code." : nil
        case .website:
            return websiteValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Enter a website or app URL." : nil
        case .wifi:
            return wifiSSID.isEmpty ? "Enter the Wi-Fi network name." : nil
        case .phone:
            return phoneValue.isEmpty ? "Enter a phone number." : nil
        case .email:
            return emailValue.isEmpty ? "Enter an email address." : nil
        case .sms:
            return smsNumber.isEmpty ? "Enter a destination number." : nil
        case .contact:
            return [contactFirstName, contactLastName].joined().isEmpty ? "Enter at least a first or last name." : nil
        case .location:
            return latitude.isEmpty || longitude.isEmpty ? "Enter latitude and longitude." : nil
        case .event:
            return eventTitle.isEmpty ? "Give the event a title." : nil
        case .facetime:
            return facetimeAddress.isEmpty ? "Enter a phone number or email for FaceTime." : nil
        case .appLink:
            return appLink.isEmpty ? "Enter a custom scheme or URL." : nil
        case .otp:
            return otpIssuer.isEmpty || otpAccount.isEmpty || otpSecret.isEmpty ? "Issuer, account, and secret are required." : nil
        }
    }

    func importPayload(_ rawPayload: String, suggestedKind: QRCodeKind?) {
        let parsed = QRPayloadParser.parse(rawPayload)
        selectedKind = suggestedKind ?? parsed.kind
        switch selectedKind {
        case .text:
            textValue = rawPayload
        case .website:
            websiteValue = rawPayload
        case .wifi:
            populateWiFi(from: rawPayload)
        case .phone:
            phoneValue = parsed.fields.first(where: { $0.label == "Number" })?.value ?? rawPayload
        case .email:
            emailValue = parsed.fields.first(where: { $0.label == "Address" })?.value ?? ""
            emailSubject = parsed.fields.first(where: { $0.label == "Subject" })?.value ?? ""
            emailBody = parsed.fields.first(where: { $0.label == "Body" })?.value ?? ""
        case .sms:
            smsNumber = parsed.fields.first(where: { $0.label == "Number" })?.value ?? ""
            smsBody = parsed.fields.first(where: { $0.label == "Message" })?.value ?? ""
        case .contact:
            contactFirstName = ""
            contactLastName = parsed.subtitle
            contactOrganization = parsed.fields.first(where: { $0.label == "Organization" })?.value ?? ""
            contactPhone = parsed.fields.first(where: { $0.label == "Phone" })?.value ?? ""
            contactEmail = parsed.fields.first(where: { $0.label == "Email" })?.value ?? ""
        case .location:
            latitude = parsed.fields.first(where: { $0.label == "Latitude" })?.value ?? ""
            longitude = parsed.fields.first(where: { $0.label == "Longitude" })?.value ?? ""
            locationLabel = parsed.subtitle
        case .event:
            eventTitle = parsed.fields.first(where: { $0.label == "Title" })?.value ?? parsed.subtitle
            eventLocation = parsed.fields.first(where: { $0.label == "Location" })?.value ?? ""
        case .facetime:
            facetimeAddress = parsed.subtitle
        case .appLink:
            appLink = rawPayload
        case .otp:
            populateOTP(from: rawPayload)
        }
        Haptics.shared.success()
    }

    private func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: ";", with: "\\;")
    }

    private func dayStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func populateWiFi(from raw: String) {
        let trimmed = raw.replacingOccurrences(of: "WIFI:", with: "", options: [.caseInsensitive])
        trimmed.split(separator: ";").forEach { part in
            if part.hasPrefix("S:") { wifiSSID = String(part.dropFirst(2)) }
            if part.hasPrefix("P:") { wifiPassword = String(part.dropFirst(2)) }
            if part.hasPrefix("T:") { wifiSecurity = WiFiSecurity(rawValue: String(part.dropFirst(2))) ?? .wpa }
            if part.hasPrefix("H:") { wifiHidden = String(part.dropFirst(2)).lowercased() == "true" }
        }
    }

    private func populateOTP(from raw: String) {
        let withoutPrefix = raw.replacingOccurrences(of: "otpauth://totp/", with: "", options: [.caseInsensitive])
        let pieces = withoutPrefix.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let label = pieces.first?.removingPercentEncoding ?? ""
        let query = URLComponents(string: "https://dummy.invalid/?" + (pieces.count > 1 ? pieces[1] : ""))
        otpIssuer = query?.queryItems?.first(where: { $0.name == "issuer" })?.value ?? label.split(separator: ":").first.map(String.init) ?? ""
        otpAccount = label.split(separator: ":").last.map(String.init) ?? ""
        otpSecret = query?.queryItems?.first(where: { $0.name == "secret" })?.value ?? ""
    }
}
