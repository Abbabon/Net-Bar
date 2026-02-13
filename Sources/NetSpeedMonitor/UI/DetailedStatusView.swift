import SwiftUI
import Charts

struct DetailedStatusView: View {
    @StateObject private var statsService = NetworkStatsService()
    @ObservedObject private var systemStatsService = SystemStatsService.shared
    @EnvironmentObject var menuBarState: MenuBarState
    @EnvironmentObject var orderManager: OrderManager
    @Environment(\.openWindow) var openWindow
    
    @State private var uptimeString: String = "00:00:00"
    @State private var contentHeight: CGFloat = 600 // Default start height
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @AppStorage("showTraffic") private var showTraffic = true
    @AppStorage("showConnection") private var showConnection = true
    @AppStorage("showRouter") private var showRouter = true
    @AppStorage("showDNS") private var showDNS = true
    @AppStorage("showInternet") private var showInternet = true
    @AppStorage("showTips") private var showTips = true
    
    @AppStorage("showCPU") private var showCPU = false
    @AppStorage("showMemory") private var showMemory = false
    @AppStorage("showDisk") private var showDisk = false
    @AppStorage("showEnergy") private var showEnergy = false
    @AppStorage("showTemp") private var showTemp = false
    
    var body: some View {
        ScrollView {
            StatusContentView(
                statsService: statsService,
                systemStatsService: systemStatsService,
                menuBarState: menuBarState,
                visibleSections: visibleSections,
                tips: tips,
                showTips: showTips,
                isSnapshot: false,
                onSettingsTap: {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings")
                    // Close the popover by simulating a click outside or resigning focus? 
                    // Actually, opening the window usually stays in front.
                },
                onQuitTap: {
                    NSApp.terminate(nil)
                }
            )
            .padding(16)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: ViewHeightKey.self, value: geometry.size.height)
            })
        }
        .onPreferenceChange(ViewHeightKey.self) { contentHeight = $0 }
        .frame(width: 350)
        .frame(height: min(contentHeight, 600))
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(timer) { input in
             let diff = input.timeIntervalSince(menuBarState.appLaunchDate)
             let hours = Int(diff) / 3600
             let minutes = (Int(diff) % 3600) / 60
             let seconds = Int(diff) % 60
             uptimeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
         }
    }
    
    // Smart Tips Logic
    var tips: [String] {
        var list: [String] = []
        let s = statsService.stats
        let sys = systemStatsService.stats
        
        if showConnection {
            if s.rssi < -75 && s.rssi != 0 { list.append("Weak Wi-Fi signal. Move closer to your router.") }
            if s.txRate < 50 && s.txRate > 0 { list.append("Low link rate. Wi-Fi might be slow.") }
            if s.noise > -85 && s.noise != 0 { list.append("High interference (Noise). Try changing Wi-Fi channel.") }
        }
        
        if showRouter {
            if s.routerLoss > 1.0 { list.append("Packet loss detected to router. Connection unstable.") }
            if s.routerJitter > 50 { list.append("High jitter detected. Calls may be choppy.") }
        }
        
        // Misc Tips (System)
        if showCPU && sys.cpuUsage > 90 { list.append("High CPU usage detected.") }
        if showMemory && sys.memoryUsage > 90 { list.append("Memory usage is critical.") }
        if showDisk && sys.diskUsage > 90 { list.append("Low disk space.") }
        if showTemp && sys.thermalPressure != "Normal" { list.append("Device is running hot (\(sys.thermalPressure)).") }
        if showEnergy && sys.batteryLevel < 20 && !sys.isCharging { list.append("Battery is low.") }
        
        return list
    }
    
    var visibleSections: [String] {
        orderManager.sectionOrder.filter { section in
            switch section {
            case "Traffic": return showTraffic
            case "Connection": return showConnection
            case "Router": return showRouter
            case "DNS": return showDNS
            case "Internet": return showInternet
            case "Processor": return showCPU
            case "Memory": return showMemory
            case "Disk": return showDisk
            case "Battery": return showEnergy
            case "Thermal State": return showTemp
            default: return false
            }
        }
    }
}

// Extracted view for snapshotting
struct StatusContentView: View {
    @ObservedObject var statsService: NetworkStatsService
    @ObservedObject var systemStatsService: SystemStatsService
    @ObservedObject var menuBarState: MenuBarState
    
    let visibleSections: [String]
    let tips: [String]
    let showTips: Bool
    let isSnapshot: Bool
    let onSettingsTap: () -> Void
    let onQuitTap: () -> Void
    
