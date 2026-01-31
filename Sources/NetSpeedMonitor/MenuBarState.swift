import SwiftUI
import Combine
import ServiceManagement
import SystemConfiguration
import NetTrafficStat

enum NetSpeedUpdateInterval: Int, CaseIterable, Identifiable {
    case Sec1 = 1
    case Sec2 = 2
    case Sec5 = 5
    case Sec10 = 10
    case Sec30 = 30
    
    var id: Int { self.rawValue }
    
    var displayName: String {
        switch self {
        case .Sec1: return "1s"
        case .Sec2: return "2s"
        case .Sec5: return "5s"
        case .Sec10: return "10s"
        case .Sec30: return "30s"
        }
    }
}

class MenuBarState: ObservableObject {
    @AppStorage("AutoLaunchEnabled") var autoLaunchEnabled: Bool = false {
        didSet { updateAutoLaunchStatus() }
    }
    @AppStorage("NetSpeedUpdateInterval") var netSpeedUpdateInterval: Int = 1 {
        didSet { updateNetSpeedUpdateIntervalStatus() }
    }
    
    @AppStorage("displayMode") var displayMode: DisplayMode = .both
    @AppStorage("showArrows") var showArrows: Bool = true
    @AppStorage("unitType") var unitType: UnitType = .bytes
    @AppStorage("fixedUnit") var fixedUnit: FixedUnit = .auto
    @AppStorage("fontSize") var fontSize: Double = 9.0
    @AppStorage("textSpacing") var textSpacing: Double = 0.0
    @AppStorage("characterSpacing") var characterSpacing: Double = 0.0
    
    @Published var menuText = ""
    
    var currentIcon: NSImage {
        return MenuBarIconGenerator.generateIcon(
            text: menuText,
            font: .monospacedSystemFont(ofSize: fontSize, weight: .semibold),
            spacing: textSpacing,
            kern: characterSpacing
        )
    }
    
    private var timer: Timer?
    private var primaryInterface: String?
    private var netTrafficStat = NetTrafficStatReceiver()
    
    private var uploadSpeed: Double = 0.0
    private var downloadSpeed: Double = 0.0
    private let byteMetrics: [String] = [" B", "KB", "MB", "GB", "TB"]
    private let bitMetrics: [String] = [" b", "Kb", "Mb", "Gb", "Tb"]
    
    private func currentAutoLaunchStatus() -> Bool {
        let service = SMAppService.mainApp
        let status = service.status
        return status == .enabled
    }
    
    private func updateAutoLaunchStatus() {
        let service = SMAppService.mainApp
        do {
            if autoLaunchEnabled {
                if service.status == .notFound || service.status == .notRegistered {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            print("AutoLaunch update failed: \(error)")
            autoLaunchEnabled = currentAutoLaunchStatus()
        }
    }
    
    private func updateNetSpeedUpdateIntervalStatus() {
        self.stopTimer()
        self.startTimer()
    }
    
    private func findPrimaryInterface() -> String? {
        let storeRef = SCDynamicStoreCreate(nil, "FindCurrentInterfaceIpMac" as CFString, nil, nil)
        let global = SCDynamicStoreCopyValue(storeRef, "State:/Network/Global/IPv4" as CFString)
        let primaryInterface = global?.value(forKey: "PrimaryInterface") as? String
        return primaryInterface
    }
    
    private func formatSpeed(_ speed: Double) -> (String, String) {
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
        
        return (String(format: "%6.2lf", scaledValue), metrics[metricIndex] + (unitType == .bits ? "ps" : "/s"))
    }
    
    private func startTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(self.netSpeedUpdateInterval), repeats: true) { _ in
                self.primaryInterface = self.findPrimaryInterface()
                if (self.primaryInterface == nil) { return }
                
                if let netTrafficStatMap = self.netTrafficStat.getNetTrafficStatMap() {
                    if let netTrafficStat = netTrafficStatMap.object(forKey: self.primaryInterface!) as? NetTrafficStatOC  {
                        self.downloadSpeed = netTrafficStat.ibytes_per_sec as! Double
                        self.uploadSpeed = netTrafficStat.obytes_per_sec as! Double
                        
                        let (downVal, downUnit) = self.formatSpeed(self.downloadSpeed)
                        let (upVal, upUnit) = self.formatSpeed(self.uploadSpeed)
                        
                        var text = ""
                        
                        if self.displayMode == .both || self.displayMode == .uploadOnly {
                            text += "\(self.showArrows ? "↑ " : "")\(upVal) \(upUnit)\n"
                        }
                        
                        if self.displayMode == .both || self.displayMode == .downloadOnly {
                            text += "\(self.showArrows ? "↓ " : "")\(downVal) \(downUnit)"
                        }
                        
                        self.menuText = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
        DispatchQueue.main.async {
            self.autoLaunchEnabled = self.currentAutoLaunchStatus()
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

