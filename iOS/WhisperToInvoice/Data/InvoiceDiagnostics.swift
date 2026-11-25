import Foundation
import MetricKit
import UIKit
import os

/// Crash / memory diagnostics for the invoice flow (Android: `InvoiceDiagnostics`).
///
/// Only sizes, counters and system info are logged here — never invoice content, client names or
/// audio data.
enum InvoiceDiagnostics {

    private static let megabyte: UInt64 = 1024 * 1024

    /// Logs device RAM, the memory this process may still allocate, and the process footprint,
    /// tagged with `label`.
    static func logMemory(_ label: String) {
        let physical = ProcessInfo.processInfo.physicalMemory / megabyte
        let available = UInt64(os_proc_available_memory()) / megabyte
        let footprint = currentFootprintBytes().map { $0 / megabyte }
        let thermal = ProcessInfo.processInfo.thermalState
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        AppLog.diagnostics.debug(
            """
            [\(label, privacy: .public)] deviceRam=\(physical, privacy: .public)MB \
            availableToProcess=\(available, privacy: .public)MB \
            footprint=\(footprint.map(String.init) ?? "n/a", privacy: .public)MB \
            thermalState=\(thermal.rawValue, privacy: .public) lowPowerMode=\(lowPower, privacy: .public)
            """)
    }

    /// The process's physical memory footprint (what iOS uses to decide on jetsam kills).
    private static func currentFootprintBytes() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? UInt64(info.phys_footprint) : nil
    }

    /// Logs why previous app runs ended abnormally (crash, watchdog, memory exception...). This is
    /// the iOS counterpart of Android's `getHistoricalProcessExitReasons`; it relies on the
    /// MetricKit diagnostic reports of iOS 27 and later.
    static func startPreviousExitReporting() {
        guard #available(iOS 27.0, *) else {
            AppLog.diagnostics.info("Previous-exit diagnostics require iOS 27; skipped on this OS version")
            return
        }
        PreviousExitReporter.shared.start()
    }
}

@available(iOS 27.0, *)
private final class PreviousExitReporter: @unchecked Sendable {
    static let shared = PreviousExitReporter()

    private let manager = MetricManager()
    private let lock = OSAllocatedUnfairLock(initialState: false)

    func start() {
        let alreadyStarted = lock.withLock { started -> Bool in
            let previous = started
            started = true
            return previous
        }
        if alreadyStarted { return }
        let manager = self.manager
        Task.detached(priority: .utility) {
            for await report in manager.diagnosticReports {
                Self.log(report)
            }
        }
    }

    private static func log(_ report: DiagnosticReport) {
        let window = report.timeRange
        switch report.result {
        case .crash(let crash):
            AppLog.diagnostics.warning(
                """
                Previous exit: CRASH signal=\(crash.signal.map(String.init) ?? "n/a", privacy: .public) \
                exceptionType=\(crash.exceptionType.map(String.init) ?? "n/a", privacy: .public) \
                category=\(crash.terminationCategory?.description ?? "n/a", privacy: .public) \
                window=\(window.start, privacy: .public)..\(window.end, privacy: .public)
                """)
        case .hang:
            AppLog.diagnostics.warning("Previous exit: HANG window=\(window.start, privacy: .public)")
        case .cpuException:
            AppLog.diagnostics.warning("Previous exit: CPU exception window=\(window.start, privacy: .public)")
        case .diskWriteException:
            AppLog.diagnostics.warning("Previous exit: disk-write exception window=\(window.start, privacy: .public)")
        case .appLaunch:
            AppLog.diagnostics.warning("Diagnostic: slow app launch window=\(window.start, privacy: .public)")
        case .memoryException:
            AppLog.diagnostics.warning("Previous exit: MEMORY exception (jetsam) window=\(window.start, privacy: .public)")
        @unknown default:
            AppLog.diagnostics.warning("Previous exit: other diagnostic window=\(window.start, privacy: .public)")
        }
    }
}
