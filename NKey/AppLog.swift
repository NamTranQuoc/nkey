import OSLog

enum AppLog {
    private static let subsystem = "com.local.NKey"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let input = Logger(subsystem: subsystem, category: "input")
    static let suggestions = Logger(subsystem: subsystem, category: "suggestions")
    static let automation = Logger(subsystem: subsystem, category: "automation")
}
