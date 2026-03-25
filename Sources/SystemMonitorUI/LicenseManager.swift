import Foundation
import CryptoKit

// ---------------------------------------------------------------------------
// LicenseManager — validation par signature asymétrique P256 (ECDSA-SHA256)
//
// Format de clé : "identifier:base64(signature_raw_64_bytes)"
//   ex. : "thomas@example.com:ANlxnzC2g7qzutOU..."
//
// La clé PRIVÉE n'est jamais dans l'app.
// La clé PUBLIQUE est embarquée ci-dessous — elle ne permet que de vérifier,
// pas de forger de nouvelles licences.
//
// Pour générer des licences : voir scripts/generate_license.swift
// ---------------------------------------------------------------------------

final class LicenseManager: ObservableObject {

  // Clé publique P256 raw (64 bytes, x||y, base64)
  // ⚠️  Si vous regénérez la paire de clés, mettez à jour cette valeur
  //     ET redistribuez l'app — les anciennes licences ne fonctionneront plus.
  static let publicKeyBase64 =
    "NgPdRz3b8btzpq9s3qYaFjnrqedyg//S/WxRbWrqkQY3kFfsfhxVL1F3FqEReQBVPhU/2wayPo7PnEbj5Be0xQ=="

  @Published private(set) var isActivated: Bool   = false
  @Published private(set) var licenseKey : String = ""
  @Published private(set) var licensedTo : String = ""  // l'identifiant signé (ex. email)

  private let defaults            = UserDefaults.standard
  private let keyStorageKey       = "com.sysmon.ui.licenseKey.v2"
  private let activatedStorageKey = "com.sysmon.ui.isActivated.v2"

  init() { loadStored() }

  // MARK: – Public API

  /// Vérifie qu'une clé est cryptographiquement valide.
  func validate(key: String) -> Bool {
    let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)

    // Découpe sur le DERNIER ":" pour tolérer des emails qui contiennent ":"
    guard let colonRange = trimmed.range(of: ":", options: .backwards) else { return false }
    let identifier = String(trimmed[..<colonRange.lowerBound])
    let sigB64     = String(trimmed[colonRange.upperBound...])

    guard !identifier.isEmpty,
          !sigB64.isEmpty,
          let sigData = Data(base64Encoded: sigB64),
          sigData.count == 64,                          // raw P256 sig = 64 bytes exactement
          let keyData  = Data(base64Encoded: Self.publicKeyBase64),
          let pubKey   = try? P256.Signing.PublicKey(rawRepresentation: keyData),
          let sig      = try? P256.Signing.ECDSASignature(rawRepresentation: sigData),
          let payload  = identifier.data(using: .utf8)
    else { return false }

    return pubKey.isValidSignature(sig, for: payload)
  }

  /// Active la licence si la signature est valide. Retourne `true` en cas de succès.
  @discardableResult
  func activate(key: String) -> Bool {
    guard validate(key: key) else { return false }
    let trimmed  = key.trimmingCharacters(in: .whitespacesAndNewlines)
    isActivated  = true
    licenseKey   = trimmed
    licensedTo   = extractIdentifier(from: trimmed)
    defaults.set(trimmed, forKey: keyStorageKey)
    defaults.set(true,    forKey: activatedStorageKey)
    return true
  }

  func deactivate() {
    isActivated = false
    licenseKey  = ""
    licensedTo  = ""
    defaults.removeObject(forKey: keyStorageKey)
    defaults.set(false, forKey: activatedStorageKey)
  }

  // MARK: – Private helpers

  private func loadStored() {
    guard let stored = defaults.string(forKey: keyStorageKey),
          defaults.bool(forKey: activatedStorageKey),
          validate(key: stored) else { return }
    isActivated = true
    licenseKey  = stored
    licensedTo  = extractIdentifier(from: stored)
  }

  private func extractIdentifier(from key: String) -> String {
    guard let r = key.range(of: ":", options: .backwards) else { return key }
    return String(key[..<r.lowerBound])
  }
}
