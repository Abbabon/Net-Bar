# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Net Bar is a macOS menu bar application for real-time system and network monitoring. Built with Swift/SwiftUI + Objective-C++ (for low-level network stats). Requires macOS 14.0 (Sonoma) or later.

## Branching

- **`develop`** — default branch; local working branch for all development
- **`main`** — tracks upstream (iad1tya/Net-Bar); PRs to upstream are proposed from feature branches off main

## Build & Run

```bash
# Build (uses Swift Package Manager)
swift build -c release

# Build + install to /Applications
bash build_and_install.sh
```

There are no tests in this project.

## Architecture

**SPM targets** (Package.swift):
- `NetSpeedMonitor` — main executable (Swift/SwiftUI), produces the `NetBar` binary
- `NetTrafficStat` — C++/ObjC++ library for reading network interface byte counters via `sysctl`

**External dependency:** `LaunchAtLogin` v5.0.0+ (start-at-login toggle)

### State & Services Layer

- **MenuBarState** — central observable state for network speeds, display settings, traffic history, and pin-to-menu-bar toggles. Polls `NetTrafficStatReceiver` (C++/ObjC bridge) every 1 second. Assembles the menu bar text from all pinned stats (speed, RSSI, ping, CPU, RAM, etc.) joined by `" | "`.
- **NetworkStatsService** — singleton (`shared`). Wi-Fi details (CoreWLAN), ping tests to DNS/router/1.1.1.1 with ICMP→TCP fallback, jitter calculation. Polls every 3 seconds. No location permissions required.
- **SystemStatsService** — CPU, memory, disk, battery, thermal monitoring via `host_cpu_load_info`, `vm_statistics64`, IOKit.
- **SpeedTestService** — wraps the system `networkQuality` CLI tool with async execution and output parsing.
- **OrderManager** — persists drag-and-drop section order via UserDefaults (JSON).

### UI Layer

- **NetSpeedMonitorApp** — app entry point, creates MenuBarExtra scene + Settings window.
- **DetailedStatusView** — main popover showing all diagnostics sections (reorderable, toggleable). Each section header has a pin button to pin that stat to the menu bar.
- **SettingsView** — configuration: section visibility/order, typography, display mode, units, pin-to-menu-bar toggles, updates.
- **MenuContentView** — context menu (launch at login, open Activity Monitor, quit).
- **StatGraphView** — reusable Charts-based area graph (60-second history buffer).
- **MenuBarIconGenerator** — renders dynamic text icon for the menu bar.

### Pin-to-Menu-Bar System

Any section can be pinned to the menu bar via its header pin button or through Settings toggles. Pinned stats are `@AppStorage` bools (e.g. `showSpeedMenu`, `showCPUMenu`, `showRSSIMenu`). `MenuBarState.startTimer()` collects all enabled pins into a `statsList` array joined by `" | "`. Network speed (`showSpeedMenu`) is pinned by default. When nothing is pinned, the classic stacked speed display is used as fallback.

### Data Flow

All services are `ObservableObject` with `@Published` properties. Views observe via `@EnvironmentObject`. Network speed updates on a 1-second timer; network stats (Wi-Fi, ping) poll every 3 seconds. Settings are persisted in `UserDefaults`.

### System Utilities Invoked at Runtime

`/sbin/ping`, `/usr/bin/nc`, `/sbin/route`, `/usr/sbin/scutil`, `/usr/bin/networkQuality`
