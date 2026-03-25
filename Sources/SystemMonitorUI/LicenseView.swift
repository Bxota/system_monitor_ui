import SwiftUI

// ---------------------------------------------------------------------------
// LicenseView — activation / gestion de la licence Pro
// ---------------------------------------------------------------------------

struct LicenseView: View {
  @EnvironmentObject private var licenseManager: LicenseManager

  var body: some View {
    ScrollView {
      VStack(spacing: 0) {
        if licenseManager.isActivated {
          ActivatedView()
        } else {
          ActivationView()
        }
      }
      .frame(maxWidth: 560)
      .padding(32)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

// MARK: – Activated state

private struct ActivatedView: View {
  @EnvironmentObject private var licenseManager: LicenseManager

  var body: some View {
    VStack(spacing: 28) {
      // Hero
      ZStack {
        Circle()
          .fill(Color.green.opacity(0.12))
          .frame(width: 80, height: 80)
        Image(systemName: "checkmark.seal.fill")
          .font(.system(size: 36))
          .foregroundStyle(.green)
      }

      VStack(spacing: 8) {
        Text("System Monitor Pro")
          .font(.title.weight(.bold))
        Text("Votre licence est active — profitez de toutes les fonctionnalités.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      // Licence pill
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Label("Activée pour", systemImage: "person.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Spacer()
          Label("Signature vérifiée", systemImage: "checkmark.shield.fill")
            .font(.caption2)
            .foregroundStyle(.green)
        }
        Text(licenseManager.licensedTo)
          .font(.system(.callout, design: .monospaced).weight(.medium))
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
      }
      .padding(18)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.quaternary))

      // Features list
      ProFeaturesList()

      Divider()

      Button(role: .destructive) {
        licenseManager.deactivate()
      } label: {
        Label("Désactiver la licence", systemImage: "trash")
          .font(.callout.weight(.medium))
      }
      .buttonStyle(.plain)
      .foregroundStyle(.red)
    }
  }
}

// MARK: – Activation form

private struct ActivationView: View {
  @EnvironmentObject private var licenseManager: LicenseManager

  @State private var inputKey    = ""
  @State private var errorMsg: String? = nil
  @State private var isShaking   = false

  var body: some View {
    VStack(spacing: 28) {
      // Hero
      ZStack {
        Circle()
          .fill(Color.accentColor.opacity(0.12))
          .frame(width: 80, height: 80)
        Image(systemName: "lock.shield.fill")
          .font(.system(size: 36))
          .foregroundStyle(Color.accentColor)
      }

      VStack(spacing: 8) {
        Text("System Monitor Pro")
          .font(.title.weight(.bold))
        Text("Débloquez les fonctionnalités avancées avec une clé de licence.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      // Features list
      ProFeaturesList()

      Divider()

      // Input
      VStack(alignment: .leading, spacing: 10) {
        Label("Clé de licence", systemImage: "key.fill")
          .font(.subheadline.weight(.semibold))

        HStack(spacing: 10) {
          TextField("email@example.com:MEUCIQDh…", text: $inputKey)
            .font(.system(.body, design: .monospaced))
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .onSubmit { tryActivate() }

          Button("Activer", action: tryActivate)
            .buttonStyle(.borderedProminent)
            .disabled(inputKey.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .modifier(ShakeModifier(trigger: isShaking))

        if let err = errorMsg {
          Label(err, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .padding(18)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.quaternary))
      .animation(.easeInOut(duration: 0.2), value: errorMsg)

      // Demo hint
      VStack(spacing: 4) {
        Text("Clé de démonstration :")
          .font(.caption)
          .foregroundStyle(.tertiary)
        Button {
          inputKey = "demo@sysmon.app:ANlxnzC2g7qzutOUsBeDtGkORF+mvNq9c6Va2cjSH/I8gGvHZ/lxrIExEFdHs70Vcwrc5pDU7odf7K315Kn/fQ=="
        } label: {
          Text("demo@sysmon.app (cliquer pour remplir)")
            .font(.caption)
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
      }
    }
  }

  private func tryActivate() {
    withAnimation { errorMsg = nil }
    if licenseManager.activate(key: inputKey) {
      inputKey = ""
    } else {
      withAnimation { errorMsg = "Clé invalide — vérifiez le format et réessayez." }
      isShaking.toggle()
    }
  }
}

// MARK: – Shared components

private struct ProFeaturesList: View {
  private let features: [(String, String, Color)] = [
    ("externaldrive.fill",     "Disk Visualizer",     .indigo),
    ("chart.bar.fill",         "Statistiques Pro",    .blue),
    ("bell.badge.fill",        "Alertes système",     .orange),
    ("arrow.up.right.circle.fill", "Accès prioritaire", .green),
  ]

  var body: some View {
    VStack(spacing: 0) {
      ForEach(features, id: \.0) { icon, title, color in
        HStack(spacing: 14) {
          Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

          Text(title)
            .font(.callout)

          Spacer()

          Image(systemName: "checkmark")
            .font(.caption.weight(.bold))
            .foregroundStyle(.green)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)

        if title != features.last?.1 {
          Divider().padding(.leading, 64)
        }
      }
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.quaternary))
  }
}

// MARK: – Shake animation (compatible macOS 13)

private struct ShakeModifier: ViewModifier {
  let trigger: Bool
  @State private var shakeCount: Int = 0

  func body(content: Content) -> some View {
    content
      .modifier(ShakeEffect(shakes: shakeCount))
      .onChange(of: trigger) { _ in
        withAnimation(.easeOut(duration: 0.4)) { shakeCount += 1 }
      }
  }
}

/// GeometryEffect qui produit une oscillation décroissante (shake).
private struct ShakeEffect: GeometryEffect {
  var shakes: Int

  var animatableData: CGFloat {
    get { CGFloat(shakes) }
    set { shakes = Int(newValue) }
  }

  func effectValue(size: CGSize) -> ProjectionTransform {
    let phase     = CGFloat(shakes).truncatingRemainder(dividingBy: 1)
    let amplitude = 8.0 * sin(phase * .pi * 6) * max(0, 1 - phase)
    return ProjectionTransform(CGAffineTransform(translationX: amplitude, y: 0))
  }
}
