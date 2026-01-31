import SwiftUI
import Charts

struct DetailedStatusView: View {
    @StateObject private var statsService = NetworkStatsService()
    @EnvironmentObject var menuBarState: MenuBarState
    @Environment(\.openWindow) var openWindow
    
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
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
                    .onTapGesture {
                        NSApp.activate(ignoringOtherApps: true)
                        openWindow(id: "settings")
                    }
            }
            
            Divider()
            
            // Wi-Fi Section
            VStack(alignment: .leading) {
                HStack {
                    Circle()
                        .fill(statsService.stats.ssid == "Disconnected" || statsService.stats.ssid == "No Interface" ? Color.red : (statsService.stats.rssi == 0 ? Color.orange : (statsService.stats.rssi > -90 ? Color.green : Color.red)))
                        .frame(width: 8, height: 8)
                    Text(statsService.stats.ssid)
                        .font(.system(size: 14, weight: .bold))
                    Text(statsService.stats.band)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Link Rate")
                            .foregroundStyle(.secondary)
                        Text("\(Int(statsService.stats.txRate)) Mbps")
                            .foregroundStyle(.green)
                            .monospacedDigit()
                        StatGraphView(
                            data: Array(repeating: statsService.stats.txRate, count: 20), // Placeholder for rate history if valid, or we could track it too.
                            color: .green,
                            minRange: 0, maxRange: 1000
                        )
                    }
                    
                    GridRow {
                        Text("Signal")
                            .foregroundStyle(.secondary)
                        Text("\(statsService.stats.rssi) dBm")
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                        StatGraphView(
                            data: statsService.signalHistory.map { Double($0) },
                            color: .orange,
                            minRange: -100, maxRange: -30
                        )
                    }
                    
                    GridRow {
                        Text("Noise")
                            .foregroundStyle(.secondary)
                        Text("\(statsService.stats.noise) dBm")
                            .foregroundStyle(.green)
                            .monospacedDigit()
                        StatGraphView(
                            data: statsService.noiseHistory.map { Double($0) },
                            color: .green,
                            minRange: -110, maxRange: -80
                        )
                    }
                }
            }
            
            Divider()
            
            // Router Section
            VStack(alignment: .leading) {
                Text("Router")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Ping")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f ms", statsService.stats.routerPing))
                            .foregroundStyle(.green)
                            .monospacedDigit()
                        StatGraphView(
                            data: statsService.routerPingHistory,
                            color: .green,
                            minRange: 0, maxRange: 100
                        )
                    }
                    
                    GridRow {
                        Text("Jitter")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f ms", statsService.stats.routerJitter))
                            .foregroundStyle(.red) // Assuming slightly high jitter in red for visual matching
                            .monospacedDigit()
                        // Generic Jitter Graph
                         StatGraphView(
                            data: statsService.routerPingHistory.map { abs($0 - statsService.stats.routerPing) }, // visual approx for jitter graph
                            color: .red,
                            minRange: 0, maxRange: 50
                        )
                    }
                    
                    GridRow {
                        Text("Loss")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f%%", statsService.stats.routerLoss))
                            .foregroundStyle(.yellow)
                            .monospacedDigit()
                        Rectangle().fill(Color.orange).frame(height: 2) // Static line for now
                    }
                }
            }

            Divider()
            
            // Internet Section
            VStack(alignment: .leading) {
                Text("Internet • 1.1.1.1")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    
                 Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                    GridRow {
                        Text("Ping")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.0f ms", statsService.stats.ping))
                            .foregroundStyle(.yellow)
                            .monospacedDigit()
                        StatGraphView(
                            data: statsService.pingHistory,
                            color: .yellow,
                            minRange: 0, maxRange: 200
                        )
                    }
                    
                    GridRow {
                        Text("Jitter")
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f ms", statsService.stats.jitter))
                             .foregroundStyle(.red)
                            .monospacedDigit()
                         StatGraphView(
                            data: statsService.pingHistory.map { abs($0 - statsService.stats.ping) },
                            color: .red,
                            minRange: 0, maxRange: 50
                        )
                    }
                }
            }
            
            Divider()
            
            // Quit Button
            Button(action: {
                NSApp.terminate(nil)
            }) {
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
        .padding(16)
        .frame(width: 350)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
