import SwiftUI
import Combine
import LaunchAtLogin
import SystemConfiguration
import NetTrafficStat

class MenuBarState: ObservableObject {
    // LaunchAtLogin handles the storage and state automatically
    // We can expose a binding or just use LaunchAtLogin directly in the view
    // But keeping a published property to sync might be useful if we want to observe changes,
    // though LaunchAtLogin.observable seems better. For now let's just leave it out of here
    // and use LaunchAtLogin directly in the view, OR wrapper it.
    // Let's wrapping it for simplicity in the View code we have.
    
    // Explicit UserDefaults for reliable persistence in a non-View class
    private let defaults = UserDefaults.standard
    
    var autoLaunchEnabled: Bool {
        get { LaunchAtLogin.isEnabled }
        set { LaunchAtLogin.isEnabled = newValue }
    }
    
    @AppStorage("displayMode") var displayMode: DisplayMode = .both
    @AppStorage("showArrows") var showArrows: Bool = true
    @AppStorage("unitType") var unitType: UnitType = .bytes
    @AppStorage("fixedUnit") var fixedUnit: FixedUnit = .auto
    @AppStorage("fontSize") var fontSize: Double = 9.0
    @AppStorage("textSpacing") var textSpacing: Double = 0.0
    @AppStorage("characterSpacing") var characterSpacing: Double = 0.0
    @AppStorage("unstackNetworkUsage") var unstackNetworkUsage: Bool = false
    
    @AppStorage("showSpeedMenu") var showSpeedMenu: Bool = true

    @AppStorage("showCPUMenu") var showCPUMenu: Bool = false
    @AppStorage("showMemoryMenu") var showMemoryMenu: Bool = false
    @AppStorage("showDiskMenu") var showDiskMenu: Bool = false
    @AppStorage("showTempMenu") var showTempMenu: Bool = false

    @AppStorage("showRSSIMenu") var showRSSIMenu: Bool = false
    @AppStorage("showRouterPingMenu") var showRouterPingMenu: Bool = false
    @AppStorage("showDNSPingMenu") var showDNSPingMenu: Bool = false
    @AppStorage("showInternetPingMenu") var showInternetPingMenu: Bool = false
    @AppStorage("showBatteryMenu") var showBatteryMenu: Bool = false
    
    @Published var menuText = ""
    @Published var isConnected: Bool = true
    
    // Use @Published with manual UserDefaults sync for these critical values
    @Published var totalUpload: Double = 0.0 {
        didSet { defaults.set(totalUpload, forKey: "totalUploadPersistent") }
    }
    @Published var totalDownload: Double = 0.0 {
        didSet { defaults.set(totalDownload, forKey: "totalDownloadPersistent") }
    }
    @Published var appLaunchDate: Double = 0.0 {
        didSet { defaults.set(appLaunchDate, forKey: "appLaunchDate") }
    }
    
    var currentIcon: NSImage {
        return MenuBarIconGenerator.generateIcon(
            text: menuText,
            font: .monospacedSystemFont(ofSize: fontSize, weight: .semibold),
            spacing: textSpacing,
            kern: characterSpacing,
            isConnected: isConnected
        )
    }
    
    // Expose raw values for UI
    var currentUploadSpeed: Double { uploadSpeed }
    var currentDownloadSpeed: Double { downloadSpeed }
    
    private var timer: Timer?
    private var primaryInterface: String?
    private var netTrafficStat = NetTrafficStatReceiver()
    private var systemStatsService = SystemStatsService.shared
    private var networkStatsService = NetworkStatsService.shared
    
    @Published var downloadHistory: [Double] = []
    @Published var uploadHistory: [Double] = []
    @Published var totalTrafficHistory: [Double] = []
    private let historyLimit = 60
    
    // Current Speed
    private var uploadSpeed: Double = 0.0
    private var downloadSpeed: Double = 0.0
    
    private let byteMetrics: [String] = [" B", "KB", "MB", "GB", "TB"]
    private let bitMetrics: [String] = [" b", "Kb", "Mb", "Gb", "Tb"]
    
