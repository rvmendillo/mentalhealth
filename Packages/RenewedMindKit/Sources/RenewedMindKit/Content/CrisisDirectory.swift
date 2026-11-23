import Foundation

public struct CrisisLine: Hashable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let detail: String
    /// Digits to dial (used for tel: links).
    public let phone: String?
    /// Number to text (used for sms: links).
    public let sms: String?
    /// Suggested message body for text lines (e.g. "HOME").
    public let smsBody: String?
    public let website: String?

    public init(id: String, name: String, detail: String, phone: String? = nil, sms: String? = nil,
                smsBody: String? = nil, website: String? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.phone = phone
        self.sms = sms
        self.smsBody = smsBody
        self.website = website
    }

    public var phoneURL: URL? { phone.flatMap { URL(string: "tel:\($0)") } }

    public var smsURL: URL? {
        guard let sms else { return nil }
        if let smsBody, let encoded = smsBody.addingPercentEncoding(withAllowedCharacters: .alphanumerics) {
            return URL(string: "sms:\(sms)&body=\(encoded)")
        }
        return URL(string: "sms:\(sms)")
    }

    public var websiteURL: URL? { website.flatMap { URL(string: $0) } }
}

public struct CrisisRegion: Hashable, Sendable, Identifiable {
    /// ISO 3166-1 alpha-2 code, or "INTL" for the fallback.
    public let code: String
    public let name: String
    public let emergencyNumber: String
    public let lines: [CrisisLine]

    public var id: String { code }

    public var emergencyURL: URL? { URL(string: "tel:\(emergencyNumber)") }
}

/// Verified crisis resources. If a region isn't listed, the international directory is shown.
public enum CrisisDirectory {
    public static let findAHelpline = CrisisLine(
        id: "findahelpline", name: "Find a Helpline",
        detail: "Free, confidential helplines in more than 130 countries.",
        website: "https://findahelpline.com")

    public static let regions: [CrisisRegion] = [
        CrisisRegion(code: "US", name: "United States", emergencyNumber: "911", lines: [
            CrisisLine(id: "us-988", name: "988 Suicide & Crisis Lifeline",
                       detail: "Call or text 988, any time. Free and confidential.",
                       phone: "988", sms: "988", website: "https://988lifeline.org"),
            CrisisLine(id: "us-ctl", name: "Crisis Text Line", detail: "Text HOME to 741741.",
                       sms: "741741", smsBody: "HOME", website: "https://www.crisistextline.org"),
            CrisisLine(id: "us-dv", name: "National Domestic Violence Hotline",
                       detail: "Call 1-800-799-7233 or text START to 88788.",
                       phone: "18007997233", sms: "88788", smsBody: "START", website: "https://www.thehotline.org"),
        ]),
        CrisisRegion(code: "CA", name: "Canada", emergencyNumber: "911", lines: [
            CrisisLine(id: "ca-988", name: "9-8-8 Suicide Crisis Helpline",
                       detail: "Call or text 988, any time.", phone: "988", sms: "988", website: "https://988.ca"),
        ]),
        CrisisRegion(code: "GB", name: "United Kingdom", emergencyNumber: "999", lines: [
            CrisisLine(id: "gb-samaritans", name: "Samaritans", detail: "Call 116 123, free, any time.",
                       phone: "116123", website: "https://www.samaritans.org"),
        ]),
        CrisisRegion(code: "IE", name: "Ireland", emergencyNumber: "112", lines: [
            CrisisLine(id: "ie-samaritans", name: "Samaritans", detail: "Call 116 123, free, any time.",
                       phone: "116123", website: "https://www.samaritans.org"),
        ]),
        CrisisRegion(code: "AU", name: "Australia", emergencyNumber: "000", lines: [
            CrisisLine(id: "au-lifeline", name: "Lifeline", detail: "Call 13 11 14, any time.",
                       phone: "131114", website: "https://www.lifeline.org.au"),
        ]),
        CrisisRegion(code: "NZ", name: "New Zealand", emergencyNumber: "111", lines: [
            CrisisLine(id: "nz-1737", name: "Need to talk? 1737", detail: "Call or text 1737, free, any time.",
                       phone: "1737", sms: "1737", website: "https://1737.org.nz"),
        ]),
        CrisisRegion(code: "PH", name: "Philippines", emergencyNumber: "911", lines: [
            CrisisLine(id: "ph-ncmh", name: "NCMH Crisis Hotline",
                       detail: "Call 1553 (landline, toll-free), 0917 899 8727 (Globe/TM), or 0919 057 1553 (Smart/TNT). 24/7.",
                       phone: "1553"),
        ]),
        CrisisRegion(code: "IN", name: "India", emergencyNumber: "112", lines: [
            CrisisLine(id: "in-telemanas", name: "Tele-MANAS",
                       detail: "Call 14416 or 1-800-891-4416, free, 24/7, in many languages.",
                       phone: "14416"),
        ]),
    ]

    public static let international = CrisisRegion(
        code: "INTL", name: "Elsewhere", emergencyNumber: "112", lines: [findAHelpline])

    /// The region for a country code, falling back to the international directory.
    public static func region(for code: String?) -> CrisisRegion {
        guard let code = code?.uppercased() else { return international }
        return regions.first { $0.code == code } ?? international
    }
}
