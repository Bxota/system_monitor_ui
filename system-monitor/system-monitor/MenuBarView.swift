import SwiftUI

// ---------------------------------------------------------------------------
// MenuBarView — popover compact affiché au clic sur l'icône dans la top bar
// ---------------------------------------------------------------------------

struct MenuBarView: View {
  @EnvironmentObject private var service: SysmonService

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      metricsGrid
      Divider()
      footer
    }
    .frame(width: 280)
  }

  // MARK: – Header

  private var header: some View {
    HStack(spacing: 10) {
      Image(systemName: "cpu")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color.accentColor)
        .frame(width: 28, height: 28)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

      VStack(alignment: .leading, spacing: 1) {
        Text("System Monitor")
          .font(.subheadline.weight(.semibold))
        Text(service.status == .running ? "En direct" : service.status.rawValue.capitalized)
          .font(.caption)
          .foregroundStyle(statusColor)
      }

      Spacer()

      // Pulsing dot
      Circle()
        .fill(statusColor)
        .frame(width: 7, height: 7)
        .overlay {
          if service.status == .running {
            Circle()
              .stroke(statusColor.opacity(0.4), lineWidth: 2)
              .scaleEffect(1.6)
              .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: service.status)
          }
        }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
  }

  // MARK: – Metrics grid

  private var metricsGrid: some View {
    VStack(spacing: 0) {
      ForEach(featuredMetrics, id: \.name) { metric in
        MenuBarMetricRow(metric: metric)
        if metric.name != featuredMetrics.last?.name {
          Divider().padding(.leading, 14)
        }
      }
    }
  }

  // Pick the most interesting metrics for the compact view
  private var featuredMetrics: [Metric] {
    let priorities = ["cpu.usage_percent", "ram.used_percent", "battery.percent",
                      "storage.used_percent", "network.rx_bytes_per_sec", "network.tx_bytes_per_sec"]
    var result: [Metric] = []
    for name in priorities {
      if let m = service.metrics.first(where: { $0.name == name }) {
        result.append(m)
        if result.count == 5 { break }
      }
    }
    // If not enough named hits, fill with whatever we have
    if result.count < 4 {
      let extras = service.metrics.filter { m in !result.contains(where: { $0.name == m.name }) }
      result.append(contentsOf: extras.prefix(4 - result.count))
    }
    return result
  }

  private var statusColor: Color {
    switch service.status {
    case .running: return .green
    case .paused:  return .orange
    case .error:   return .red
    case .idle:    return .gray
    }
  }

  // MARK: – Footer

  private var footer: some View {
    HStack {
      if let updated = service.lastUpdated {
        Text("Mis à jour " + RelativeDateTimeFormatter().localizedString(for: updated, relativeTo: Date()))
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      Spacer()
      Button {
        service.togglePause()
      } label: {
        Image(systemName: service.isPaused ? "play.fill" : "pause.fill")
          .font(.caption)
      }
      .buttonStyle(.plain)
      .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
  }
}

// MARK: – Metric row for menu bar

private struct MenuBarMetricRow: View {
  let metric: Metric

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: metric.iconName)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(categoryColor)
        .frame(width: 22, alignment: .center)

      Text(metric.displayName.capitalized)
        .font(.callout)
        .lineLimit(1)

      Spacer()

      if let gauge = metric.gaugeValue {
        // Compact progress bar
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Capsule().fill(Color.primary.opacity(0.08)).frame(height: 5)
            Capsule()
              .fill(barGradient(gauge))
              .frame(width: max(4, geo.size.width * gauge / 100), height: 5)
          }
        }
        .frame(width: 64, height: 5)
      }

      Text(metric.displayValue)
        .font(.callout.monospacedDigit().weight(.medium))
        .foregroundStyle(.primary)
        .frame(minWidth: 52, alignment: .trailing)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
  }

  private var categoryColor: Color {
    switch metric.category.lowercased() {
    case "cpu":            return .blue
    case "memory", "ram": return .purple
    case "battery":        return .green
    case "network", "net": return .teal
    case "disk","storage": return .orange
    default:               return Color.accentColor
    }
  }

  private func barGradient(_ value: Double) -> AnyShapeStyle {
    let color: Color = value > 85 ? .red : value > 65 ? .orange : categoryColor
    return AnyShapeStyle(color.gradient)
  }
}

// MARK: – Menu bar label (shown inline in the macOS menu bar)
// Affichage configurable via Préférences → Barre de menu.

struct MenuBarLabel: View {
  @ObservedObject var service: SysmonService
  @AppStorage(kMenuBarMetricKey) private var metricKey: String = "status"

  var body: some View {
    HStack(spacing: 3) {
      if metricKey == "status" {
        // Mode par défaut : icône colorée selon l'état du service
        Image(systemName: "cpu")
          .foregroundStyle(statusColor)
      } else {
        // Mode métrique : icône + valeur en direct
        Image(systemName: iconForKey(metricKey))
        if let metric = service.metrics.first(where: { $0.name == metricKey }) {
          Text(metric.displayValue)
            .font(.system(size: 11, design: .monospaced))
            .monospacedDigit()
        }
      }
    }
  }

  private var statusColor: Color {
    switch service.status {
    case .running: return .green
    case .paused:  return .orange
    case .error:   return .red
    case .idle:    return .primary   // couleur système par défaut
    }
  }

  private func iconForKey(_ key: String) -> String {
    if key.contains("cpu")                              { return "cpu" }
    if key.contains("ram") || key.contains("memory")   { return "memorychip" }
    if key.contains("battery")                         { return "battery.100" }
    if key.contains("storage") || key.contains("disk") { return "internaldrive" }
    if key.contains("network")                         { return "network" }
    return "chart.bar"
  }
}
