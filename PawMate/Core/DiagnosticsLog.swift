import Foundation

enum DiagnosticsLog {

    private static let storageKey = "pawmate.activity_log"
    private static let maxEntries = 500
    private static let writeQueue = DispatchQueue(label: "pawmate.activity-log")
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func record(_ message: String) {
        print(message)
        let entry = "[\(timeFormatter.string(from: Date()))] \(message)"
        writeQueue.async {
            let defaults = UserDefaults.standard
            var entries = defaults.stringArray(forKey: storageKey) ?? []
            entries.append(entry)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
            defaults.set(entries, forKey: storageKey)
        }
    }

    static func exportAll() -> String {
        (UserDefaults.standard.stringArray(forKey: storageKey) ?? []).joined(separator: "\n")
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
