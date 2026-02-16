# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Net Bar is a macOS menu bar application for real-time system and network monitoring. Built with Swift/SwiftUI + Objective-C++ (for low-level network stats). Requires macOS 14.0 (Sonoma) or later.

## Build & Run

```bash
# Build (uses Swift Package Manager)
swift build -c release

# Build + install to /Applications (existing install_app.sh)
swift build -c release && bash install_app.sh

# Manual install after build
BIN_PATH=$(swift build -c release --show-bin-path)
rm -rf "NetBar.app"
mkdir -p "NetBar.app/Contents/MacOS" "NetBar.app/Contents/Resources"
cp "$BIN_PATH/NetBar" "NetBar.app/Contents/MacOS/NetBar"
cp Sources/NetSpeedMonitor/Info.plist "NetBar.app/Contents/Info.plist"
cp Sources/NetSpeedMonitor/Resources/AppIcon.icns "NetBar.app/Contents/Resources/AppIcon.icns"
cp -r Sources/NetSpeedMonitor/Assets.xcassets "NetBar.app/Contents/Resources/"
mv "NetBar.app" /Applications/

# Clear Gatekeeper quarantine (unsigned app)
xattr -rd com.apple.quarantine /Applications/NetBar.app
```

There are no tests in this project.

## Architecture

**SPM targets** (Package.swift):
- `NetSpeedMonitor` — main executable (Swift/SwiftUI), produces the `NetBar` binary
- `NetTrafficStat` — C++/ObjC++ library for reading network interface byte counters via `sysctl`

**External dependency:** `LaunchAtLogin` v5.0.0+ (start-at-login toggle)

### State & Services Layer

- **MenuBarState** — central observable state for network speeds, display settings, and traffic history. Polls `NetTrafficStatReceiver` (C++/ObjC bridge) every 1 second.
- **NetworkStatsService** — Wi-Fi details (CoreWLAN), ping tests to DNS/router/1.1.1.1 with ICMP→TCP fallback, jitter calculation.
- **SystemStatsService** — CPU, memory, disk, battery, thermal monitoring via `host_cpu_load_info`, `vm_statistics64`, IOKit.
- **SpeedTestService** — wraps the system `networkQuality` CLI tool with async execution and output parsing.
- **OrderManager** — persists drag-and-drop section order via UserDefaults (JSON).

### UI Layer

- **NetSpeedMonitorApp** — app entry point, creates MenuBarExtra scene + Settings window.
- **DetailedStatusView** — main popover showing all diagnostics sections (reorderable, toggleable).
- **SettingsView** — configuration: section visibility/order, typography, display mode, units, updates.
- **MenuContentView** — context menu (launch at login, open Activity Monitor, quit).
- **StatGraphView** — reusable Charts-based area graph (60-second history buffer).
- **MenuBarIconGenerator** — renders dynamic text icon for the menu bar.

### Data Flow

All services are `ObservableObject` with `@Published` properties. Views observe via `@EnvironmentObject`. Everything updates on a 1-second timer cycle. Settings are persisted in `UserDefaults`.

### System Utilities Invoked at Runtime

`/sbin/ping`, `/usr/bin/nc`, `/sbin/route`, `/usr/sbin/scutil`, `/usr/bin/networkQuality`