    private func checkInternetReachability() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)

        guard let reachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else { return false }

        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(reachability, &flags) { return false }

        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        return isReachable && !needsConnection
    }

    private func findPrimaryInterface() -> String? {
        let storeRef = SCDynamicStoreCreate(nil, "FindCurrentInterfaceIpMac" as CFString, nil, nil)
        let global = SCDynamicStoreCopyValue(storeRef, "State:/Network/Global/IPv4" as CFString)
        let primaryInterface = global?.value(forKey: "PrimaryInterface") as? String
        return primaryInterface
    }
    
    func formatSpeed(_ speed: Double) -> (String, String) {
        // Convert to bits if needed
        let value = unitType == .bits ? speed * 8 : speed
        
        let metrics = unitType == .bits ? bitMetrics : byteMetrics
        var scaledValue = value
        var metricIndex = 0
        
        if fixedUnit == .kb {
            scaledValue = value / 1024.0
            metricIndex = 1
        } else if fixedUnit == .mb {
            scaledValue = value / (1024.0 * 1024.0)
            metricIndex = 2
        } else {
            // Auto
            while scaledValue > 1024.0 && metricIndex < metrics.count - 1 {
                scaledValue /= 1024.0
                metricIndex += 1
            }
        }
        
        return (String(format: "%.2f", scaledValue), metrics[metricIndex] + (unitType == .bits ? "ps" : "/s"))
    }
    
    func formatBytes(_ bytes: Double) -> (String, String) {
         let metrics = byteMetrics // Always bytes for total
         var scaledValue = bytes
         var metricIndex = 0
         
         while scaledValue > 1024.0 && metricIndex < metrics.count - 1 {
             scaledValue /= 1024.0
             metricIndex += 1
         }
         
         return (String(format: "%.2f", scaledValue), metrics[metricIndex])
    }
    
    private func updateHistory<T>(_ history: inout [T], newValue: T) {
        history.append(newValue)
        if history.count > historyLimit {
            history.removeFirst()
        }
    }
    
    private func startTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.isConnected = self.checkInternetReachability()
                self.primaryInterface = self.findPrimaryInterface()
                if (self.primaryInterface == nil) { return }
                
                if let netTrafficStatMap = self.netTrafficStat.getNetTrafficStatMap() {
                    if let netTrafficStat = netTrafficStatMap.object(forKey: self.primaryInterface!) as? NetTrafficStatOC  {
                        self.downloadSpeed = netTrafficStat.ibytes_per_sec as! Double
                        self.uploadSpeed = netTrafficStat.obytes_per_sec as! Double
                        
                        // Accumulate totals (speed is bytes per second, timer is 1s)
                        self.totalDownload += self.downloadSpeed
                        self.totalUpload += self.uploadSpeed
                        
                        // Update History
                        self.updateHistory(&self.downloadHistory, newValue: self.downloadSpeed)
                        self.updateHistory(&self.uploadHistory, newValue: self.uploadSpeed)
                        self.updateHistory(&self.totalTrafficHistory, newValue: self.downloadSpeed + self.uploadSpeed)
                        
                        let (downVal, downUnit) = self.formatSpeed(self.downloadSpeed)
                        let (upVal, upUnit) = self.formatSpeed(self.uploadSpeed)
                        
                        // Pinned Stats
                        var statsList: [String] = []

                        // Network Speed (pinnable, default on)
                        if self.showSpeedMenu {
                            var speedParts: [String] = []
                            if self.displayMode == .both || self.displayMode == .uploadOnly {
                                speedParts.append("\(self.showArrows ? "↑ " : "")\(upVal) \(upUnit)")
                            }
                            if self.displayMode == .both || self.displayMode == .downloadOnly {
                                speedParts.append("\(self.showArrows ? "↓ " : "")\(downVal) \(downUnit)")
                            }
                            statsList.append(speedParts.joined(separator: self.unstackNetworkUsage ? " " : "\n"))
                        }

                        // Network stats
                        let netStats = self.networkStatsService.stats
                        if self.showRSSIMenu {
                            statsList.append("RSSI: \(netStats.rssi)")
                        }
                        if self.showRouterPingMenu {
                            statsList.append("RTR: \(netStats.routerLoss == 100 ? "---" : String(format: "%.0fms", netStats.routerPing))")
                        }
                        if self.showDNSPingMenu {
                            statsList.append("DNS: \(netStats.dnsLoss == 100 ? "---" : String(format: "%.0fms", netStats.dnsPing))")
                        }
                        if self.showInternetPingMenu {
                            statsList.append("Ping: \(netStats.loss == 100 ? "---" : String(format: "%.0fms", netStats.ping))")
                        }

                        // System stats
                        if self.showCPUMenu {
                            statsList.append("CPU: \(Int(self.systemStatsService.stats.cpuUsage))%")
                        }
                        if self.showMemoryMenu {
                            statsList.append("RAM: \(Int(self.systemStatsService.stats.memoryUsage))%")
                        }
                        if self.showDiskMenu {
                            statsList.append("HDD: \(Int(self.systemStatsService.stats.diskUsage))%")
                        }
                        if self.showTempMenu {
                            statsList.append("\(Int(self.systemStatsService.stats.cpuTemperature))°C")
                        }
                        if self.showBatteryMenu {
                            statsList.append("BAT: \(Int(self.systemStatsService.stats.batteryLevel))%")
                        }

                        let text: String
                        if !statsList.isEmpty {
                            // Pinned stats replace the default speed display
                            text = statsList.joined(separator: " | ")
                        } else {
                            // Default: show network speed
                            var networkSegments: [String] = []
                            if self.displayMode == .both || self.displayMode == .uploadOnly {
                                networkSegments.append("\(self.showArrows ? "↑ " : "")\(upVal) \(upUnit)")
                            }
                            if self.displayMode == .both || self.displayMode == .downloadOnly {
                                networkSegments.append("\(self.showArrows ? "↓ " : "")\(downVal) \(downUnit)")
                            }
                            text = networkSegments.joined(separator: self.unstackNetworkUsage ? " | " : "\n")
                        }

                        self.menuText = text
                    }
                }
            }
        RunLoop.current.add(timer, forMode: .common)
        self.timer = timer
    }
    
    private func stopTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    init() {
        // Load initial values from UserDefaults
        self.totalUpload = defaults.double(forKey: "totalUploadPersistent")
        self.totalDownload = defaults.double(forKey: "totalDownloadPersistent")
        self.appLaunchDate = defaults.double(forKey: "appLaunchDate")
        
        // Only set appLaunchDate if it's the very first time (0.0)
        if self.appLaunchDate == 0.0 {
            self.appLaunchDate = Date().timeIntervalSince1970
        }
        
        DispatchQueue.main.async {
            // Ensure valid display mode default
            if self.menuText.isEmpty { self.menuText = "..." }
            self.startTimer()
        }
    }
    
    deinit {
        DispatchQueue.main.async {
            self.stopTimer()
        }
    }
}

