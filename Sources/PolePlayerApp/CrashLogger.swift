import Foundation
import os

private let crashLog = Logger(subsystem: "PolePlayer", category: "Crash")

private func handleUncaughtException(_ exception: NSException) {
    crashLog.error("Uncaught exception: \(exception.name.rawValue, privacy: .public) \(exception.reason ?? "", privacy: .public)")
}

enum CrashLogger {
    static func install() {
        NSSetUncaughtExceptionHandler(handleUncaughtException)
    }
}
