import Foundation
import CSysmon

struct Metric: Identifiable, Hashable {
  enum Value: Hashable {
    case double(Double)
    case int64(Int64)
    case uint64(UInt64)
    case string(String)
  }

  let id = UUID()
  let name: String
  let unit: String?
  let value: Value

  init(cMetric: sysmon_metric_t) {
    if cMetric.name != nil {
      name = String(cString: cMetric.name)
    } else {
      name = "unknown"
    }

    if cMetric.unit != nil {
      let unitValue = String(cString: cMetric.unit)
      unit = unitValue.isEmpty ? nil : unitValue
    } else {
      unit = nil
    }

    switch cMetric.type {
    case SYSMON_METRIC_DOUBLE:
      value = .double(cMetric.value.f64)
    case SYSMON_METRIC_INT64:
      value = .int64(cMetric.value.i64)
    case SYSMON_METRIC_UINT64:
      value = .uint64(cMetric.value.u64)
    case SYSMON_METRIC_STRING:
      if cMetric.value.str != nil {
        value = .string(String(cString: cMetric.value.str))
      } else {
        value = .string("-")
      }
    default:
      value = .string("-")
    }
  }

  var category: String {
    let segment = nameSegments.first.map { String($0) } ?? "Other"
    return segment.capitalized
  }

  var shortName: String {
    let tail = nameSegments.dropFirst()
    guard !tail.isEmpty else { return name }
    return tail.map { String($0) }.joined(separator: " ")
  }

  var displayName: String {
    shortName.replacingOccurrences(of: "_", with: " ")
  }

  var displayValue: String {
    switch value {
    case .string(let text):
      return text
    case .double(let number):
      return formatNumber(number)
    case .int64(let number):
      return formatInteger(Int64(number))
    case .uint64(let number):
      return formatUnsigned(number)
    }
  }

  var numericValue: Double? {
    switch value {
    case .double(let number):
      return number
    case .int64(let number):
      return Double(number)
    case .uint64(let number):
      return Double(number)
    case .string:
      return nil
    }
  }

  var gaugeValue: Double? {
    guard isPercentLike, let numeric = numericValue else { return nil }
    let percent = numeric <= 1.0 ? numeric * 100.0 : numeric
    return min(max(percent, 0), 100)
  }

  var iconName: String {
    let lower = name.lowercased()
    if lower.contains("cpu") {
      return "cpu"
    }
    if lower.contains("memory") || lower.contains("ram") {
      return "memorychip"
    }
    if lower.contains("disk") || lower.contains("storage") {
      return "internaldrive"
    }
    if lower.contains("net") || lower.contains("wifi") {
      return "network"
    }
    if lower.contains("temp") || lower.contains("thermal") {
      return "thermometer"
    }
    if lower.contains("battery") {
      return "battery.100"
    }
    if lower.contains("fan") {
      return "fanblades"
    }
    return "waveform.path.ecg"
  }

  private var nameSegments: [Substring] {
    name.split(whereSeparator: { $0 == "." || $0 == "/" || $0 == ":" })
  }

  private var isPercentLike: Bool {
    if let unit, unit == "%" { return true }
    let lower = name.lowercased()
    return lower.contains("percent") || lower.contains("usage") || lower.contains("util")
  }

  private var isBytesUnit: Bool {
    guard let unit else { return false }
    let lower = unit.lowercased()
    return lower == "b" || lower.contains("byte")
  }

  private func formatNumber(_ number: Double) -> String {
    if isBytesUnit {
      return Metric.byteFormatter.string(fromByteCount: Int64(number))
    }

    if isPercentLike {
      let value = number <= 1.0 ? number * 100.0 : number
      let formatted = Metric.numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
      return "\(formatted)%"
    }

    let formatted = Metric.numberFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    if let unit, !unit.isEmpty {
      return "\(formatted) \(unit)"
    }
    return formatted
  }

  private func formatInteger(_ number: Int64) -> String {
    if isBytesUnit {
      return Metric.byteFormatter.string(fromByteCount: number)
    }

    let formatted = Metric.integerFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    if let unit, !unit.isEmpty {
      return "\(formatted) \(unit)"
    }
    return formatted
  }

  private func formatUnsigned(_ number: UInt64) -> String {
    if isBytesUnit, number <= UInt64(Int64.max) {
      return Metric.byteFormatter.string(fromByteCount: Int64(number))
    }

    let formatted = Metric.integerFormatter.string(from: NSNumber(value: number)) ?? "\(number)"
    if let unit, !unit.isEmpty {
      return "\(formatted) \(unit)"
    }
    return formatted
  }

  private static let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 0
    return formatter
  }()

  private static let integerFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    return formatter
  }()

  private static let byteFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useAll]
    formatter.countStyle = .memory
    return formatter
  }()
}
