// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "SystemMonitorUI",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "SystemMonitorUI", targets: ["SystemMonitorUI"])
  ],
  targets: [
    .target(
      name: "CSysmon",
      path: "Sources/CSysmon",
      publicHeadersPath: "."
    ),
    .executableTarget(
      name: "SystemMonitorUI",
      dependencies: ["CSysmon"],
      path: "Sources/SystemMonitorUI",
      resources: [
        .copy("Resources/sysmon.ini")
      ],
      linkerSettings: [
        .unsafeFlags(["-L", "vendor/sysmon/sysmon", "-lsysmon"], .when(platforms: [.macOS]))
      ]
    )
  ]
)
