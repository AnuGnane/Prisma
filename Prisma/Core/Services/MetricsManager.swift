//
//  MetricsManager.swift
//  Prisma
//
//  Subscribes to MetricKit and logs crash/hang diagnostics.
//
//  MetricKit delivers payloads at most once per day (after a device-idle
//  window). To trigger an immediate delivery during development, use the
//  "Simulate MetricKit Payloads" Xcode scheme action.
//
//  To forward payloads to a remote service (Crashlytics, Sentry, etc.),
//  add the upload call inside didReceive(_:) below the DEBUG log block.
//

import MetricKit
import Foundation

final class MetricsManager: NSObject, MXMetricManagerSubscriber {

    static let shared = MetricsManager()

    private override init() {
        super.init()
    }

    /// Call once at app launch (from PrismaApp.init) to begin receiving payloads.
    func register() {
        MXMetricManager.shared.add(self)
    }

    // MARK: - MXMetricManagerSubscriber

    /// Receives performance metric payloads (CPU, memory, disk, network, etc.).
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            #if DEBUG
            let json = payload.jsonRepresentation()
            let pretty = json.prettyPrintedString ?? json.debugDescription
            print("[MetricsManager] Metric payload:\n\(pretty)")
            #endif
            // TODO: forward to remote analytics (Crashlytics, Sentry, etc.)
        }
    }

    /// Receives diagnostic payloads: crashes, hangs, CPU exceptions, disk-write exceptions.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            #if DEBUG
            let json = payload.jsonRepresentation()
            let pretty = json.prettyPrintedString ?? json.debugDescription
            print("[MetricsManager] Diagnostic payload:\n\(pretty)")

            if let crashes = payload.crashDiagnostics, !crashes.isEmpty {
                print("[MetricsManager]   \(crashes.count) crash(es)")
            }
            if let hangs = payload.hangDiagnostics, !hangs.isEmpty {
                print("[MetricsManager]   \(hangs.count) hang(s)")
            }
            if let cpuExceptions = payload.cpuExceptionDiagnostics, !cpuExceptions.isEmpty {
                print("[MetricsManager]   \(cpuExceptions.count) CPU exception(s)")
            }
            if let diskExceptions = payload.diskWriteExceptionDiagnostics, !diskExceptions.isEmpty {
                print("[MetricsManager]   \(diskExceptions.count) disk-write exception(s)")
            }
            #endif
            // TODO: forward to remote crash reporting service
        }
    }
}

// MARK: - Helpers

private extension Data {
    /// Returns a human-readable pretty-printed JSON string, or nil if parsing fails.
    var prettyPrintedString: String? {
        guard let obj = try? JSONSerialization.jsonObject(with: self),
              let data = try? JSONSerialization.data(withJSONObject: obj, options: .prettyPrinted) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
