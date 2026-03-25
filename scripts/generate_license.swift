#!/usr/bin/env swift
// =============================================================================
// generate_license.swift — Génère des licences signées P256 pour System Monitor
//
// UTILISATION :
//   swift scripts/generate_license.swift setup              → 1ère fois, crée la clé privée
//   swift scripts/generate_license.swift thomas@example.com → génère une licence
//   swift scripts/generate_license.swift --pubkey           → affiche la clé publique
//
// PRÉREQUIS (1 fois) :
//   swift scripts/generate_license.swift setup
//   → sauvegarde ~/.sysmon_private.key (chmod 600, ne jamais versionner)
// =============================================================================

import Foundation
import CryptoKit

// MARK: – Chemin de la clé privée

let privateKeyPath = (NSHomeDirectory() as NSString).appendingPathComponent(".sysmon_private.key")

// MARK: – Helpers

func loadPrivateKey() -> P256.Signing.PrivateKey? {
    guard let b64 = try? String(contentsOfFile: privateKeyPath, encoding: .utf8)
                          .trimmingCharacters(in: .whitespacesAndNewlines),
          let data = Data(base64Encoded: b64),
          let key  = try? P256.Signing.PrivateKey(rawRepresentation: data) else {
        return nil
    }
    return key
}

func generateAndSaveKeyPair() {
    let key     = P256.Signing.PrivateKey()
    let privB64 = key.rawRepresentation.base64EncodedString()
    let pubB64  = key.publicKey.rawRepresentation.base64EncodedString()

    do {
        try privB64.write(toFile: privateKeyPath, atomically: true, encoding: .utf8)
        // chmod 600
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: privateKeyPath)
    } catch {
        print("❌ Impossible d'écrire \(privateKeyPath): \(error)")
        exit(1)
    }

    print("""
    ✅ Paire de clés P256 générée avec succès !

    Clé privée sauvegardée dans : \(privateKeyPath)
    ⚠️  Ne jamais versionner ce fichier (ajoutez-le à .gitignore)

    ──────────────────────────────────────────────────────────────────
    Clé PUBLIQUE (à coller dans LicenseManager.swift) :
    \(pubB64)
    ──────────────────────────────────────────────────────────────────

    Dans LicenseManager.swift, remplacez la valeur de `publicKeyBase64` :
        static let publicKeyBase64 = "\(pubB64)"
    """)
}

func signLicense(identifier: String, with key: P256.Signing.PrivateKey) -> String {
    guard let payload = identifier.data(using: .utf8),
          let sig     = try? key.signature(for: payload) else {
        print("❌ Erreur lors de la signature")
        exit(1)
    }
    let sigB64 = sig.rawRepresentation.base64EncodedString()
    return "\(identifier):\(sigB64)"
}

// MARK: – Main

let args = CommandLine.arguments.dropFirst()  // ignore le nom du script

guard let command = args.first else {
    print("""
    Usage :
      swift scripts/generate_license.swift setup                → génère la paire de clés
      swift scripts/generate_license.swift thomas@example.com   → crée une licence
      swift scripts/generate_license.swift --pubkey             → affiche la clé publique
    """)
    exit(0)
}

switch command {

case "setup":
    if FileManager.default.fileExists(atPath: privateKeyPath) {
        print("⚠️  Une clé privée existe déjà à \(privateKeyPath)")
        print("    Supprimez-la manuellement avant de regénérer (attention : invalide les licences existantes).")
        exit(1)
    }
    generateAndSaveKeyPair()

case "--pubkey":
    guard let key = loadPrivateKey() else {
        print("❌ Clé privée introuvable. Lancez d'abord : swift scripts/generate_license.swift setup")
        exit(1)
    }
    print(key.publicKey.rawRepresentation.base64EncodedString())

default:
    // L'argument est l'identifiant à signer (email ou autre)
    let identifier = command

    guard let key = loadPrivateKey() else {
        print("❌ Clé privée introuvable à \(privateKeyPath)")
        print("   Lancez d'abord : swift scripts/generate_license.swift setup")
        exit(1)
    }

    let licenseKey = signLicense(identifier: identifier, with: key)

    print("""
    ✅ Licence générée pour : \(identifier)

    ──────────────────────────────────────────────────────────────────
    \(licenseKey)
    ──────────────────────────────────────────────────────────────────

    Envoyez cette clé à l'utilisateur. Elle s'active dans :
    System Monitor → Préférences → Licence
    """)
}
