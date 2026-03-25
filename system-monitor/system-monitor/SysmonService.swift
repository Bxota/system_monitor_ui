import Combine
import Foundation
import CSysmon

final class SysmonService: ObservableObject {
  enum Status: String {
    case idle
    case running
    case paused
    case error
  }

  @Published var metrics: [Metric] = []
  @Published var status: Status = .idle
  @Published var lastUpdated: Date?
  @Published var lastError: String?
  @Published var intervalMs: Int = 1000
  @Published var isPaused = false

  private var sysmon: OpaquePointer?
  private var timer: DispatchSourceTimer?
  private let queue = DispatchQueue(label: "sysmon.poller")

  deinit {
    stop()
  }

  func start() {
    guard sysmon == nil else { return }

    let iniPath = resolveIniPath()
    let result: sysmon_result_t
    if let iniPath {
      result = iniPath.withCString { cPath in
        var options = sysmon_create_options_t(ini_path: cPath)
        return withUnsafePointer(to: &options) { sysmon_create($0, &sysmon) }
      }
    } else {
      var options = sysmon_create_options_t(ini_path: nil)
      result = withUnsafePointer(to: &options) { sysmon_create($0, &sysmon) }
    }

    guard result == SYSMON_OK, let sysmon else {
      updateError("Failed to start: \(describeResult(result))")
      return
    }

    let interval = Int(sysmon_interval_ms(sysmon))
    intervalMs = interval > 0 ? interval : 1000
    status = .running

    scheduleTimer()
    refreshNow()
  }

  func stop() {
    timer?.cancel()
    timer = nil

    if let sysmon {
      sysmon_destroy(sysmon)
      self.sysmon = nil
    }

    status = .idle
  }

  func togglePause() {
    if isPaused {
      isPaused = false
      status = .running
      scheduleTimer()
      refreshNow()
    } else {
      isPaused = true
      status = .paused
      timer?.cancel()
      timer = nil
    }
  }

  func refreshNow() {
    queue.async { [weak self] in
      self?.pollOnce(force: true)
    }
  }

  private func scheduleTimer() {
    guard timer == nil else { return }
    guard intervalMs > 0 else { return }

    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now(), repeating: .milliseconds(intervalMs))
    timer.setEventHandler { [weak self] in
      self?.pollOnce(force: false)
    }
    timer.resume()
    self.timer = timer
  }

  private func pollOnce(force: Bool) {
    guard let sysmon else { return }
    if isPaused && !force { return }

    var snapshot: OpaquePointer?
    let result = sysmon_poll(sysmon, &snapshot)

    guard result == SYSMON_OK, let snapshot else {
      updateError("Poll failed: \(describeResult(result))")
      return
    }

    let count = Int(sysmon_snapshot_metric_count(snapshot))
    var collected: [Metric] = []
    collected.reserveCapacity(count)

    for index in 0..<count {
      if let metricPtr = sysmon_snapshot_metric_at(snapshot, index) {
        collected.append(Metric(cMetric: metricPtr.pointee))
      }
    }

    sysmon_snapshot_destroy(snapshot)

    let sorted = collected.sorted { lhs, rhs in
      if lhs.category == rhs.category {
        return lhs.displayName < rhs.displayName
      }
      return lhs.category < rhs.category
    }

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.metrics = sorted
      self.lastUpdated = Date()
      self.lastError = nil
      if !self.isPaused {
        self.status = .running
      }
    }
  }

  private func updateError(_ message: String) {
    var combinedMessage = message
    if let sysmon, let cString = sysmon_last_error(sysmon) {
      let details = String(cString: cString)
      if !details.isEmpty {
        combinedMessage = "\(message) • \(details)"
      }
    }

    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.lastError = combinedMessage
      self.status = .error
    }
  }

  private func resolveIniPath() -> String? {
    let envPath = ProcessInfo.processInfo.environment["SYSMON_INI_PATH"]
    if let envPath, FileManager.default.fileExists(atPath: envPath) {
      return envPath
    }

    #if SWIFT_PACKAGE
    if let bundled = Bundle.module.url(forResource: "sysmon", withExtension: "ini") {
      return bundled.path
    }
    #else
    if let bundled = Bundle.main.url(forResource: "sysmon", withExtension: "ini") {
      return bundled.path
    }
    #endif

    let localPath = "sysmon.ini"
    if FileManager.default.fileExists(atPath: localPath) {
      return localPath
    }

    return nil
  }

  private func describeResult(_ result: sysmon_result_t) -> String {
    switch result {
    case SYSMON_OK:
      return "OK"
    case SYSMON_ERR_INVALID_ARGUMENT:
      return "Invalid argument"
    case SYSMON_ERR_IO:
      return "I/O error"
    case SYSMON_ERR_PARSE:
      return "Parse error"
    case SYSMON_ERR_NOT_SUPPORTED:
      return "Not supported"
    case SYSMON_ERR_OUT_OF_MEMORY:
      return "Out of memory"
    case SYSMON_ERR_INTERNAL:
      return "Internal error"
    default:
      return "Unknown error"
    }
  }
}
