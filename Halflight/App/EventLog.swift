import Foundation
import os

/// DEBUG-only event log. No analytics SDK, nothing leaves the device.
enum EventLog {
    static func log(_ name: String, _ meta: [String: String] = [:]) {
        #if DEBUG
        let logger = Logger(subsystem: "app.halflight.duo", category: "events")
        if meta.isEmpty {
            logger.debug("event=\(name, privacy: .public)")
        } else {
            let pairs = meta.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
            logger.debug("event=\(name, privacy: .public) \(pairs, privacy: .public)")
        }
        #endif
    }
}
