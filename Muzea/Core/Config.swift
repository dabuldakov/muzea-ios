import Foundation

enum Config {
    static let makeupBaseURL = URL(string: "http://90.188.89.63:8085")!
    static let chatBaseURL = URL(string: "http://90.188.89.63:8086")!

    static let newsPageSize = 20
    static let messagePageSize = 50
    static let chatPollInterval: UInt64 = 3_000_000_000 // 3s in nanoseconds
    static let unreadPollInterval: UInt64 = 10_000_000_000 // 10s
}