    init(statsService: NetworkStatsService, systemStatsService: SystemStatsService, menuBarState: MenuBarState, visibleSections: [String], tips: [String], showTips: Bool, isSnapshot: Bool = false, onSettingsTap: @escaping () -> Void, onQuitTap: @escaping () -> Void) {
        self.statsService = statsService
        self.systemStatsService = systemStatsService
        self.menuBarState = menuBarState
        self.visibleSections = visibleSections
        self.tips = tips
        self.showTips = showTips
        self.isSnapshot = isSnapshot
        self.onSettingsTap = onSettingsTap
        self.onQuitTap = onQuitTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Net Bar")
                        .font(.headline)
                    Text("Network Diagnostics")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                if !isSnapshot {
                    // Share Button AND Settings Button
                    HStack(spacing: 12) {
                        // Share Button
                        Button(action: shareStats) {
                             Image(systemName: "square.and.arrow.up")
                                 .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Image(systemName: "gearshape")
                            .foregroundStyle(.secondary)
                            .onTapGesture {
                                onSettingsTap()
                            }
                    }
                }
            }
            Divider()
            
            // Usage Header (SSID)
            HStack {
                 Circle()
                     .fill(Color.green)
                     .frame(width: 8, height: 8)
                 Text(statsService.stats.ssid.isEmpty ? "Wi-Fi" : statsService.stats.ssid)
                     .font(.headline)
                 
                 if !statsService.stats.band.isEmpty {
                     Text(statsService.stats.band)
                         .font(.caption)
                         .padding(.horizontal, 6)
                         .padding(.vertical, 2)
                         .background(Color.gray.opacity(0.3))
                         .cornerRadius(4)
                 }
            }
            
            // Traffic Section
            ForEach(Array(visibleSections.enumerated()), id: \.element) { index, section in
                if index > 0 { Divider() }
                sectionView(for: section)
            }
            
            Divider()
            
            // Tips Section
            if showTips && !tips.isEmpty && !isSnapshot {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Tips", systemImage: "lightbulb.fill")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.yellow)
                    
                    ForEach(tips, id: \.self) { tip in
                        Text("• " + tip)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Divider()
            }
            
            if !isSnapshot {
                // Quit Button
                Button(action: onQuitTap) {
                    HStack {
                        Image(systemName: "power")
                        Text("Quit App")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            if isSnapshot {
                HStack(spacing: 6) {
                    Spacer()
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    Text("Net Bar")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }
    
    @MainActor
    func shareStats() {
        guard let image = renderSnapshot() else { return }
        
        let picker = NSSharingServicePicker(items: [image])
        // Find the window to anchor the picker
        if let window = NSApp.windows.first(where: { $0.isKeyWindow }) ?? NSApp.windows.first {
             // Show centered in the window or near the top right
             // Getting the exact button frame is hard without GeometryReader, 
             // but showing it relative to the content view is a reasonable fallback.
            picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
    }
    
    @MainActor
    func renderSnapshot() -> NSImage? {
        let renderer = ImageRenderer(content:
            StatusContentView(
                statsService: statsService,
                systemStatsService: systemStatsService,
                menuBarState: menuBarState,
                visibleSections: ["Traffic", "Connection", "Router", "DNS", "Internet"],
                tips: [],
                showTips: false,
                isSnapshot: true,
                onSettingsTap: {}, // No-op
                onQuitTap: {} // No-op
            )
            .padding(16)
            .frame(width: 350)
            .background(Color(NSColor.windowBackgroundColor))
        )
        renderer.scale = 2.0 // Retinal quality
        
        return renderer.nsImage
    }

    @ViewBuilder
    func sectionView(for section: String) -> some View {
        switch section {
        case "Traffic":
            VStack(alignment: .leading, spacing: 12) {
                 Text("Traffic")
                     .font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                 Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                     GridRow(alignment: .center) {
                         Text("Download").foregroundStyle(.secondary)
                         Text(menuBarState.formatBytes(menuBarState.totalDownload).0 + " " + menuBarState.formatBytes(menuBarState.totalDownload).1)
                             .foregroundStyle(.green).monospacedDigit()
                         StatGraphView(data: menuBarState.downloadHistory, color: .green, minRange: 0, maxRange: 1024 * 1024, height: 16)
                     }
                     GridRow(alignment: .center) {
                         Text("Upload").foregroundStyle(.secondary)
                         Text(menuBarState.formatBytes(menuBarState.totalUpload).0 + " " + menuBarState.formatBytes(menuBarState.totalUpload).1)
                             .foregroundStyle(.blue).monospacedDigit()
                         StatGraphView(data: menuBarState.uploadHistory, color: .blue, minRange: 0, maxRange: 1024 * 1024, height: 16)
                     }
                     GridRow(alignment: .center) {
                          Text("Total").foregroundStyle(.secondary)
                          Text(menuBarState.formatBytes(menuBarState.totalDownload + menuBarState.totalUpload).0 + " " + menuBarState.formatBytes(menuBarState.totalDownload + menuBarState.totalUpload).1)
                              .foregroundStyle(.purple).monospacedDigit()
                          StatGraphView(data: menuBarState.totalTrafficHistory, color: .purple, minRange: 0, maxRange: 1024 * 1024 * 2, height: 16)
                      }
                 }
            }
        case "Connection":
            VStack(alignment: .leading, spacing: 12) {
                Text("Connection").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow(alignment: .center) {
                        Text("Link Rate").foregroundStyle(.secondary)
                        Text("\(Int(statsService.stats.txRate)) Mbps").foregroundStyle(.green).monospacedDigit()
                        StatGraphView(data: Array(repeating: statsService.stats.txRate, count: 20), color: .green, minRange: 0, maxRange: 1000, height: 16)
                    }
                    GridRow(alignment: .center) {
                        Text("Signal").foregroundStyle(.secondary)
                        Text("\(statsService.stats.rssi) dBm").foregroundStyle(.orange).monospacedDigit()
                        StatGraphView(data: statsService.signalHistory.map { Double($0) }, color: .orange, minRange: -100, maxRange: -30, height: 16)
                    }
                    GridRow(alignment: .center) {
                        Text("Noise").foregroundStyle(.secondary)
                        Text("\(statsService.stats.noise) dBm").foregroundStyle(.green).monospacedDigit()
                        StatGraphView(data: statsService.noiseHistory.map { Double($0) }, color: .green, minRange: -110, maxRange: -80, height: 16)
                    }
                }
            }
        case "Router":
            VStack(alignment: .leading, spacing: 12) {
                Text("Router").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow(alignment: .center) {
                        Text("Ping").foregroundStyle(.secondary)
                        Text(statsService.stats.routerLoss == 100 ? "---" : String(format: "%.0f ms", statsService.stats.routerPing)).foregroundStyle(.green).monospacedDigit()
                        StatGraphView(data: statsService.routerPingHistory, color: .green, minRange: 0, maxRange: 100, height: 16)
                    }
                    GridRow(alignment: .center) {
                        Text("Jitter").foregroundStyle(.secondary)
                        Text(String(format: "%.1f ms", statsService.stats.routerJitter)).foregroundStyle(.yellow).monospacedDigit()
                         StatGraphView(data: statsService.routerPingHistory.map { abs($0 - statsService.stats.routerPing) }, color: .yellow, minRange: 0, maxRange: 50, height: 16)
                    }
                }
            }
        case "DNS":
            VStack(alignment: .leading, spacing: 12) {
                Text("DNS Router Assigned").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                     GridRow(alignment: .center) {
                         Text(statsService.stats.dns.isEmpty ? "Unknown" : statsService.stats.dns).foregroundStyle(.secondary)
                         Text(statsService.stats.dnsLoss == 100 ? "---" : String(format: "%.0f ms", statsService.stats.dnsPing)).foregroundStyle(.cyan).monospacedDigit()
                         StatGraphView(data: statsService.dnsPingHistory, color: .cyan, minRange: 0, maxRange: 100, height: 16)
                     }
                      GridRow(alignment: .center) {
                          Text("Jitter").foregroundStyle(.secondary)
                          Text(String(format: "%.1f ms", statsService.stats.dnsJitter)).foregroundStyle(.purple).monospacedDigit()
                          StatGraphView(data: statsService.dnsPingHistory.map { abs($0 - statsService.stats.dnsPing) }, color: .purple, minRange: 0, maxRange: 50, height: 16)
                      }
                 }
            }
        case "Internet":
            VStack(alignment: .leading, spacing: 12) {
                Text("Internet - 1.1.1.1").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                 Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow(alignment: .center) {
                        Text("Ping").foregroundStyle(.secondary)
                        Text(statsService.stats.loss == 100 ? "---" : String(format: "%.0f ms", statsService.stats.ping)).foregroundStyle(.yellow).monospacedDigit()
                        StatGraphView(data: statsService.pingHistory, color: .yellow, minRange: 0, maxRange: 200, height: 16)
                    }
                    GridRow(alignment: .center) {
                        Text("Jitter").foregroundStyle(.secondary)
                        Text(String(format: "%.1f ms", statsService.stats.jitter)).foregroundStyle(.red).monospacedDigit()
                         StatGraphView(data: statsService.pingHistory.map { abs($0 - statsService.stats.ping) }, color: .red, minRange: 0, maxRange: 50, height: 16)
                    }
                }
            }
        case "Processor":
             VStack(alignment: .leading, spacing: 12) {
                 Text("Processor").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                 Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                     GridRow(alignment: .center) {
                         Text("Usage").foregroundStyle(.secondary)
                         Text(String(format: "%.1f%%", systemStatsService.stats.cpuUsage))
                             .foregroundStyle(systemStatsService.stats.cpuUsage > 80 ? .red : .primary).monospacedDigit()
                     }
                     GridRow(alignment: .center) {
                         Text("Cores").foregroundStyle(.secondary)
                         Text("\(systemStatsService.stats.physicalCores) Physical / \(systemStatsService.stats.activeCores) Active")
                             .foregroundStyle(.secondary).font(.body)
                         Spacer()
                     }
                 }
             }
        case "Memory":
            VStack(alignment: .leading, spacing: 12) {
                Text("Memory").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow(alignment: .center) {
                        Text("Usage").foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", systemStatsService.stats.memoryUsage))
                            .foregroundStyle(systemStatsService.stats.memoryUsage > 80 ? .red : .primary).monospacedDigit()
                    }
                     GridRow(alignment: .center) {
                        Text("Used").foregroundStyle(.secondary)
                        Text(String(format: "%.2f GB / %.0f GB", systemStatsService.stats.memoryUsed, systemStatsService.stats.memoryTotal))
                            .foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        case "Disk":
             VStack(alignment: .leading, spacing: 12) {
                Text("Disk").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                    GridRow(alignment: .center) {
                        Text("Usage").foregroundStyle(.secondary)
                        Text(String(format: "%.1f%%", systemStatsService.stats.diskUsage))
                            .foregroundStyle(systemStatsService.stats.diskUsage > 90 ? .red : .primary).monospacedDigit()
                    }
                     GridRow(alignment: .center) {
                        Text("Free").foregroundStyle(.secondary)
                        Text(String(format: "%.0f GB", systemStatsService.stats.diskFree))
                            .foregroundStyle(.secondary).monospacedDigit()
                         Spacer()
                    }
                }
            }
        case "Battery":
             VStack(alignment: .leading, spacing: 12) {
                Text("Battery").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                 Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                     GridRow(alignment: .center) {
                         Text("Level").foregroundStyle(.secondary)
                         HStack(spacing: 4) {
                             Image(systemName: systemStatsService.stats.isCharging ? "bolt.fill" : "battery.100")
                                .foregroundStyle(systemStatsService.stats.isCharging ? .yellow : .green)
                             Text(String(format: "%.0f%%", systemStatsService.stats.batteryLevel)).monospacedDigit()
                         }
                     }
                     if systemStatsService.stats.timeRemaining > 0 {
                         GridRow(alignment: .center) {
                               Text("Time").foregroundStyle(.secondary)
                               Text("\(systemStatsService.stats.timeRemaining) min").foregroundStyle(.secondary).monospacedDigit()
                               Spacer()
                         }
                     }
                 }
            }
        case "Thermal State":
             VStack(alignment: .leading, spacing: 12) {
                Text("Thermal State").font(.caption).fontWeight(.bold).foregroundStyle(.secondary)
                 Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 12) {
                     GridRow(alignment: .center) {
                         Text("State").foregroundStyle(.secondary)
                         HStack(spacing: 4) {
                               Image(systemName: "thermometer")
                             Text(systemStatsService.stats.thermalPressure)
                                  .foregroundStyle(systemStatsService.stats.thermalPressure == "Normal" ? .green : .red)
                         }
                     }
                     GridRow(alignment: .center) {
                         Text("Temperature").foregroundStyle(.secondary)
                         Text(String(format: "~%.0f°C", systemStatsService.stats.cpuTemperature))
                             .foregroundStyle(systemStatsService.stats.cpuTemperature > 80 ? .red : .orange)
                             .monospacedDigit()
                         Spacer()
                     }
                 }
            }
        default:
             EmptyView()
        }
    }
}

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
