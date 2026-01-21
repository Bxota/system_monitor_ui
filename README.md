# System monitoring UI

## Download core library
`sudo CORE_REPO=Bxota/system_monitor_core ./scripts/fetch_libsysmon.sh`

Notes:
- By default on macOS, the script ensures `libsysmon.a` contains both `arm64` and `x86_64`.
- To override architectures, set `ARCHS` (example: `ARCHS="x86_64"`).
- To always build from source instead of downloading the release asset, set `FORCE_BUILD_FROM_SOURCE=1`.
- If `vendor/sysmon` is owned by root, run the script with `sudo` or set `SUDO_CMD=sudo`.
