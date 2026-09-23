import Foundation

enum StorageMonitor {
    /// Free space the system is willing to give an app for important data, in bytes.
    static func availableBytes() -> Int64? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage
    }

    static func hasRoom(minimumMB: Int) -> Bool {
        guard let bytes = availableBytes() else { return true }
        return bytes > Int64(minimumMB) * 1_024 * 1_024
    }
}
