import SwiftUI
import Foundation
import UIKit

enum AppTab: Hashable {
    case scan
    case create
    case library
    case settings
}

enum QRCodeKind: String, CaseIterable, Codable, Identifiable {
    case text
    case website
    case wifi
    case phone
    case email
    case sms
    case contact
    case location
    case event
    case facetime
    case appLink
    case otp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "Text"
        case .website: return "Website"
        case .wifi: return "Wi-Fi"
        case .phone: return "Phone"
        case .email: return "Email"
        case .sms: return "SMS"
        case .contact: return "Contact"
        case .location: return "Location"
        case .event: return "Event"
        case .facetime: return "FaceTime"
        case .appLink: return "App Link"
        case .otp: return "One-Time Code"
        }
    }

    var icon: String {
        switch self {
        case .text: return "text.alignleft"
        case .website: return "globe"
        case .wifi: return "wifi"
        case .phone: return "phone"
        case .email: return "envelope"
        case .sms: return "message"
        case .contact: return "person.crop.circle"
        case .location: return "mappin.and.ellipse"
        case .event: return "calendar"
        case .facetime: return "video"
        case .appLink: return "link.circle"
        case .otp: return "key"
        }
    }

    var shortDescription: String {
        switch self {
        case .text: return "Notes, IDs, plain content"
        case .website: return "Links and landing pages"
        case .wifi: return "SSID, password, security"
        case .phone: return "Tap-to-call code"
        case .email: return "Pre-filled email link"
        case .sms: return "Pre-filled text message"
        case .contact: return "vCard contact card"
        case .location: return "Maps and coordinates"
        case .event: return "Calendar event payload"
        case .facetime: return "Audio or video contact"
        case .appLink: return "Custom schemes and deep links"
        case .otp: return "Authenticator setup"
        }
    }
}

enum WiFiSecurity: String, CaseIterable, Identifiable {
    case wpa = "WPA"
    case wep = "WEP"
    case none = "nopass"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wpa: return "WPA / WPA2"
        case .wep: return "WEP"
        case .none: return "Open"
        }
    }
}

enum QRPalette: String, CaseIterable, Codable, Identifiable {
    case classic
    case inverted
    case graphite
    case forest
    case cobalt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .inverted: return "Inverted"
        case .graphite: return "Graphite"
        case .forest: return "Forest"
        case .cobalt: return "Cobalt"
        }
    }

    var uiForeground: UIColor {
        switch self {
        case .classic: return .black
        case .inverted: return .white
        case .graphite: return UIColor(red: 0.16, green: 0.18, blue: 0.21, alpha: 1)
        case .forest: return UIColor(red: 0.11, green: 0.28, blue: 0.20, alpha: 1)
        case .cobalt: return UIColor(red: 0.10, green: 0.20, blue: 0.52, alpha: 1)
        }
    }

    var uiBackground: UIColor {
        switch self {
        case .classic: return .white
        case .inverted: return .black
        case .graphite: return UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1)
        case .forest: return UIColor(red: 0.96, green: 0.98, blue: 0.96, alpha: 1)
        case .cobalt: return UIColor(red: 0.96, green: 0.97, blue: 1.0, alpha: 1)
        }
    }

    var foreground: Color { Color(uiColor: uiForeground) }
    var background: Color { Color(uiColor: uiBackground) }
}

enum QRErrorCorrectionLevel: String, CaseIterable, Codable, Identifiable {
    case low = "L"
    case medium = "M"
    case quartile = "Q"
    case high = "H"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "L"
        case .medium: return "M"
        case .quartile: return "Q"
        case .high: return "H"
        }
    }

    var subtitle: String {
        switch self {
        case .low: return "Maximum capacity"
        case .medium: return "Balanced"
        case .quartile: return "Robust"
        case .high: return "Highest recovery"
        }
    }
}

enum QRLibrarySource: String, Codable {
    case scanned
    case created
}

struct QRInfoField: Hashable, Codable {
    var label: String
    var value: String
}

struct ParsedQRContent: Hashable, Codable {
    var kind: QRCodeKind
    var title: String
    var subtitle: String
    var fields: [QRInfoField]
    var rawValue: String
    var primaryURLString: String?
}

struct QRLibraryItem: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    var createdAt: Date
    var source: QRLibrarySource
    var title: String
    var subtitle: String
    var payload: String
    var kind: QRCodeKind
    var favorite: Bool
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: AppTab = .scan
    @Published var importedPayload: String?
    @Published var importedKind: QRCodeKind?

    func openCreator(with payload: String, kind: QRCodeKind?) {
        importedPayload = payload
        importedKind = kind
        selectedTab = .create
    }

    func clearImport() {
        importedPayload = nil
        importedKind = nil
    }
}
