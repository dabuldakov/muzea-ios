import Foundation

/// Длительность медиа в формате `m:ss` / `h:mm:ss`.
enum DurationFormatter {
    static func mmss(_ totalSeconds: Int) -> String {
        let seconds = max(0, totalSeconds)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
