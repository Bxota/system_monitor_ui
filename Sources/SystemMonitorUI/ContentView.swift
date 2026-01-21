import SwiftUI

struct ContentView: View {
  @StateObject private var service = SysmonService()
  @State private var selectedCategory = "All"
  @State private var searchText = ""

  private let gridColumns = [
    GridItem(.adaptive(minimum: 240), spacing: 16)
  ]

  var body: some View {
    NavigationSplitView {
      List {
        SidebarRow(
          title: "All Metrics",
          systemImage: "list.bullet",
          isSelected: selectedCategory == "All"
        ) {
          selectedCategory = "All"
        }

        if !categories.isEmpty {
          Section("Categories") {
            ForEach(categories, id: \.self) { category in
              SidebarRow(
                title: category,
                systemImage: iconName(for: category),
                isSelected: selectedCategory == category
              ) {
                selectedCategory = category
              }
            }
          }
        }
      }
      .listStyle(.sidebar)
      .navigationTitle("System Monitor")
    } detail: {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          headerView

          if let error = service.lastError {
            ErrorBanner(message: error)
          }

          if filteredMetrics.isEmpty {
            EmptyStateView(
              title: "No metrics",
              message: "Waiting for the first snapshot or adjust your filters.",
              systemImage: "waveform.path.ecg"
            )
            .frame(maxWidth: .infinity, minHeight: 300)
          } else {
            LazyVGrid(columns: gridColumns, spacing: 16) {
              ForEach(filteredMetrics) { metric in
                MetricCard(metric: metric)
              }
            }
          }
        }
        .padding(24)
      }
    }
    .searchable(text: $searchText, prompt: "Search metrics")
    .toolbar {
      ToolbarItemGroup {
        Button {
          service.refreshNow()
        } label: {
          Label("Refresh", systemImage: "arrow.clockwise")
        }

        Button {
          service.togglePause()
        } label: {
          Label(service.isPaused ? "Resume" : "Pause", systemImage: service.isPaused ? "play.fill" : "pause.fill")
        }
      }
    }
    .onAppear {
      service.start()
    }
    .onDisappear {
      service.stop()
    }
  }

  private var categories: [String] {
    let set = Set(service.metrics.map { $0.category })
    return set.sorted()
  }

  private var filteredMetrics: [Metric] {
    let filteredByCategory = service.metrics.filter { metric in
      if selectedCategory == "All" { return true }
      return metric.category == selectedCategory
    }

    guard !searchText.isEmpty else { return filteredByCategory }
    return filteredByCategory.filter { metric in
      metric.displayName.localizedCaseInsensitiveContains(searchText) ||
        metric.name.localizedCaseInsensitiveContains(searchText)
    }
  }

  private var headerView: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("System Monitor")
          .font(.largeTitle.weight(.bold))

        Text("\(service.metrics.count) metrics • Refresh every \(service.intervalMs) ms")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      Spacer()

      StatusBadge(status: service.status, lastUpdated: service.lastUpdated)
    }
  }

  private func iconName(for category: String) -> String {
    switch category.lowercased() {
    case "cpu":
      return "cpu"
    case "memory", "ram":
      return "memorychip"
    case "disk", "storage":
      return "internaldrive"
    case "network", "net":
      return "network"
    case "temperature", "thermal", "sensors":
      return "thermometer"
    case "battery", "power":
      return "battery.100"
    case "fan", "cooling":
      return "fanblades"
    default:
      return "waveform.path.ecg"
    }
  }
}

private struct StatusBadge: View {
  let status: SysmonService.Status
  let lastUpdated: Date?

  var body: some View {
    VStack(alignment: .trailing, spacing: 6) {
      HStack(spacing: 8) {
        Circle()
          .fill(statusColor)
          .frame(width: 8, height: 8)
        Text(statusLabel)
          .font(.callout.weight(.semibold))
      }

      if let lastUpdated {
        Text(relativeDate(from: lastUpdated))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
  }

  private var statusLabel: String {
    switch status {
    case .idle:
      return "Idle"
    case .running:
      return "Live"
    case .paused:
      return "Paused"
    case .error:
      return "Error"
    }
  }

  private var statusColor: Color {
    switch status {
    case .idle:
      return .gray
    case .running:
      return .green
    case .paused:
      return .orange
    case .error:
      return .red
    }
  }

  private func relativeDate(from date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

private struct ErrorBanner: View {
  let message: String

  var body: some View {
    Label(message, systemImage: "exclamationmark.triangle.fill")
      .font(.callout)
      .foregroundStyle(.red)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(Color.red.opacity(0.2))
      )
  }
}

private struct SidebarRow: View {
  let title: String
  let systemImage: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
    .buttonStyle(.plain)
    .listRowBackground(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
    )
  }
}

private struct EmptyStateView: View {
  let title: String
  let message: String
  let systemImage: String

  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 36, weight: .semibold))
        .foregroundStyle(.secondary)

      Text(title)
        .font(.title3.weight(.semibold))

      Text(message)
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 320)
    }
    .padding(24)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

private struct MetricCard: View {
  let metric: Metric

  var body: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 10) {
        if let gaugeValue = metric.gaugeValue {
          Gauge(value: gaugeValue, in: 0...100) {
            Text("Usage")
          } currentValueLabel: {
            Text(metric.displayValue)
              .font(.headline)
          }
          .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
          .gaugeStyle(.accessoryCircularCapacity)
        } else {
          Text(metric.displayValue)
            .font(.title2.weight(.semibold))
        }

        Text(metric.name)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } label: {
      Label(metric.displayName, systemImage: metric.iconName)
    }
    .groupBoxStyle(MetricCardStyle())
  }
}

private struct MetricCardStyle: GroupBoxStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      configuration.label
        .font(.headline)
      configuration.content
    }
    .padding(12)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .stroke(.quaternary)
    )
  }
}
